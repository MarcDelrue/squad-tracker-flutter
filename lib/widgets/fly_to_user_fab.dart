import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';

class FlyToUserFab extends StatelessWidget {
  final bool isDisabled;

  const FlyToUserFab({super.key, required this.isDisabled});

  @override
  Widget build(BuildContext context) {
    final mapUserLocationService = MapUserLocationService();

    return Stack(
      children: [
        Positioned(
          top: 16.0 + MediaQuery.of(context).padding.top,
          left: 16.0,
          child: FloatingActionButton.small(
            onPressed: isDisabled
                ? null
                : () => mapUserLocationService.flyToUserLocation(),
            backgroundColor: isDisabled ? Colors.grey : Colors.white,
            shape: CircleBorder(
              side: BorderSide(
                color: isDisabled ? Colors.grey : Colors.green,
                width: 2.0,
              ),
            ),
            child: Icon(
              Icons.my_location,
              color: isDisabled ? Colors.white : Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}
