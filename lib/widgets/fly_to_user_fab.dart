import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';

class MapControlButtons extends StatelessWidget {
  final bool isGeolocationDisabled;
  final bool showBattleLogs;
  final VoidCallback onBattleLogsPressed;

  const MapControlButtons({
    super.key,
    required this.isGeolocationDisabled,
    required this.showBattleLogs,
    required this.onBattleLogsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final mapUserLocationService = MapUserLocationService();

    return Positioned(
      top: 16.0 + MediaQuery.of(context).padding.top,
      left: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fly to user button (top)
          ValueListenableBuilder<bool>(
            valueListenable: mapUserLocationService.isFollowingUser,
            builder: (context, isFollowing, _) {
              final bool disabled = isGeolocationDisabled;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: FloatingActionButton.small(
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
                ),
              );
            },
          ),

          // Battle logs button (middle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.small(
              heroTag: 'battle_logs_fab',
              onPressed: onBattleLogsPressed,
              backgroundColor: showBattleLogs ? Colors.blue : Colors.white,
              shape: CircleBorder(
                side: BorderSide(
                  color: showBattleLogs ? Colors.white : Colors.blue,
                  width: 2.0,
                ),
              ),
              child: Icon(
                Icons.list_alt,
                color: showBattleLogs ? Colors.white : Colors.blue,
              ),
            ),
          ),

          // Compass button (bottom)
          ValueListenableBuilder<double>(
            valueListenable: mapUserLocationService.cameraBearingDegrees,
            builder: (context, bearing, _) {
              final double radians = bearing * 3.141592653589793 / 180.0;
              return FloatingActionButton.small(
                heroTag: 'compass_fab',
                onPressed: () async {
                  await mapUserLocationService.resetNorth();
                },
                backgroundColor: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(
                    color: Colors.red,
                    width: 2.0,
                  ),
                ),
                child: Transform.rotate(
                  angle: radians,
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.red,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
