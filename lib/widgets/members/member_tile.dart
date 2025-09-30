import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';
import 'package:squad_tracker_flutter/widgets/common/connectivity_dot.dart';

class MemberTileProps {
  final int kills;
  final int deaths;
  final double? distanceMeters;
  final double? directionDegrees;
  final UserSquadSessionStatus? effectiveStatus;
  const MemberTileProps({
    required this.kills,
    required this.deaths,
    required this.distanceMeters,
    required this.directionDegrees,
    required this.effectiveStatus,
  });
}

class MemberTile extends StatelessWidget {
  final UserWithSession member;
  final MemberTileProps props;
  final UserSquadLocation? memberLocation;
  final bool isSelf;
  final MapUserLocationService mapUserLocationService;
  final UserService userService;
  final VoidCallback? onFlyToMember;

  const MemberTile({
    super.key,
    required this.member,
    required this.props,
    required this.memberLocation,
    required this.isSelf,
    required this.mapUserLocationService,
    required this.userService,
    this.onFlyToMember,
  });

  @override
  Widget build(BuildContext context) {
    final memberColor = hexToColor(member.user.main_color ?? '#000000');
    final statusColor = _getStatusColor(props.effectiveStatus);
    final kd =
        props.deaths == 0 ? props.kills.toDouble() : props.kills / props.deaths;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: memberColor, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildMemberAvatar(memberColor),
        title: Row(
          children: [
            Expanded(
              child: Text(
                isSelf
                    ? '${member.user.username ?? 'Unknown'} (you)'
                    : (member.user.username ?? 'Unknown'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusText(props.effectiveStatus),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSelf && props.distanceMeters != null)
              Text(
                'Distance: ${props.distanceMeters!.toStringAsFixed(0)}m',
                style: const TextStyle(color: Colors.grey),
              ),
            if (!isSelf && props.directionDegrees != null)
              Text(
                'Direction: ${_getDirectionText(props.directionDegrees!)}',
                style: const TextStyle(color: Colors.grey),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.sports_martial_arts,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('${props.kills}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 8),
                  const Icon(Icons.heart_broken,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('${props.deaths}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 8),
                  Text('K/D ${kd.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.location_on,
            color: memberColor,
          ),
          onPressed: () => _onGeolocatePressed(),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(Color memberColor) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: memberColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              (member.user.username ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: ConnectivityDot(userId: member.user.id, isYou: isSelf),
        ),
      ],
    );
  }

  void _onGeolocatePressed() async {
    if (isSelf) {
      await mapUserLocationService.toggleFollow();
      onFlyToMember?.call();
      return;
    }
    if (memberLocation != null &&
        memberLocation!.latitude != null &&
        memberLocation!.longitude != null) {
      mapUserLocationService.flyToLocation(
        memberLocation!.longitude!,
        memberLocation!.latitude!,
      );
      onFlyToMember?.call();
    }
  }

  Color _getStatusColor(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return Colors.green;
      case UserSquadSessionStatus.dead:
        return Colors.grey.shade700;
      case UserSquadSessionStatus.help:
        return Colors.orange;
      case UserSquadSessionStatus.medic:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return 'ALIVE';
      case UserSquadSessionStatus.dead:
        return 'DEAD';
      case UserSquadSessionStatus.help:
        return 'HELP';
      case UserSquadSessionStatus.medic:
        return 'MEDIC';
      default:
        return 'UNKNOWN';
    }
  }

  String _getDirectionText(double direction) {
    if (direction >= 337.5 || direction < 22.5) return 'N';
    if (direction >= 22.5 && direction < 67.5) return 'NE';
    if (direction >= 67.5 && direction < 112.5) return 'E';
    if (direction >= 112.5 && direction < 157.5) return 'SE';
    if (direction >= 157.5 && direction < 202.5) return 'S';
    if (direction >= 202.5 && direction < 247.5) return 'SW';
    if (direction >= 247.5 && direction < 292.5) return 'W';
    if (direction >= 292.5 && direction < 337.5) return 'NW';
    return 'N';
  }
}
