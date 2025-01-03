import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';

class MemberInGameRow extends StatelessWidget {
  final String? name;
  final UserSquadSessionStatus? status;
  final double? latitude;
  final double? longitude;
  final MapUserLocationService mapUserLocationService =
      MapUserLocationService();

  MemberInGameRow({
    super.key,
    this.name,
    this.status,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name ?? 'No Name'),
        subtitle: Text(status?.value ?? 'No Status'),
        onTap: () {
          if (latitude != null && longitude != null) {
            mapUserLocationService.flyToLocation(latitude!, longitude!);
          }
        },
      ),
    );
  }
}
