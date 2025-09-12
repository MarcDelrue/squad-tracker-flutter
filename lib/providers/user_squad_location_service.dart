import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/location/user_squad_location_controller.dart';

class UserSquadLocationService {
  static final UserSquadLocationService _singleton =
      UserSquadLocationService._internal();
  factory UserSquadLocationService() {
    return _singleton;
  }
  UserSquadLocationService._internal();

  final UserSquadLocationController _controller = UserSquadLocationController();

  late List<UserSquadLocation>? differenceWithPreviousLocation;

  // Facade getters
  UserSquadLocation? get currentUserLocation => _controller.currentUserLocation;

  List<UserSquadLocation>? get currentMembersLocation =>
      _controller.currentMembersLocation;

  Stream<List<UserSquadLocation>> get currentMembersLocationStream =>
      _controller.currentMembersLocationStream;

  Map<String, double>? get currentMembersDistanceFromUser =>
      _controller.currentMembersDistanceFromUser;

  Map<String, double>? get currentMembersDirectionFromUser =>
      _controller.currentMembersDirectionFromUser;

  Map<String, double>? get currentMembersDirectionToMember =>
      _controller.currentMembersDirectionToMember;

  Future<void> getLastUserLocation(String userId, String squadId) async {
    try {
      await _controller.loadCurrentUserLocation(
          userId: userId, squadId: squadId);
    } catch (e) {
      debugPrint('Error in getLastUserLocation: $e');
    }
  }

  Future<void> saveCurrentLocation(
      double longitude, double latitude, double? direction) async {
    try {
      await _controller.updateCurrentUserLocation(
        longitude: longitude,
        latitude: latitude,
        direction: direction,
      );
    } catch (e) {
      debugPrint('Error in saveCurrentLocation: $e');
    }
  }

  Future<List> fetchMembersLocation(
      List<String> membersId, String squadId) async {
    try {
      final prev =
          List<UserSquadLocation>.from(_controller.currentMembersLocation);
      final locations = await _controller.loadMembersLocations(
          memberIds: membersId, squadId: squadId);
      _getDifferencesWithPreviousLocation(locations, prev);
      return locations;
    } catch (e) {
      debugPrint('Error in fetchMembersLocation: $e');
      return [];
    }
  }

  // Realtime management handled by controller

  // Distances and directions handled by controller

  void updateMemberDirectionFromUser(double? userDirection) {
    _controller.updateMemberDirectionFromUser(userDirection);
  }

  void unsubscribeMemberLocations(String memberId) {
    final channel = _controller.membersLocationsChannels[memberId];
    channel?.unsubscribe();
    _controller.membersLocationsChannels.remove(memberId);
  }

  void _getDifferencesWithPreviousLocation(
      List<UserSquadLocation>? currentLocations,
      List<UserSquadLocation>? previousLocations) {
    if (currentLocations == null ||
        previousLocations == null ||
        currentLocations.isEmpty ||
        previousLocations.isEmpty) {
      differenceWithPreviousLocation = [];
      return;
    }

    final differences = currentLocations.where((currentLocation) {
      final previousLocation = previousLocations.firstWhere(
        (prevLocation) => prevLocation.user_id == currentLocation.user_id,
        orElse: () => currentLocation,
      );

      return previousLocation.longitude != currentLocation.longitude ||
          previousLocation.latitude != currentLocation.latitude ||
          previousLocation.direction != currentLocation.direction;
    }).toList();

    differenceWithPreviousLocation = differences;
  }

  void dispose() {
    _controller.dispose();
  }
}
