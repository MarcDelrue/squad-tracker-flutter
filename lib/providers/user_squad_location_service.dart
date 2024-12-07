import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSquadLocationService extends ChangeNotifier {
  static final UserSquadLocationService _singleton =
      UserSquadLocationService._internal();
  factory UserSquadLocationService() {
    return _singleton;
  }
  UserSquadLocationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  late List<UserSquadLocation>? differenceWithPreviousLocation;
  Map<String, RealtimeChannel>? membersLocationsChannels;
  UserSquadLocation? _currentUserLocation;
  UserSquadLocation? get currentUserLocation => _currentUserLocation;

  set currentUserLocation(UserSquadLocation? value) {
    _currentUserLocation = value;
    _updateMembersDistanceFromUser();
    notifyListeners();
  }

  List<UserSquadLocation>? _currentMembersLocation;
  List<UserSquadLocation>? get currentMembersLocation =>
      _currentMembersLocation;

  set currentMembersLocation(List<UserSquadLocation>? value) {
    _getDifferencesWithPreviousLocation(value, _currentMembersLocation);
    _currentMembersLocation = value;
    notifyListeners();
  }

  Map<String, double>? _currentMembersDistanceFromUser = {};
  Map<String, double>? get currentMembersDistanceFromUser =>
      _currentMembersDistanceFromUser;

  set currentMembersDistanceFromUser(Map<String, double>? value) {
    _currentMembersDistanceFromUser = value;
    notifyListeners();
  }

  Future<void> getLastUserLocation(String userId, String squadId) async {
    try {
      final hasUserSquadLocation = await _supabase
          .from('user_squad_locations')
          .select()
          .eq('user_id', userId)
          .eq('squad_id', squadId)
          .maybeSingle();

      if (hasUserSquadLocation == null) {
        debugPrint('No user squad location found for user ID: $userId');
      } else {
        currentUserLocation = UserSquadLocation(
            id: hasUserSquadLocation['id'],
            user_id: hasUserSquadLocation['user_id'],
            squad_id: hasUserSquadLocation['squad_id'],
            longitude: hasUserSquadLocation['longitude'],
            latitude: hasUserSquadLocation['latitude']);
      }
    } catch (e) {
      debugPrint('Error in getLastUserLocation: $e');
    }
  }

  saveCurrentLocation(
      double longitude, double latitude, double? direction) async {
    try {
      await _supabase.from('user_squad_locations').update({
        'longitude': longitude,
        'latitude': latitude,
        'direction': direction
      }).eq('id', _currentUserLocation!.id);
      _updateMembersDistanceFromUser();
    } catch (e) {
      debugPrint('Error in saveCurrentLocation: $e');
    }
  }

  fetchMembersLocation(List<String> membersId, String squadId) async {
    try {
      final List<UserSquadLocation> locations = [];
      for (String memberId in membersId) {
        final response = await _supabase
            .from('user_squad_locations')
            .select()
            .eq('user_id', memberId)
            .eq('squad_id', squadId)
            .maybeSingle();

        if (response != null) {
          _listenMemberLocations(memberId, squadId);
          UserSquadLocation memberLocation =
              UserSquadLocation.fromJson(response);
          currentMembersDistanceFromUser![memberId] =
              _calculateDistanceFromUser(memberLocation);
          debugPrint(
              'Updated distance from user for member $memberId: ${currentMembersDistanceFromUser![memberId]}');

          locations.add(memberLocation);
        }
      }
      debugPrint('Fetched locations: $locations');
      currentMembersLocation = locations;
      return locations;
    } catch (e) {
      debugPrint('Error in fetchMembersLocation: $e');
      return [];
    }
  }

  _listenMemberLocations(String memberId, String squadId) {
    // Check if a channel for this memberId already exists
    if (membersLocationsChannels != null &&
        membersLocationsChannels!.containsKey(memberId)) {
      return; // Exit early if the channel already exists
    }

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
            callback: (PostgresChangePayload payload) {
              debugPrint('User squad location change detected: $payload');
              final updatedLocation =
                  UserSquadLocation.fromJson(payload.newRecord);
              currentMembersDistanceFromUser![memberId] =
                  _calculateDistanceFromUser(updatedLocation);
              debugPrint(
                  'Updated distance from user for member $memberId: ${currentMembersDistanceFromUser![memberId]}');

              // Update currentMembersLocation
              final updatedMembersLocation =
                  currentMembersLocation?.map((location) {
                return location.user_id == memberId
                    ? updatedLocation
                    : location;
              }).toList();

              currentMembersLocation = updatedMembersLocation;
            })
        .subscribe();

    membersLocationsChannels ??= {};
    membersLocationsChannels![memberId] = channel;
    debugPrint('Listener setup complete for member locations: $memberId');
  }

  _updateMembersDistanceFromUser() {
    for (String memberId in currentMembersDistanceFromUser!.keys) {
      currentMembersDistanceFromUser![memberId] = _calculateDistanceFromUser(
          currentMembersLocation!
              .firstWhere((location) => location.user_id == memberId));
      debugPrint(
          'Updated distance from user for member $memberId: ${currentMembersDistanceFromUser![memberId]}');
    }
  }

  _calculateDistanceFromUser(UserSquadLocation location) {
    if (currentUserLocation != null) {
      final distance = _calculateDistanceBetweenTwoLocations(
          location.latitude!,
          location.longitude!,
          currentUserLocation!.latitude!,
          currentUserLocation!.longitude!);
      return distance;
    }
    return 0;
  }

  double _calculateDistanceBetweenTwoLocations(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  unsubscribeMemberLocations(String memberId) {
    final channel = membersLocationsChannels![memberId];
    channel?.unsubscribe();
    membersLocationsChannels?.remove(memberId);
  }

  void _getDifferencesWithPreviousLocation(
      List<UserSquadLocation>? currentLocations,
      List<UserSquadLocation>? previousLocations) {
    debugPrint('Current locations: $currentLocations');
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

    debugPrint('Differences with previous location: $differences');
    differenceWithPreviousLocation = differences;
  }
}
