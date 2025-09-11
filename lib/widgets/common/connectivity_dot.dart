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

  static const Duration _fresh = Duration(seconds: 20);
  static const Duration _warn = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
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
        if (mounted) setState(() => _updatedAt = l.updated_at);
      }
    });
    _ownChannel = supa.Supabase.instance.client
        .channel('user-${widget.userId}-own-location-dot')
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
                  s = s + 'Z';
                }
                final parsed = DateTime.tryParse(s);
                if (parsed != null) {
                  if (mounted) {
                    setState(() {
                      _updatedAt = parsed.toUtc();
                    });
                  }
                }
              }
            })
        .subscribe();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    if (_ownChannel != null) {
      supa.Supabase.instance.client.removeChannel(_ownChannel!);
      _ownChannel = null;
    }
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
}
