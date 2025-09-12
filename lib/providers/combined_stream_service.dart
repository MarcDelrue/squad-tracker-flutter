import 'dart:async';
import 'package:squad_tracker_flutter/models/user_with_location_session_model.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
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
      // Use the latest cached locations immediately so joins/leaves reflect
      // on the device without waiting for a location stream emission.
      final locations = userSquadLocationService.currentMembersLocation ??
          const <UserSquadLocation>[];

      if (members == null || members.isEmpty) {
        yield const <UserWithLocationSession>[];
        continue;
      }

      final usersWithLocation = members.map((member) {
        final location = locations.firstWhere(
          (loc) => loc.user_id == member.user.id,
          orElse: () => UserSquadLocation(
            id: -1,
            user_id: member.user.id,
            squad_id: member.session.squad_id,
            latitude: null,
            longitude: null,
            direction: null,
            updated_at: null,
          ),
        );
        return UserWithLocationSession(
          userWithSession: member,
          location: location.id == -1 ? null : location,
        );
      }).toList();

      yield usersWithLocation;
    }
  }
}
