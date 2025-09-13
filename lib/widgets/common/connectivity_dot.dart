import 'dart:async';
import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class ConnectivityDot extends StatefulWidget {
  final String userId;
  final bool isYou;
  const ConnectivityDot({super.key, required this.userId, required this.isYou});

  @override
  State<ConnectivityDot> createState() => _ConnectivityDotState();
}

class _ConnectivityDotState extends State<ConnectivityDot> {
  final userSquadLocationService = UserSquadLocationService();
  StreamSubscription<List<UserSquadLocation>>? _sub;
  Timer? _tick;
  DateTime? _updatedAt;
  supa.RealtimeChannel? _ownChannel;
  supa.RealtimeChannel? _sessionChannel;
  supa.RealtimeChannel? _gameStatsChannel;
  late final String _chanSuffix;

  static const Duration _fresh = Duration(seconds: 20);
  static const Duration _warn = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _chanSuffix = DateTime.now().microsecondsSinceEpoch.toString();
    final seed = userSquadLocationService.currentMembersLocation?.firstWhere(
      (e) => e.user_id == widget.userId,
      orElse: () =>
          UserSquadLocation(id: -1, user_id: widget.userId, squad_id: -1),
    );
    if (seed != null && seed.id != -1) {
      _updatedAt = seed.updated_at;
    }
    if (_updatedAt == null && widget.isYou) {
      _updatedAt = userSquadLocationService.currentUserLocation?.updated_at;
    }
    _sub = userSquadLocationService.currentMembersLocationStream
        .listen((locations) {
      final l = locations.firstWhere(
        (e) => e.user_id == widget.userId,
        orElse: () =>
            UserSquadLocation(id: -1, user_id: widget.userId, squad_id: -1),
      );
      if (l.id != -1) {
        if (mounted)
          setState(() {
            if (l.updated_at != null) {
              _updatedAt = _maxDate(_updatedAt, l.updated_at);
            }
          });
      }
    });
    _ownChannel = supa.Supabase.instance.client
        .channel('user-${widget.userId}-own-location-dot-$_chanSuffix')
        .onPostgresChanges(
            event: supa.PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_squad_locations',
            filter: supa.PostgresChangeFilter(
              type: supa.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: widget.userId,
            ),
            callback: (payload) {
              final ts = payload.newRecord['updated_at']?.toString();
              if (ts != null) {
                var s = ts.trim();
                if (s.contains(' ') && !s.contains('T')) {
                  s = s.replaceFirst(' ', 'T');
                }
                if (!s.endsWith('Z') && !s.contains('+', 10)) {
                  s = '${s}Z';
                }
                final parsed = DateTime.tryParse(s);
                if (parsed != null) {
                  if (mounted) {
                    setState(() {
                      _updatedAt = _maxDate(_updatedAt, parsed.toUtc());
                    });
                  }
                }
              }
            })
        .subscribe();

    // Also react to user_squad_sessions changes (join/leave, heartbeat updates)
    _sessionChannel = supa.Supabase.instance.client
        .channel('user-${widget.userId}-session-dot-$_chanSuffix')
        .onPostgresChanges(
            event: supa.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'user_squad_sessions',
            filter: supa.PostgresChangeFilter(
              type: supa.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: widget.userId,
            ),
            callback: (payload) {
              _handleSessionPayload(payload);
            })
        .onPostgresChanges(
            event: supa.PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_squad_sessions',
            filter: supa.PostgresChangeFilter(
              type: supa.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: widget.userId,
            ),
            callback: (payload) {
              _handleSessionPayload(payload);
            })
        .subscribe();

    // And react to user_game_stats changes (kills/deaths/status changes)
    _gameStatsChannel = supa.Supabase.instance.client
        .channel('user-${widget.userId}-game-stats-dot-$_chanSuffix')
        .onPostgresChanges(
            event: supa.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'user_game_stats',
            filter: supa.PostgresChangeFilter(
              type: supa.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: widget.userId,
            ),
            callback: (payload) {
              _handleGameStatsRecord(payload.newRecord);
            })
        .onPostgresChanges(
            event: supa.PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_game_stats',
            filter: supa.PostgresChangeFilter(
              type: supa.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: widget.userId,
            ),
            callback: (payload) {
              _handleGameStatsRecord(payload.newRecord);
            })
        .subscribe();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
    _seedFromLatestGameStats();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    _ownChannel?.unsubscribe();
    _ownChannel = null;
    _sessionChannel?.unsubscribe();
    _sessionChannel = null;
    _gameStatsChannel?.unsubscribe();
    _gameStatsChannel = null;
    super.dispose();
  }

  Color get _color {
    final t = _updatedAt;
    if (t == null) return Colors.grey;
    final age = DateTime.now().toUtc().difference(t.toUtc());
    if (age <= _fresh) return Colors.green;
    if (age <= _warn) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1),
      ),
    );
  }

  void _handleSessionRecord(Map<String, dynamic> record) {
    final ts = (record['updated_at'] ?? record['created_at'])?.toString();
    if (ts != null) {
      var s = ts.trim();
      if (s.contains(' ') && !s.contains('T')) {
        s = s.replaceFirst(' ', 'T');
      }
      if (!s.endsWith('Z') && !s.contains('+', 10)) {
        s = '${s}Z';
      }
      final parsed = DateTime.tryParse(s);
      if (parsed != null && mounted) {
        setState(() {
          _updatedAt = _maxDate(_updatedAt, parsed.toUtc());
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _updatedAt = _maxDate(_updatedAt, DateTime.now().toUtc());
      });
    }
  }

  void _handleSessionPayload(supa.PostgresChangePayload payload) {
    final Map<String, dynamic>? newRec =
        payload.newRecord as Map<String, dynamic>?;
    final Map<String, dynamic>? oldRec =
        payload.oldRecord as Map<String, dynamic>?;
    if (newRec != null && oldRec != null) {
      final bool isActiveChanged = (newRec['is_active']?.toString() ?? '') !=
          (oldRec['is_active']?.toString() ?? '');
      if (isActiveChanged) {
        _handleSessionRecord(newRec);
      }
      return;
    }
    if (newRec != null) {
      _handleSessionRecord(newRec);
      return;
    }
  }

  void _handleGameStatsRecord(Map<String, dynamic> record) {
    // Any change in user_game_stats (kills, deaths, status) counts as fresh activity.
    if (mounted) {
      setState(() {
        _updatedAt = _maxDate(_updatedAt, DateTime.now().toUtc());
      });
    }
  }

  DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Future<void> _seedFromLatestGameStats() async {
    try {
      final sb = supa.Supabase.instance.client;
      final rows = await sb
          .from('user_game_stats')
          .select('last_status_change_at, updated_at, joined_at, created_at')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return;
      final Map<String, dynamic> r = rows.first;
      final ts = (r['last_status_change_at'] ??
              r['updated_at'] ??
              r['joined_at'] ??
              r['created_at'])
          ?.toString();
      if (ts == null) return;
      var s = ts.trim();
      if (s.contains(' ') && !s.contains('T')) {
        s = s.replaceFirst(' ', 'T');
      }
      if (!s.endsWith('Z') && !s.contains('+', 10)) {
        s = '${s}Z';
      }
      final parsed = DateTime.tryParse(s);
      if (parsed != null && mounted) {
        setState(() {
          _updatedAt = _maxDate(_updatedAt, parsed.toUtc());
        });
      }
    } catch (_) {}
  }
}
