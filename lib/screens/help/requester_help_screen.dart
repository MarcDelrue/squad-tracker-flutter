import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/distance_calculator_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequesterHelpScreen extends StatefulWidget {
  final String requestId;
  const RequesterHelpScreen({super.key, required this.requestId});

  @override
  State<RequesterHelpScreen> createState() => _RequesterHelpScreenState();
}

class _RequesterHelpScreenState extends State<RequesterHelpScreen> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<_HelperRow> _helpers = [];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    final sb = Supabase.instance.client;
    final loc = context.read<UserSquadLocationService>();
    final dist = context.read<DistanceCalculatorService>();

    _sub = sb
        .from('help_responses')
        .stream(primaryKey: ['id'])
        .eq('request_id', widget.requestId)
        .listen((rows) async {
          final accepted =
              rows.where((r) => r['response'] == 'accepted').toList();
          final List<_HelperRow> out = [];
          for (final r in accepted) {
            final uid = r['responder_id'] as String;
            final u = await sb
                .from('users')
                .select('username, main_color')
                .eq('id', uid)
                .maybeSingle();
            final my = loc.currentUserLocation;
            final theirList = loc.currentMembersLocation
                ?.where((l) => l.user_id == uid)
                .toList();
            final their = (theirList != null && theirList.isNotEmpty)
                ? theirList.first
                : null;
            double? meters, bearing;
            if (my != null && their != null) {
              meters = dist.calculateDistanceFromUser(their, my);
              bearing = dist.calculateDirectionToMember(their, my);
            }
            out.add(_HelperRow(
              username: (u?['username'] as String?) ?? 'Teammate',
              color: (u?['main_color'] as String?) ?? '#FFFFFF',
              distance: meters?.round(),
              bearingCardinal:
                  bearing != null ? _bearingToCardinal(bearing) : null,
            ));
          }
          if (mounted) setState(() => _helpers = out);
        });
  }

  String _bearingToCardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg % 360) / 45).round() % 8];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    final sb = Supabase.instance.client;
    await sb.from('help_requests').update({
      'resolved_at': DateTime.now().toIso8601String(),
      'resolution': 'auto_dismissed'
    }).eq('id', widget.requestId);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help requested')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _helpers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final h = _helpers[i];
                  return ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Color(
                            int.parse(h.color.replaceFirst('#', '0xff')))),
                    title: Text(h.username),
                    subtitle: Text([
                      if (h.distance != null) '${h.distance} m',
                      if (h.bearingCardinal != null) h.bearingCardinal!,
                    ].join(' • ')),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelperRow {
  final String username;
  final String color;
  final int? distance;
  final String? bearingCardinal;
  _HelperRow(
      {required this.username,
      required this.color,
      this.distance,
      this.bearingCardinal});
}
