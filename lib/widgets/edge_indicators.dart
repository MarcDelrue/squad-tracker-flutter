import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';
import 'dart:async';
import 'dart:math' as math;

class EdgeIndicators extends StatefulWidget {
  const EdgeIndicators({super.key});

  @override
  State<EdgeIndicators> createState() => _EdgeIndicatorsState();
}

class _EdgeIndicatorsState extends State<EdgeIndicators> {
  final userSquadLocationService = UserSquadLocationService();
  final userService = UserService();
  final squadMembersService = SquadMembersService();

  // Timer to update arrow directions more frequently
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Start timer to update arrows more frequently
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          // Force rebuild to update arrow directions
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserSquadLocation>>(
      stream: userSquadLocationService.currentMembersLocationStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final members = snapshot.data!;
        final offScreenMembers = _getOffScreenMembers(members);

        if (offScreenMembers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: offScreenMembers.map((member) {
            return _buildEdgeIndicator(member);
          }).toList(),
        );
      },
    );
  }

  List<UserSquadLocation> _getOffScreenMembers(
      List<UserSquadLocation> members) {
    // Show indicators for members that are very far away (>200m)
    // This is a simple heuristic - in a real implementation you'd check
    // if markers are actually off-screen by converting map coordinates
    return members
        .where((member) =>
            member.latitude != null &&
            member.longitude != null &&
            member.user_id != userService.currentUser?.id &&
            _isMemberFarAway(member))
        .toList();
  }

  bool _isMemberFarAway(UserSquadLocation member) {
    final distance = userSquadLocationService
        .currentMembersDistanceFromUser?[member.user_id];
    return distance != null && distance > 200; // Show indicator if >200m away
  }

  Widget _buildEdgeIndicator(UserSquadLocation member) {
    final distance = userSquadLocationService
        .currentMembersDistanceFromUser?[member.user_id];
    final direction = userSquadLocationService
        .currentMembersDirectionToMember?[member.user_id];

    if (distance == null || direction == null) {
      return const SizedBox.shrink();
    }

    // Get member's color
    final memberColor = _getMemberColor(member.user_id);

    // Calculate position on map edge
    final position = _calculateEdgePosition(direction);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: _buildIndicatorArrow(
          distance, direction, member.user_id, memberColor),
    );
  }

  Color _getMemberColor(String userId) {
    try {
      final member = squadMembersService.getMemberDataById(userId);
      return hexToColor(member.user.main_color ?? '#000000');
    } catch (e) {
      return Colors.blue; // Default color if member not found
    }
  }

  Offset _calculateEdgePosition(double direction) {
    final screenSize = MediaQuery.of(context).size;

    // Account for safe areas and UI elements
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Define the map area (excluding UI elements)
    final mapTop = topPadding + 80; // Space for top buttons
    final mapBottom =
        screenSize.height - bottomPadding - 200; // Space for bottom sheet
    final mapLeft = 16; // Left margin
    final mapRight =
        screenSize.width - 80; // Right margin (space for FAB buttons)

    final mapCenterX = (mapLeft + mapRight) / 2;
    final mapCenterY = (mapTop + mapBottom) / 2;
    final mapRadius = math.min(mapRight - mapLeft, mapBottom - mapTop) * 0.45;

    // Convert direction to radians and calculate position on map edge
    final angle = direction * (math.pi / 180);
    final x = mapCenterX + mapRadius * math.cos(angle);
    final y = mapCenterY -
        mapRadius * math.sin(angle); // Negative because screen Y is inverted

    // Clamp to map bounds
    final clampedX = x.clamp(mapLeft + 20.0, mapRight - 20.0);
    final clampedY = y.clamp(mapTop + 20.0, mapBottom - 20.0);

    return Offset(clampedX, clampedY);
  }

  Widget _buildIndicatorArrow(
      double distance, double direction, String userId, Color memberColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: memberColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: direction * (math.pi / 180),
            child: Icon(
              Icons.arrow_upward,
              color: memberColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${distance.toStringAsFixed(0)}m',
            style: TextStyle(
              color: memberColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
