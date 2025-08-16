import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/distance_calculator_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSquadLocationService {
  static final UserSquadLocationService _singleton =
      UserSquadLocationService._internal();
  factory UserSquadLocationService() {
    return _singleton;
  }
  UserSquadLocationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DistanceCalculatorService distanceCalculatorService =
      DistanceCalculatorService();
  late List<UserSquadLocation>? differenceWithPreviousLocation;
  Map<String, RealtimeChannel>? membersLocationsChannels;

  UserSquadLocation? _currentUserLocation;
  UserSquadLocation? get currentUserLocation => _currentUserLocation;

  set currentUserLocation(UserSquadLocation? value) {
    _currentUserLocation = value;
    _updateMembersDistanceFromUser();
  }

  List<UserSquadLocation>? _currentMembersLocation;
  List<UserSquadLocation>? get currentMembersLocation =>
      _currentMembersLocation;

  set currentMembersLocation(List<UserSquadLocation>? value) {
    _getDifferencesWithPreviousLocation(value, _currentMembersLocation);
    _currentMembersLocation = value;
    if (_currentMembersLocation != null) {
      _currentMembersLocationController.add(_currentMembersLocation!);
    } else {
      _currentMembersLocationController.add([]);
    }
  }

  final _currentMembersLocationController =
      StreamController<List<UserSquadLocation>>.broadcast();
  Stream<List<UserSquadLocation>> get currentMembersLocationStream =>
      _currentMembersLocationController.stream;

  final Map<String, double> _currentMembersDistanceFromUser = {};
  Map<String, double>? get currentMembersDistanceFromUser =>
      _currentMembersDistanceFromUser;

  final Map<String, double> _currentMembersDirectionFromUser = {};
  Map<String, double>? get currentMembersDirectionFromUser =>
      _currentMembersDirectionFromUser;

  final Map<String, double> _currentMembersDirectionToMember = {};
  Map<String, double>? get currentMembersDirectionToMember =>
      _currentMembersDirectionToMember;

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
        currentUserLocation = null;
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
      currentUserLocation = null;
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

          try {
            UserSquadLocation memberLocation =
                UserSquadLocation.fromJson(response);

            // Only add location if it has valid coordinates
            if (memberLocation.longitude != null &&
                memberLocation.latitude != null) {
              // Only calculate distances if current user location exists and has valid coordinates
              if (currentUserLocation != null &&
                  currentUserLocation!.longitude != null &&
                  currentUserLocation!.latitude != null) {
                try {
                  _currentMembersDistanceFromUser[memberId] =
                      distanceCalculatorService.calculateDistanceFromUser(
                          memberLocation, currentUserLocation);
                  _currentMembersDirectionFromUser[memberId] =
                      distanceCalculatorService.calculateDirectionFromUser(
                          memberLocation, currentUserLocation, 0);
                  _currentMembersDirectionToMember[memberId] =
                      distanceCalculatorService.calculateDirectionToMember(
                          memberLocation, currentUserLocation);
                } catch (e) {
                  // Handle distance calculation errors silently
                }
              }
              locations.add(memberLocation);
            }
          } catch (e) {
            // Handle parsing errors silently
          }
        }
      }
      if (locations.isNotEmpty) {
        currentMembersLocation = locations;
      } else {
        currentMembersLocation = [];
      }
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
              try {
                if (payload.newRecord == null) {
                  return;
                }

                final updatedLocation =
                    UserSquadLocation.fromJson(payload.newRecord);

                // Only calculate distances if current user location exists
                if (currentUserLocation != null) {
                  _currentMembersDistanceFromUser[memberId] =
                      distanceCalculatorService.calculateDistanceFromUser(
                          updatedLocation, currentUserLocation);
                  _currentMembersDirectionFromUser[memberId] =
                      distanceCalculatorService.calculateDirectionFromUser(
                          updatedLocation, currentUserLocation, 0);
                  _currentMembersDirectionToMember[memberId] =
                      distanceCalculatorService.calculateDirectionToMember(
                          updatedLocation, currentUserLocation);
                }

                // Update currentMembersLocation
                final updatedMembersLocation =
                    currentMembersLocation?.map((location) {
                  return location.user_id == memberId
                      ? updatedLocation
                      : location;
                }).toList();

                currentMembersLocation = updatedMembersLocation;
              } catch (e) {
                // Handle errors silently
              }
            })
        .subscribe();

    membersLocationsChannels ??= {};
    membersLocationsChannels![memberId] = channel;
    debugPrint('Listener setup complete for member locations: $memberId');
  }

  _updateMembersDistanceFromUser() {
    if (_currentMembersDistanceFromUser.isEmpty ||
        currentMembersLocation == null) {
      return;
    }
    for (String memberId in _currentMembersDistanceFromUser.keys) {
      _currentMembersDistanceFromUser[memberId] =
          distanceCalculatorService.calculateDistanceFromUser(
              currentMembersLocation!
                  .firstWhere((location) => location.user_id == memberId),
              currentUserLocation);
      debugPrint(
          'Updated distance from user for member $memberId: ${_currentMembersDistanceFromUser[memberId]}');
    }
  }

  updateMemberDirectionFromUser(double? userDirection) {
    if (_currentMembersDirectionFromUser.isEmpty ||
        currentMembersLocation == null) {
      return;
    }
    for (String memberId in _currentMembersDirectionFromUser.keys) {
      _currentMembersDirectionFromUser[memberId] =
          distanceCalculatorService.calculateDirectionFromUser(
              currentMembersLocation!
                  .firstWhere((location) => location.user_id == memberId),
              currentUserLocation,
              userDirection);
      _currentMembersDirectionToMember[memberId] =
          distanceCalculatorService.calculateDirectionToMember(
              currentMembersLocation!
                  .firstWhere((location) => location.user_id == memberId),
              currentUserLocation);
      debugPrint(
          'Updated direction from user for member $memberId: ${_currentMembersDirectionFromUser[memberId]}');
    }
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

  void dispose() {
    _currentMembersLocationController.close();
  }
}
