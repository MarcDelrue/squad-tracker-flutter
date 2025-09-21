import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class HelpRequest {
  final String requestId;
  final String requesterId;
  final String requesterName;
  final UserSquadSessionStatus status; // HELP or MEDIC
  final double? distanceMeters;
  final double?
      directionDegrees; // 0-360 bearing from current user to requester
  final DateTime timestamp;
  final String? requesterAvatarUrl;
  final int requesterKills;
  final int requesterDeaths;
  final String? requesterColorHex;

  const HelpRequest({
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    required this.distanceMeters,
    required this.directionDegrees,
    required this.timestamp,
    required this.requesterAvatarUrl,
    required this.requesterKills,
    required this.requesterDeaths,
    required this.requesterColorHex,
  });
}
