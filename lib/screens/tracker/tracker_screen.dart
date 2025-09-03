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
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _filterController =
      TextEditingController(text: "TTGO");
  final BleService _ble = BleService();
  String _myStatus = 'alive';
  int _myKills = 0;
  int _myDeaths = 0;
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  CombinedStreamService? _combinedService;
  StreamSubscription<List<UserWithLocationSession>?>? _combinedSub;
  StreamSubscription<List<Map<String, dynamic>>>? _scoreboardSub;
  StreamSubscription<Map<String, dynamic>>? _myStatsSub;
  Map<String, Map<String, dynamic>> _scoreByUserId =
      <String, Map<String, dynamic>>{};
  int _lastProcessedMsgCount = 0;
  // Flags no longer used for gating snapshot sending, kept for potential UI hooks
  // but removed to satisfy lints
  String? _lastConnectedRemoteId;

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
      // My row first
      final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
      for (final r in rows) {
        final uid = r.userWithSession.user.id;
        final name = r.userWithSession.user.username ?? 'member';
        final s = r.userWithSession.session.user_status;
        final score = _scoreByUserId[uid];
        final status = (score?['status'] as String?)?.toLowerCase() ??
            (s != null
                ? UserSquadSessionStatusExtension(s).value.toLowerCase()
                : 'alive');
        final kills = score?['kills'] ?? 0;
        final deaths = score?['deaths'] ?? 0;
        if (uid == user.id) {
          _myStatus = status;
          _myKills = kills;
          _myDeaths = deaths;
        } else {
          list.add({
            'id': uid,
            'username': name,
            'kills': kills,
            'deaths': deaths,
          });
        }
      }
      setState(() {
        _members = list;
      });
      _sendSnapshotIfConnected(ble);
    });

    // Scoreboard stream (K/D)
    if (_scoreboardSub == null) {
      final gameId = await GameService().getActiveGameId(int.parse(squad.id));
      if (gameId != null) {
        _scoreboardSub =
            GameService().streamScoreboardByGame(gameId).listen((rows) {
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
          // Update my status immediately from scoreboard to avoid stale session default
          final me = UserService().currentUser;
          String? myStatusFromScore;
          if (me != null) {
            final mine = byId[me.id];
            final s = mine != null ? mine['status'] as String? : null;
            if (s != null && s.isNotEmpty) {
              myStatusFromScore = s.toLowerCase();
            }
          }
          setState(() {
            _scoreByUserId = byId;
            if (myStatusFromScore != null) {
              _myStatus = myStatusFromScore;
            }
          });
          _sendSnapshotIfConnected(ble);
        });

        // Faster initial K/D for me only
        final myStatsStream =
            await GameService().streamMyStats(int.parse(squad.id));
        if (myStatsStream != null && _myStatsSub == null) {
          _myStatsSub = myStatsStream.listen((row) {
            if (row.isEmpty) return;
            final kills = (row['kills'] ?? 0) as int;
            final deaths = (row['deaths'] ?? 0) as int;
            setState(() {
              _myKills = kills;
              _myDeaths = deaths;
            });
            if (ble.connectedDevice != null) {
              ble.sendLines(_buildSnapshotLines());
            }
          });
        }
      }
    }
  }

  void _sendSnapshotIfConnected(BleService ble) {
    if (ble.connectedDevice != null) {
      ble.sendLines(_buildSnapshotLines());
    }
  }

  void _processNewMessages(BleService ble) {
    final msgs = ble.receivedMessages;
    if (_lastProcessedMsgCount < msgs.length) {
      for (int i = _lastProcessedMsgCount; i < msgs.length; i++) {
        final msg = msgs[i];
        if (msg == 'DEVICE_CONNECTED') {
          // Push snapshot immediately on device connect
          if (ble.connectedDevice != null) {
            ble.sendLines(_buildSnapshotLines());
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
    lines.add('MY_STATUS $_myStatus');
    lines.add('MY_KD $_myKills $_myDeaths');
    for (final m in _members) {
      final name = (m['username'] ?? m['name'] ?? 'member').toString();
      final kills = (m['kills'] ?? 0).toString();
      final deaths = (m['deaths'] ?? 0).toString();
      lines.add('MEM $name $kills $deaths');
    }
    lines.add('EOT');
    return lines;
  }

  void _handleInbound(String msg) {
    // Simple protocol from TTGO:
    // BTN_A_PRESS => toggle alive/dead
    // BTN_B_PRESS => bump kill
    if (msg.contains('BTN_A_PRESS')) {
      // Toggle status in backend
      final squad = SquadService().currentSquad;
      if (squad != null) {
        final next = _myStatus == 'alive' ? 'DEAD' : 'ALIVE';
        GameService().setStatus(squadId: squad.id, status: next);
      }
    } else if (msg.contains('BTN_B_PRESS')) {
      final squad = SquadService().currentSquad;
      if (squad != null) {
        GameService().bumpKill(int.parse(squad.id));
      }
    }
  }

  @override
  void dispose() {
    _combinedSub?.cancel();
    _scoreboardSub?.cancel();
    _myStatsSub?.cancel();
    _messageController.dispose();
    _filterController.dispose();
    _ble.dispose();
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
    return ChangeNotifierProvider<BleService>.value(
      value: _ble,
      child: Consumer<BleService>(
        builder: (context, ble, _) {
          _maybeStartDataSync(ble);
          // Detect connection change to trigger immediate sync and reset message cursor
          final currentId = ble.connectedDevice?.remoteId.str;
          if (currentId != _lastConnectedRemoteId) {
            _lastConnectedRemoteId = currentId;
            // Avoid replaying old messages from a previous session/device
            _lastProcessedMsgCount = ble.receivedMessages.length;
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
                          title: Text(d.name.isNotEmpty
                              ? d.name
                              : d.device.remoteId.str),
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
                          title: Text(
                              ble.connectedDevice!.platformName.isNotEmpty
                                  ? ble.connectedDevice!.platformName
                                  : ble.connectedDevice!.remoteId.str),
                          trailing: ElevatedButton(
                            onPressed: () => ble.disconnect(),
                            child: const Text('Disconnect'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _myStatus == 'alive'
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Status: ${_myStatus.toUpperCase()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('K: $_myKills  D: $_myDeaths'),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () async {
                                  await ble.sendLines(_buildSnapshotLines());
                                },
                                child: const Text('Sync to Device'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Message to TTGO',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final text = _messageController.text.trim();
                                  if (text.isNotEmpty) {
                                    await ble.sendString(text);
                                    _messageController.clear();
                                  }
                                },
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('Received messages'),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: ble.receivedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = ble.receivedMessages[index];
                              return ListTile(
                                dense: true,
                                title: Text(msg),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
