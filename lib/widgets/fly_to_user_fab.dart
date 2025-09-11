import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';

class MapControlButtons extends StatelessWidget {
  final bool isGeolocationDisabled;
  final VoidCallback onBattleLogsPressed;

  const MapControlButtons({
    super.key,
    required this.isGeolocationDisabled,
    required this.onBattleLogsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final mapUserLocationService = MapUserLocationService();

    return Stack(
      children: [
        // Fly to user button
        Positioned(
          top: 16.0 + MediaQuery.of(context).padding.top,
          left: 16.0,
          child: ValueListenableBuilder<bool>(
              valueListenable: mapUserLocationService.isFollowingUser,
              builder: (context, isFollowing, _) {
                final bool disabled = isGeolocationDisabled;
                return FloatingActionButton.small(
                  heroTag: 'fly_to_user_fab',
                  onPressed: disabled
                      ? null
                      : () => mapUserLocationService.toggleFollow(),
                  backgroundColor: disabled
                      ? Colors.grey
                      : (isFollowing ? Colors.green : Colors.white),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: disabled
                          ? Colors.grey
                          : (isFollowing ? Colors.white : Colors.green),
                      width: 2.0,
                    ),
                  ),
                  child: Icon(
                    isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: disabled
                        ? Colors.white
                        : (isFollowing ? Colors.white : Colors.green),
                  ),
                );
              }),
        ),

        // Show battle logs button
        Positioned(
          top: 16.0 + MediaQuery.of(context).padding.top,
          left: 80.0, // Positioned to the right of the fly to user button
          child: FloatingActionButton.small(
            heroTag: 'battle_logs_fab',
            onPressed: onBattleLogsPressed,
            backgroundColor: Colors.white,
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.blue,
                width: 2.0,
              ),
            ),
            child: const Icon(
              Icons.list_alt,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }
}
