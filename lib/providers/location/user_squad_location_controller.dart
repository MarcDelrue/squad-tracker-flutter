import 'dart:async';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/location/location_derived_state.dart';
import 'package:squad_tracker_flutter/providers/location/user_location_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSquadLocationController {
  final UserLocationRepository repository;
  final LocationDerivedState derived;
  final SupabaseClient _supabase = Supabase.instance.client;

  UserSquadLocationController({
    UserLocationRepository? repository,
    LocationDerivedState? derived,
  })  : repository = repository ?? UserLocationRepository(),
        derived = derived ?? LocationDerivedState();

  // State
  UserSquadLocation? currentUserLocation;
  List<UserSquadLocation> currentMembersLocation = <UserSquadLocation>[];
  final _currentMembersLocationController =
      StreamController<List<UserSquadLocation>>.broadcast();
  Stream<List<UserSquadLocation>> get currentMembersLocationStream =>
      _currentMembersLocationController.stream;

  Map<String, double> currentMembersDistanceFromUser = <String, double>{};
  Map<String, double> currentMembersDirectionFromUser = <String, double>{};
  Map<String, double> currentMembersDirectionToMember = <String, double>{};

  Map<String, RealtimeChannel> membersLocationsChannels =
      <String, RealtimeChannel>{};

  Future<void> loadCurrentUserLocation({
    required String userId,
    required String squadId,
  }) async {
    currentUserLocation =
        await repository.getUserLocation(userId: userId, squadId: squadId);
    _recomputeDistances();
  }

  Future<void> updateCurrentUserLocation({
    required double longitude,
    required double latitude,
    required double? direction,
  }) async {
    if (currentUserLocation == null) return;
    await repository.updateUserLocation(
        userId: currentUserLocation!.user_id,
        squadId: currentUserLocation!.squad_id.toString(),
        longitude: longitude,
        latitude: latitude,
        direction: direction);
    _recomputeDistances();
  }

  Future<List<UserSquadLocation>> loadMembersLocations({
    required List<String> memberIds,
    required String squadId,
  }) async {
    final locations = await repository.getMembersLocations(
        memberIds: memberIds, squadId: squadId);
    currentMembersLocation = locations;
    _currentMembersLocationController.add(List.unmodifiable(locations));
    _recomputeDistancesAndDirections();
    for (final l in locations) {
      _ensureMemberRealtime(l.user_id);
    }
    return locations;
  }

  void updateMemberDirectionFromUser(double? userDirection) {
    currentMembersDirectionFromUser = derived.computeDirectionsFromUser(
        members: currentMembersLocation,
        currentUser: currentUserLocation,
        userDirection: userDirection);
    currentMembersDirectionToMember = derived.computeDirectionsToMember(
        members: currentMembersLocation, currentUser: currentUserLocation);
  }

  void _recomputeDistances() {
    currentMembersDistanceFromUser = derived.computeDistances(
        members: currentMembersLocation, currentUser: currentUserLocation);
  }

  void _recomputeDistancesAndDirections() {
    _recomputeDistances();
    updateMemberDirectionFromUser(0);
  }

  void _ensureMemberRealtime(String memberId) {
    if (membersLocationsChannels.containsKey(memberId)) return;
    final channel = _supabase
        .channel('member-$memberId-locations-channel')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_squad_locations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: memberId,
            ),
            callback: (payload) async {
              try {
                final squad = currentUserLocation?.squad_id;
                if (squad == null) return;
                final loc = await repository.getUserLocation(
                    userId: memberId, squadId: squad.toString());
                if (loc == null) return;
                final idx = currentMembersLocation
                    .indexWhere((e) => e.user_id == memberId);
                if (idx >= 0) {
                  currentMembersLocation[idx] = loc;
                } else {
                  currentMembersLocation.add(loc);
                }
                _currentMembersLocationController
                    .add(List.unmodifiable(currentMembersLocation));
                _recomputeDistancesAndDirections();
              } catch (_) {}
            })
        .subscribe();
    membersLocationsChannels[memberId] = channel;
  }

  void dispose() {
    for (final c in membersLocationsChannels.values) {
      c.unsubscribe();
    }
    membersLocationsChannels.clear();
    _currentMembersLocationController.close();
  }
}
