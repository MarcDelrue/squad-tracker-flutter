import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';

class MemberInGameRow extends StatelessWidget {
  final String? name;
  final UserSquadSessionStatus? status;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeenAt;
  final MapUserLocationService mapUserLocationService =
      MapUserLocationService();

  MemberInGameRow({
    super.key,
    this.name,
    this.status,
    this.latitude,
    this.longitude,
    this.lastSeenAt,
  });

  @override
  Widget build(BuildContext context) {
    final health = _healthColor(lastSeenAt);
    final lastSeenText = _formatLastSeen(lastSeenAt);
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: health, radius: 6),
        title: Text(name ?? 'No Name'),
        subtitle: Text(
          '${status?.value ?? 'No Status'}${lastSeenText != null ? ' • $lastSeenText' : ''}',
        ),
        onTap: () {
          if (latitude != null && longitude != null) {
            mapUserLocationService.flyToLocation(latitude!, longitude!);
          }
        },
      ),
    );
  }

  Color _healthColor(DateTime? lastSeen) {
    if (lastSeen == null) return Colors.grey;
    final age = DateTime.now().difference(lastSeen);
    if (age.inSeconds <= 20) return Colors.green;
    if (age.inSeconds <= 60) return Colors.orange;
    return Colors.red;
  }

  String? _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return null;
    final age = DateTime.now().difference(lastSeen);
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    return '${age.inHours}h ago';
  }
}
