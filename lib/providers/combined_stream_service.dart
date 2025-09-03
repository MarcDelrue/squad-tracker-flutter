import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/user_with_location_session_model.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';

class CombinedStreamService {
  final SquadMembersService squadMembersService;
  final UserSquadLocationService userSquadLocationService;

  CombinedStreamService({
    required this.squadMembersService,
    required this.userSquadLocationService,
  });

  Stream<List<UserWithLocationSession>?> get combinedStream async* {
    await for (var members in squadMembersService.currentSquadMembersStream) {
      final locations =
          await userSquadLocationService.currentMembersLocationStream.first;
      final usersWithLocation = members?.map((member) {
        final location =
            locations.firstWhere((loc) => loc.user_id == member.user.id);
        return UserWithLocationSession(
          userWithSession: member,
          location: location,
        );
      }).toList();
      yield usersWithLocation;
    }
  }
}
