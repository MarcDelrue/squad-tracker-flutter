part of 'tracker_screen.dart';

extension _TrackerBleLogicExt on _TrackerScreenState {
  void _maybeStartDataSync(BleService ble) async {
    final squad = SquadService().currentSquad;
    final user = UserService().currentUser;
    if (squad == null || user == null) return;

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
        final updatedAt =
            _maxDate(r.location?.updated_at, _lastActivityByUserId[uid]);
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

    _locationsSub ??= _combinedService!
        .userSquadLocationService.currentMembersLocationStream
        .listen((_) {
      final distances = _combinedService!
          .userSquadLocationService.currentMembersDistanceFromUser;
      if (distances == null) return;
      final locs =
          _combinedService!.userSquadLocationService.currentMembersLocation;
      if (locs != null) {
        for (final l in locs) {
          final ts = l.updated_at?.toUtc();
          if (ts != null) {
            _lastActivityByUserId[l.user_id] =
                _maxDate(_lastActivityByUserId[l.user_id], ts) ?? ts;
          }
        }
      }
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

    _gameMetaSub ??= GameService()
        .streamActiveGameMetaBySquad(int.parse(squad.id))
        .listen((meta) async {
      final newGameId = (meta == null) ? null : (meta['id'] as num?)?.toInt();
      final changed = newGameId != _activeGameId;
      if (!changed) return;
      if (newGameId == null) {
        _gameStartedAt = null;
        _gameElapsedSec = -1;
        _gameState = 'ended';
        _gameTicker?.cancel();
        _gameTicker = null;
        _sendSnapshotIfConnected(ble);
        return;
      }

      await _scoreboardSub?.cancel();
      _scoreboardSub = null;
      await _myStatsSub?.cancel();
      _myStatsSub = null;

      _activeGameId = newGameId;
      final s = meta?['started_at']?.toString();
      final start = s != null ? DateTime.tryParse(s) : null;
      _gameStartedAt = start;
      _gameElapsedSec =
          start == null ? -1 : DateTime.now().difference(start).inSeconds;
      _gameState = 'active';
      _lastTimerSyncSec = -1;
      _ensureGameTicker(ble);
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

      _scoreboardSub =
          GameService().streamScoreboardByGame(newGameId).listen((rows) {
        final Map<String, Map<String, dynamic>> byId = {};
        final Map<String, Map<String, dynamic>> prevById = _scoreByUserId;
        for (final r in rows) {
          final uid = r['user_id'] as String?;
          if (uid == null) continue;
          byId[uid] = {
            'kills': (r['kills'] ?? 0) as int,
            'deaths': (r['deaths'] ?? 0) as int,
            'status': r['user_status'] as String?,
          };
          // Mark activity ONLY for users whose scoreboard row actually changed
          final prev = prevById[uid];
          if (prev != null) {
            final int prevKills = (prev['kills'] ?? 0) as int;
            final int prevDeaths = (prev['deaths'] ?? 0) as int;
            final String prevStatus = (prev['status'] as String?) ?? '';
            final int curKills = (byId[uid]?['kills'] ?? 0) as int;
            final int curDeaths = (byId[uid]?['deaths'] ?? 0) as int;
            final String curStatus = (byId[uid]?['status'] as String?) ?? '';
            if (prevKills != curKills ||
                prevDeaths != curDeaths ||
                prevStatus != curStatus) {
              _lastActivityByUserId[uid] = DateTime.now().toUtc();
            }
          }
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
      final lines = _buildSnapshotLines();
      // Send immediately and update background snapshot cache
      ble.updateSnapshot(lines);
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
    final safeMyName = _myName.replaceAll(' ', '_');
    lines.add('MY_NAME $safeMyName');
    lines.add('MY_STATUS $_myStatus');
    lines.add('MY_KD $_myKills $_myDeaths');
    lines.add('MY_COLOR $_myColorHex');
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
    // Always send baseline for game timer state:
    // - Non-negative seconds => active game with elapsed timer
    // - -1 => no active game (device should stop timer and show label)
    if (_gameElapsedSec >= 0 && _shouldSendTimerBaseline()) {
      lines.add('GAME_ELAPSED $_gameElapsedSec');
    } else if (_gameElapsedSec < 0 && _shouldSendTimerBaseline()) {
      lines.add('GAME_ELAPSED -1');
    }
    // Also include explicit game state for UI messaging on device
    lines.add('GAME_STATE $_gameState');
    lines.add('ACK $_ackOpId');
    lines.add('SEQ $_seqCounter');
    lines.add('EOT');
    return lines;
  }

  // Send a HELP_REQ to device when a new help request comes in
  Future<void> sendHelpReqToDevice({
    required String requestId,
    required String requesterName,
    required String status, // help|medic
    required int distanceMeters,
    required String directionCardinal,
    required String colorHex,
  }) async {
    final ble = Provider.of<BleService>(context, listen: false);
    if (ble.connectedDevice == null) return;
    final safeName = requesterName.replaceAll(' ', '_');
    final line =
        'HELP_REQ $requestId $safeName $status $distanceMeters $directionCardinal ${colorHex.replaceAll('#', '').toUpperCase()}';
    try {
      await ble.sendString(line);
    } catch (_) {}
  }

  bool _shouldSendTimerBaseline() {
    return _lastTimerSyncSec == _gameElapsedSec || _seqCounter <= 2;
  }

  DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  void _handleInbound(String msg) {
    if (msg.startsWith('OP ')) {
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
            // Mark my own recent activity
            final me = UserService().currentUser;
            if (me != null) {
              _lastActivityByUserId[me.id] = DateTime.now().toUtc();
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
            final me = UserService().currentUser;
            if (me != null) {
              _lastActivityByUserId[me.id] = DateTime.now().toUtc();
            }
            _sendSnapshotIfConnected(
                Provider.of<BleService>(context, listen: false));
            GameService().bumpKill(int.parse(squad.id));
          }
          return;
        }
      }
    } else if (msg.contains('BTN_A_PRESS')) {
      final squad = SquadService().currentSquad;
      if (squad != null) {
        final wasAlive = _myStatus == 'alive';
        _myStatus = wasAlive ? 'dead' : 'alive';
        if (wasAlive) {
          _myDeaths = _myDeaths + 1;
        }
        final me = UserService().currentUser;
        if (me != null) {
          _lastActivityByUserId[me.id] = DateTime.now().toUtc();
        }
        _sendSnapshotIfConnected(
            Provider.of<BleService>(context, listen: false));
        final nextServer = _myStatus == 'alive' ? 'ALIVE' : 'DEAD';
        GameService().setStatus(squadId: squad.id, status: nextServer);
      }
    } else if (msg.contains('BTN_B_PRESS')) {
      final squad = SquadService().currentSquad;
      if (squad != null) {
        if (_myStatus == 'alive') {
          _myKills = _myKills + 1;
          _sendSnapshotIfConnected(
              Provider.of<BleService>(context, listen: false));
        }
        final me = UserService().currentUser;
        if (me != null) {
          _lastActivityByUserId[me.id] = DateTime.now().toUtc();
        }
        GameService().bumpKill(int.parse(squad.id));
      }
    }
    // Device replied to a help request
    if (msg.startsWith('HELP_RESP ')) {
      // Delegate to HelpNotificationService to centralize logic and RLS context
      // ignore: unawaited_futures
      HelpNotificationService().handleDeviceHelpRespLine(msg);
    }
  }

  void _ensureGameTicker(BleService ble) {
    if (_gameStartedAt == null) return;
    _gameTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final start = _gameStartedAt;
      if (start == null) return;
      final now = DateTime.now();
      final sec = now.difference(start).inSeconds;
      if (sec != _gameElapsedSec) {
        _gameElapsedSec = sec;
        if (_lastTimerSyncSec == -1 ||
            (sec / 300) != (_lastTimerSyncSec / 300)) {
          _lastTimerSyncSec = sec;
          _sendSnapshotIfConnected(
              Provider.of<BleService>(context, listen: false));
        }
      }
    });
  }

  Future<void> _ensurePermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.bluetoothPermanentlyDenied)),
        );
      }
    }
  }
}
