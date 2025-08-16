import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';

class SquadMembersList extends StatefulWidget {
  final VoidCallback?
      onFlyToMember; // Callback to hide bottom sheet when flying to member

  const SquadMembersList({super.key, this.onFlyToMember});

  @override
  State<SquadMembersList> createState() => _SquadMembersListState();
}

class _SquadMembersListState extends State<SquadMembersList> {
  final userService = UserService();
  final squadMembersService = SquadMembersService();
  final userSquadLocationService = UserSquadLocationService();
  final mapUserLocationService = MapUserLocationService();
  final squadService = SquadService();

  @override
  void initState() {
    super.initState();
    // Ensure squad members are loaded when widget initializes
    _loadSquadMembers();
  }

  Future<void> _loadSquadMembers() async {
    final currentUser = userService.currentUser;
    final currentSquad = squadService.currentSquad;

    if (currentUser != null && currentSquad != null) {
      debugPrint(
          'Loading squad members for user: ${currentUser.id}, squad: ${currentSquad.id}');
      try {
        await squadMembersService.getCurrentSquadMembers(
            currentUser.id, currentSquad.id);
        debugPrint('Squad members loaded successfully');
      } catch (e) {
        debugPrint('Error loading squad members: $e');
      }
    } else {
      debugPrint(
          'Cannot load squad members - user: ${currentUser?.id}, squad: ${currentSquad?.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserWithSession>?>(
      stream: squadMembersService.currentSquadMembersStream,
      builder: (context, snapshot) {
        // Debug information
        debugPrint(
            'SquadMembersList - Stream state: ${snapshot.connectionState}');
        debugPrint('SquadMembersList - Has data: ${snapshot.hasData}');
        debugPrint('SquadMembersList - Data: ${snapshot.data}');
        debugPrint(
            'SquadMembersList - Current squad members: ${squadMembersService.currentSquadMembers}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Loading squad members...',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadSquadMembers,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Check if we have an error or no data after waiting
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading squad members: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No squad members found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final members = snapshot.data!;
        final currentUserId = userService.currentUser?.id;

        // Filter out current user and sort by distance
        final otherMembers =
            members.where((member) => member.user.id != currentUserId).toList();

        // Sort by distance (closest first)
        otherMembers.sort((a, b) {
          final distanceA = userSquadLocationService
                  .currentMembersDistanceFromUser?[a.user.id] ??
              double.infinity;
          final distanceB = userSquadLocationService
                  .currentMembersDistanceFromUser?[b.user.id] ??
              double.infinity;
          return distanceA.compareTo(distanceB);
        });

        if (otherMembers.isEmpty) {
          return const Center(
            child: Text(
              'You are the only member in the squad',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Squad Members (${otherMembers.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Member tiles
            ...otherMembers.map((member) => _buildMemberTile(member)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(UserWithSession member) {
    final memberLocation = userSquadLocationService.currentMembersLocation
        ?.where((location) => location.user_id == member.user.id)
        .firstOrNull;

    final distance = userSquadLocationService
        .currentMembersDistanceFromUser?[member.user.id];
    final direction = userSquadLocationService
        .currentMembersDirectionToMember?[member.user.id];

    final memberColor = hexToColor(member.user.main_color ?? '#000000');
    final statusColor = _getStatusColor(member.session.user_status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: memberColor, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildMemberAvatar(member, memberColor),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.user.username ?? 'Unknown',
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
                _getStatusText(member.session.user_status),
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
            if (distance != null)
              Text(
                'Distance: ${distance.toStringAsFixed(0)}m',
                style: const TextStyle(color: Colors.grey),
              ),
            if (direction != null)
              Text(
                'Direction: ${_getDirectionText(direction)}',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.location_on,
            color: Colors.blue,
          ),
          onPressed: () => _flyToMember(memberLocation),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(UserWithSession member, Color memberColor) {
    return Container(
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
    );
  }

  Color _getStatusColor(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return Colors.green;
      case UserSquadSessionStatus.dead:
        return Colors.red;
      case UserSquadSessionStatus.help:
        return Colors.orange;
      case UserSquadSessionStatus.medic:
        return Colors.purple;
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

  void _flyToMember(UserSquadLocation? memberLocation) {
    if (memberLocation != null &&
        memberLocation.latitude != null &&
        memberLocation.longitude != null) {
      mapUserLocationService.flyToLocation(
        memberLocation.longitude!,
        memberLocation.latitude!,
      );
      // Hide bottom sheet when flying to member
      widget.onFlyToMember?.call();
    }
  }
}
