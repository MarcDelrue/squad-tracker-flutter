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
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hexToColor(user.main_color ?? ''),
          ),
        ),
        title: Text(
          options.is_you
              ? '${user.username ?? ''} (you)'
              : (user.username ?? ''),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: _LastUpdatedSubtitle(
            userId: user.id, role: user.main_role, isYou: options.is_you),
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

class _LastUpdatedSubtitle extends StatefulWidget {
  final String userId;
  final String? role;
  final bool isYou;
  const _LastUpdatedSubtitle(
      {required this.userId, required this.role, required this.isYou});

  @override
  State<_LastUpdatedSubtitle> createState() => _LastUpdatedSubtitleState();
}

class _LastUpdatedSubtitleState extends State<_LastUpdatedSubtitle> {
  final userSquadLocationService = UserSquadLocationService();
  StreamSubscription<List<UserSquadLocation>>? _sub;
  Timer? _tick;
  DateTime? _updatedAt;
  supa.RealtimeChannel? _ownChannel;

  static const Duration _staleThreshold = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    // Seed from members list if present
    final seed = userSquadLocationService.currentMembersLocation?.firstWhere(
      (e) => e.user_id == widget.userId,
      orElse: () =>
          UserSquadLocation(id: -1, user_id: widget.userId, squad_id: -1),
    );
    if (seed != null && seed.id != -1) {
      _updatedAt = seed.updated_at;
    }
    // If own row and still null, seed from own location
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
    // Direct subscription to this user's location row for immediate updates
    _ownChannel = supa.Supabase.instance.client
        .channel('user-${widget.userId}-own-location')
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
                // Normalize to UTC
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
    // Periodic tick so the label refreshes (e.g., "12s ago")
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
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

  bool get _isStale {
    if (_updatedAt == null) return true;
    return DateTime.now().toUtc().difference(_updatedAt!.toUtc()) >
        _staleThreshold;
  }

  String _relativeTime() {
    final t = _updatedAt;
    if (t == null) return 'no location';
    final d = DateTime.now().toUtc().difference(t.toUtc());
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.role ?? '';
    final time = _relativeTime();
    final color = _isStale ? Colors.orange : Colors.grey;
    final List<Widget> children = [];
    if (text.isNotEmpty) {
      children.add(Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }
    if (text.isNotEmpty) children.add(const SizedBox(width: 6));
    children.add(Icon(
      _isStale ? Icons.warning_amber_rounded : Icons.schedule,
      size: 14,
      color: color,
    ));
    children.add(const SizedBox(width: 4));
    children.add(Text(time, style: TextStyle(color: color)));

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
