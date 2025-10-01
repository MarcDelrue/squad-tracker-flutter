import 'dart:async';
import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/distance_calculator_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:squad_tracker_flutter/providers/help_notification_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HelperAssistScreen extends StatefulWidget {
  final String requestId;
  const HelperAssistScreen({super.key, required this.requestId});

  @override
  State<HelperAssistScreen> createState() => _HelperAssistScreenState();
}

class _HelperAssistScreenState extends State<HelperAssistScreen> {
  Timer? _tick;
  double? _distance;
  double? _bearing;
  String _name = '';
  String _color = '#FFFFFF';
  // Reserved for future use (e.g., inline resolved banner)
  // ignore: unused_field
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final sb = Supabase.instance.client;
    final loc = UserSquadLocationService();
    final dist = DistanceCalculatorService();

    final rows = await sb
        .from('help_requests')
        .select('id, requester_id, resolved_at')
        .eq('id', widget.requestId)
        .limit(1);
    if (rows.isEmpty) return;
    final requesterId = rows.first['requester_id'] as String;
    if (rows.first['resolved_at'] != null) {
      if (mounted) setState(() => _resolved = true);
      return;
    }

    final user = await sb
        .from('users')
        .select('username, main_color')
        .eq('id', requesterId)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _name = (user?['username'] as String?) ?? 'Teammate';
        _color = (user?['main_color'] as String?) ?? '#FFFFFF';
      });
    }

    // Send an immediate GUIDE line to show overlay even before we have distance
    try {
      final ble = BleService.global;
      if (ble != null && ble.connectedDevice != null) {
        final safeName =
            (_name.isEmpty ? 'Teammate' : _name).replaceAll(' ', '_');
        final line =
            'HELP_GUIDE ${widget.requestId} $safeName -1  ${_color.replaceAll('#', '').toUpperCase()}';
        // ignore: unawaited_futures
        ble.sendString(line);
      }
    } catch (_) {}

    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      final me = loc.currentUserLocation;
      final targetList = loc.currentMembersLocation
          ?.where((l) => l.user_id == requesterId)
          .toList();
      final target = (targetList != null && targetList.isNotEmpty)
          ? targetList.first
          : null;
      if (me != null && target != null) {
        final d = dist.calculateDistanceFromUser(target, me);
        final b = dist.calculateDirectionToMember(target, me);
        if (mounted)
          setState(() {
            _distance = d;
            _bearing = b;
          });
        final ble = BleService.global;
        if (ble != null && ble.connectedDevice != null) {
          final dirCard = _bearingToCardinal(b);
          final safeName = _name.replaceAll(' ', '_');
          final line =
              'HELP_GUIDE ${widget.requestId} $safeName ${d.round()} $dirCard ${_color.replaceAll('#', '').toUpperCase()}';
          // ignore: unawaited_futures
          ble.sendString(line);
        }
      }
      final hr = await sb
          .from('help_requests')
          .select('resolved_at')
          .eq('id', widget.requestId)
          .maybeSingle();
      if ((hr?['resolved_at']) != null && mounted) {
        setState(() => _resolved = true);
        _tick?.cancel();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _bearingToCardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg % 360) / 45).round() % 8];
  }

  Future<void> _cancel() async {
    await context
        .read<HelpNotificationService>()
        .handleResponse(widget.requestId, HelpResponse.ignore);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Helping $_name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_name,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_distance != null)
              Text('${_distance!.round()} m',
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_bearing != null)
              Text(_bearingToCardinal(_bearing!),
                  style: const TextStyle(fontSize: 24)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
