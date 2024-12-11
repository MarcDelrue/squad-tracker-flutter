import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';

class FlyToUserFab extends StatefulWidget {
  const FlyToUserFab({
    super.key,
  });

  @override
  _FlyToUserFabState createState() => _FlyToUserFabState();
}

class _FlyToUserFabState extends State<FlyToUserFab> {
  final mapUserLocationService = MapUserLocationService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FloatingActionButton.small(
        onPressed: () => {
          mapUserLocationService.flyToUserLocation(),
        },
        backgroundColor: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(
            color: Colors.green,
            width: 2.0,
          ),
        ),
        child: const Icon(
          Icons.my_location,
          color: Colors.green,
        ),
      ),
    );
  }
}
