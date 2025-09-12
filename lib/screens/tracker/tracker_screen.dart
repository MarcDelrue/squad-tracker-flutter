import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:squad_tracker_flutter/providers/combined_stream_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/models/user_with_location_session_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final TextEditingController _filterController =
      TextEditingController(text: "TTGO");

  // Background state for BLE sync (not shown in UI)
  String _myStatus = 'alive';
  int _myKills = 0;
  int _myDeaths = 0;
  String _myName = 'me';
  String _myColorHex = '000000'; // RRGGBB (no '#')
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  CombinedStreamService? _combinedService;
  StreamSubscription<List<UserWithLocationSession>?>? _combinedSub;
  StreamSubscription<List<Map<String, dynamic>>>? _scoreboardSub;
  StreamSubscription<Map<String, dynamic>>? _myStatsSub;
  StreamSubscription<Map<String, dynamic>?>? _gameMetaSub;
  StreamSubscription<List<dynamic>>? _locationsSub; // members location updates
  Map<String, Map<String, dynamic>> _scoreByUserId =
      <String, Map<String, dynamic>>{};
  int _lastProcessedMsgCount = 0;
  String? _lastConnectedRemoteId;
  int? _activeGameId;
  int _seqCounter = 0; // BLE snapshot sequence number
  int _ackOpId = 0; // last OP id received from device

  void _maybeStartDataSync(BleService ble) async {
    final squad = SquadService().currentSquad;
    final user = UserService().currentUser;
    if (squad == null || user == null) return;

    // Combined members stream (name + status)
    _combinedService ??= CombinedStreamService(
      squadMembersService: SquadMembersService(),
      userSquadLocationService: UserSquadLocationService(),
    );
    _combinedSub ??= _combinedService!.combinedStream.listen((rows) {
      if (rows == null) return;
      final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
      final distances = _combinedService!
          .userSquadLocationService.currentMembersDistanceFromUser;
      const fresh = Duration(seconds: 20);
      const warn = Duration(seconds: 60);
      for (final r in rows) {
        final uid = r.userWithSession.user.id;
        final name = r.userWithSession.user.username ?? 'member';
        final color =
            (r.userWithSession.user.main_color ?? '#000000').toString();
        final s = r.userWithSession.session.user_status;
        final score = _scoreByUserId[uid];
        final status = (score?['status'] as String?)?.toLowerCase() ??
            (s != null
                ? UserSquadSessionStatusExtension(s).value.toLowerCase()
                : 'alive');
        final kills = score?['kills'] ?? 0;
        final deaths = score?['deaths'] ?? 0;
        final updatedAt = r.location?.updated_at;
        int staleBucket = 2; // default stale if unknown
        if (updatedAt != null) {
          final age = DateTime.now().toUtc().difference(updatedAt.toUtc());
          if (age <= fresh) {
            staleBucket = 0;
          } else if (age <= warn) {
            staleBucket = 1;
          } else {
            staleBucket = 2;
          }
        }
        final distanceMeters = distances?[uid];
        if (uid == user.id) {
          _myStatus = status;
          _myKills = kills;
          _myDeaths = deaths;
          _myName = name;
          _myColorHex = color.replaceAll('#', '').toUpperCase();
        } else {
          list.add({
            'id': uid,
            'username': name,
            'kills': kills,
            'deaths': deaths,
            'status': status,
            'distance': distanceMeters == null
                ? null
                : distanceMeters.isFinite
                    ? distanceMeters
                    : null,
            'stale': staleBucket,
            'color': color,
          });
        }
      }
      _members = list;
      _sendSnapshotIfConnected(ble);
    });

    // Immediate distance refresh from realtime location updates
    _locationsSub ??= _combinedService!
        .userSquadLocationService.currentMembersLocationStream
        .listen((_) {
      final distances = _combinedService!
          .userSquadLocationService.currentMembersDistanceFromUser;
      if (distances == null) return;
      // Update member distances in-place
      _members = _members.map((m) {
        final id = m['id'] as String?;
        if (id != null && distances.containsKey(id)) {
          final d = distances[id];
          return {
            ...m,
            'distance': d == null ? null : (d.isFinite ? d : null),
          };
        }
        return m;
      }).toList();
      _sendSnapshotIfConnected(ble);
    });

    // Start/refresh streams based on active game changes
    _gameMetaSub ??= GameService()
        .streamActiveGameMetaBySquad(int.parse(squad.id))
        .listen((meta) async {
      final newGameId = (meta == null) ? null : (meta['id'] as num?)?.toInt();
      final changed = newGameId != _activeGameId;
      if (!changed) return;
      if (newGameId == null) {
        return;
      }

      await _scoreboardSub?.cancel();
      _scoreboardSub = null;
      await _myStatsSub?.cancel();
      _myStatsSub = null;

      _activeGameId = newGameId;
      _myKills = 0;
      _myDeaths = 0;
      _scoreByUserId = <String, Map<String, dynamic>>{};
      _members = _members
          .map((m) => {
                'id': m['id'],
                'username': (m['username'] ?? m['name'] ?? 'member'),
                'kills': 0,
                'deaths': 0,
              })
          .toList();
      _sendSnapshotIfConnected(ble);

      // Subscribe to new game's scoreboard
      _scoreboardSub =
          GameService().streamScoreboardByGame(newGameId).listen((rows) {
        final Map<String, Map<String, dynamic>> byId = {};
        for (final r in rows) {
          final uid = r['user_id'] as String?;
          if (uid == null) continue;
          byId[uid] = {
            'kills': (r['kills'] ?? 0) as int,
            'deaths': (r['deaths'] ?? 0) as int,
            'status': r['user_status'] as String?,
          };
        }
        final me = UserService().currentUser;
        String? myStatusFromScore;
        if (me != null) {
          final mine = byId[me.id];
          final s = mine != null ? mine['status'] as String? : null;
          if (s != null && s.isNotEmpty) {
            myStatusFromScore = s.toLowerCase();
          }
        }
        _scoreByUserId = byId;
        // Immediately merge scoreboard data into current members for BLE snapshots
        _members = _members.map((m) {
          final id = m['id'] as String?;
          if (id != null) {
            final sb = byId[id];
            if (sb != null) {
              return {
                ...m,
                'kills': sb['kills'] ?? m['kills'],
                'deaths': sb['deaths'] ?? m['deaths'],
                'status':
                    (sb['status'] as String?)?.toLowerCase() ?? m['status'],
              };
            }
          }
          return m;
        }).toList();
        if (myStatusFromScore != null) {
          _myStatus = myStatusFromScore;
        }
        _sendSnapshotIfConnected(ble);
      });

      // Faster initial K/D for me only
      final myStatsStream =
          await GameService().streamMyStats(int.parse(squad.id));
      if (myStatsStream != null) {
        _myStatsSub = myStatsStream.listen((row) {
          if (row.isEmpty) return;
          final kills = (row['kills'] ?? 0) as int;
          final deaths = (row['deaths'] ?? 0) as int;
          _myKills = kills;
          _myDeaths = deaths;
          _sendSnapshotIfConnected(ble);
        });
      }
    });
  }

  void _sendSnapshotIfConnected(BleService ble) {
    if (ble.connectedDevice != null) {
      _seqCounter++;
      ble.sendLines(_buildSnapshotLines());
    }
  }

  void _processNewMessages(BleService ble) {
    final msgs = ble.receivedMessages;
    if (_lastProcessedMsgCount < msgs.length) {
      for (int i = _lastProcessedMsgCount; i < msgs.length; i++) {
        final msg = msgs[i];
        if (msg == 'DEVICE_CONNECTED') {
          if (ble.connectedDevice != null) {
            ble.sendLines(_buildSnapshotLines());
          }
        } else if (msg.startsWith('APPLIED ')) {
          final parts = msg.split(' ');
          if (parts.length >= 2) {
            final seq = int.tryParse(parts[1]);
            if (seq != null) {
              // Log RTT from when we sent SEQ to when device applied
              // ignore: avoid_print
              print('[BLE] Snapshot applied seq=$seq');
            }
          }
        } else {
          _handleInbound(msg);
        }
      }
      _lastProcessedMsgCount = msgs.length;
    }
  }

  List<String> _buildSnapshotLines() {
    final List<String> lines = <String>[];
    lines.add('RESET_MEMBERS');
    // Current user
    final safeMyName = _myName.replaceAll(' ', '_');
    lines.add('MY_NAME $safeMyName');
    lines.add('MY_STATUS $_myStatus');
    lines.add('MY_KD $_myKills $_myDeaths');
    lines.add('MY_COLOR $_myColorHex');
    // Removed legacy MEM lines to reduce BLE traffic; device supports MEMX
    // Extended MEMX lines with status, distance(m), staleness bucket, and color
    for (final m in _members) {
      final name = (m['username'] ?? m['name'] ?? 'member').toString();
      final safeName = name.replaceAll(' ', '_');
      final kills = (m['kills'] ?? 0).toString();
      final deaths = (m['deaths'] ?? 0).toString();
      final status = (m['status'] ?? 'alive').toString().toLowerCase();
      final distance = m['distance'];
      final intDistance = distance == null
          ? -1
          : (distance is num
              ? distance.round()
              : int.tryParse(distance.toString()) ?? -1);
      final stale = (m['stale'] ?? 2).toString();
      final color = (m['color'] ?? '#000000')
          .toString()
          .replaceAll('#', '')
          .toUpperCase();
      lines.add(
          'MEMX $safeName $kills $deaths $status $intDistance $stale $color');
    }
    lines.add('ACK $_ackOpId');
    lines.add('SEQ $_seqCounter');
    lines.add('EOT');
    return lines;
  }

  void _handleInbound(String msg) {
    if (msg.startsWith('OP ')) {
      // OP <id> BTN_A | OP <id> BTN_B
      final parts = msg.split(' ');
      if (parts.length >= 3) {
        final id = int.tryParse(parts[1]);
        final kind = parts[2];
        if (id != null && id > _ackOpId) {
          _ackOpId = id;
        }
        if (kind == 'BTN_A') {
          final squad = SquadService().currentSquad;
          if (squad != null) {
            final wasAlive = _myStatus == 'alive';
            _myStatus = wasAlive ? 'dead' : 'alive';
            if (wasAlive) {
              _myDeaths = _myDeaths + 1;
            }
            _sendSnapshotIfConnected(
                Provider.of<BleService>(context, listen: false));
            final nextServer = _myStatus == 'alive' ? 'ALIVE' : 'DEAD';
            GameService().setStatus(squadId: squad.id, status: nextServer);
          }
          return;
        } else if (kind == 'BTN_B') {
          final squad = SquadService().currentSquad;
          if (squad != null) {
            if (_myStatus == 'alive') {
              _myKills = _myKills + 1;
            }
            _sendSnapshotIfConnected(
                Provider.of<BleService>(context, listen: false));
            GameService().bumpKill(int.parse(squad.id));
          }
          return;
        }
      }
    } else if (msg.contains('BTN_A_PRESS')) {
      // Optimistic toggle
      final squad = SquadService().currentSquad;
      if (squad != null) {
        final wasAlive = _myStatus == 'alive';
        _myStatus = wasAlive ? 'dead' : 'alive';
        if (wasAlive) {
          _myDeaths = _myDeaths + 1;
        }
        _sendSnapshotIfConnected(
            Provider.of<BleService>(context, listen: false));
        final nextServer = _myStatus == 'alive' ? 'ALIVE' : 'DEAD';
        GameService().setStatus(squadId: squad.id, status: nextServer);
      }
    } else if (msg.contains('BTN_B_PRESS')) {
      // Optimistic kill bump (only if alive to mirror device behavior)
      final squad = SquadService().currentSquad;
      if (squad != null) {
        if (_myStatus == 'alive') {
          _myKills = _myKills + 1;
          _sendSnapshotIfConnected(
              Provider.of<BleService>(context, listen: false));
        }
        GameService().bumpKill(int.parse(squad.id));
      }
    }
  }

  @override
  void dispose() {
    _combinedSub?.cancel();
    _scoreboardSub?.cancel();
    _myStatsSub?.cancel();
    _gameMetaSub?.cancel();
    _locationsSub?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    // Just surface denied in UI through button enable/disable; no extra handling here.
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bluetooth permissions permanently denied')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, ble, _) {
        _maybeStartDataSync(ble);
        final currentId = ble.connectedDevice?.remoteId.str;
        if (currentId != _lastConnectedRemoteId) {
          _lastConnectedRemoteId = currentId;
          _lastProcessedMsgCount = ble.receivedMessages.length;
          _seqCounter = 0; // reset sequence for new connection
          _ackOpId = 0; // reset ack id on new connection
          _sendSnapshotIfConnected(ble);
        }
        _processNewMessages(ble);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tracker (BLE)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: ble.isScanning
                    ? null
                    : () async {
                        await _ensurePermissions();
                        await ble.ensureAdapterOn();
                        await ble.startScan(
                            nameFilter: _filterController.text.trim().isEmpty
                                ? null
                                : _filterController.text.trim());
                      },
                tooltip: 'Scan',
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: ble.isScanning ? () => ble.stopScan() : null,
                tooltip: 'Stop scan',
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        decoration: const InputDecoration(
                          labelText: 'Name filter (e.g. TTGO)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: ble.isScanning
                          ? null
                          : () async {
                              await _ensurePermissions();
                              await ble.ensureAdapterOn();
                              await ble.startScan(
                                  nameFilter:
                                      _filterController.text.trim().isEmpty
                                          ? null
                                          : _filterController.text.trim());
                            },
                      child: const Text('Scan'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: ble.isScanning ? () => ble.stopScan() : null,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ),
              if (ble.connectedDevice == null)
                Expanded(
                  child: ListView.separated(
                    itemCount: ble.devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final d = ble.devices[index];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(
                            d.name.isNotEmpty ? d.name : d.device.remoteId.str),
                        subtitle: Text('RSSI ${d.rssi}'),
                        trailing: ble.isConnecting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : ElevatedButton(
                                onPressed: () async {
                                  await ble.connect(d.device);
                                },
                                child: const Text('Connect'),
                              ),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.bluetooth_connected),
                        title: Text(ble.connectedDevice!.platformName.isNotEmpty
                            ? ble.connectedDevice!.platformName
                            : ble.connectedDevice!.remoteId.str),
                        trailing: ElevatedButton(
                          onPressed: () => ble.disconnect(),
                          child: const Text('Disconnect'),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () async {
                                _sendSnapshotIfConnected(ble);
                              },
                              child: const Text('Sync to Device'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
