import 'package:flutter/material.dart';
import 'dart:async';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/widgets/navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class UserSessionRow extends StatelessWidget {
  final User user;
  final UserSquadSessionOptions options;
  final Function(User) onKickUser;
  final Function(User) onSetHost;

  const UserSessionRow({
    super.key,
    required this.user,
    required this.options,
    required this.onKickUser,
    required this.onSetHost,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hexToColor(user.main_color ?? ''),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: _ConnectivityDot(userId: user.id, isYou: options.is_you),
            ),
          ],
        ),
        title: Text(
          options.is_you
              ? '${user.username ?? ''} (you)'
              : (user.username ?? ''),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(user.main_role ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (options.is_host)
              const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
              ),
            if (options.is_you)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Switch to the User tab within the existing NavigationWidget
                  NavigationWidget.goToTab(0);
                },
              ),
            if (options.can_interact)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'kick') {
                    onKickUser(user);
                  } else if (value == 'setHost') {
                    onSetHost(user);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'kick',
                    child: Text('Kick User'),
                  ),
                  const PopupMenuItem(
                    value: 'setHost',
                    child: Text('Set as Host'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityDot extends StatefulWidget {
  final String userId;
  final bool isYou;
  const _ConnectivityDot({required this.userId, required this.isYou});

  @override
  State<_ConnectivityDot> createState() => _ConnectivityDotState();
}

class _ConnectivityDotState extends State<_ConnectivityDot> {
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
        setState(() => _updatedAt = l.updated_at);
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
                  setState(() {
                    _updatedAt = parsed.toUtc();
                  });
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
