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
      final int? squad = int.tryParse(squadId);
      if (squad == null) {
        debugPrint('Invalid squadId: $squadId');
        currentUserLocation = null;
        return;
      }

      final response = await _supabase.rpc('get_user_location', params: {
        'p_user': userId,
        'p_squad': squad,
      });

      dynamic row;
      if (response is List && response.isNotEmpty) {
        row = response.first;
      } else if (response is Map<String, dynamic>) {
        row = response;
      } else {
        row = null;
      }

      if (row == null) {
        debugPrint('No user squad location found for user ID: $userId');
        currentUserLocation = null;
      } else {
        // Decrypted via RPC
        currentUserLocation = UserSquadLocation.fromJson(row);
      }
    } catch (e) {
      debugPrint('Error in getLastUserLocation: $e');
      currentUserLocation = null;
    }
  }

  saveCurrentLocation(
      double longitude, double latitude, double? direction) async {
    try {
      if (_currentUserLocation == null) return;
      await _supabase.rpc('update_user_location', params: {
        'p_user': _currentUserLocation!.user_id,
        'p_squad': _currentUserLocation!.squad_id,
        'p_long': longitude,
        'p_lat': latitude,
        'p_dir': direction,
      });
      _updateMembersDistanceFromUser();
    } catch (e) {
      debugPrint('Error in saveCurrentLocation: $e');
    }
  }

  fetchMembersLocation(List<String> membersId, String squadId) async {
    try {
      final List<UserSquadLocation> locations = [];
      final int? squad = int.tryParse(squadId);
      if (squad == null) {
        debugPrint('Invalid squadId: $squadId');
        currentMembersLocation = [];
        return [];
      }

      if (membersId.isEmpty) {
        currentMembersLocation = [];
        return [];
      }

      final response = await _supabase.rpc('get_members_locations', params: {
        'p_users': membersId,
        'p_squad': squad,
      });

      final List<dynamic> rows =
          (response is List) ? response : (response == null ? [] : [response]);

      for (final row in rows) {
        try {
          final memberLocation =
              UserSquadLocation.fromJson(row as Map<String, dynamic>);
          final memberId = memberLocation.user_id;
          _listenMemberLocations(memberId, squadId);
          if (memberLocation.longitude != null &&
              memberLocation.latitude != null) {
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
              } catch (_) {}
            }
            locations.add(memberLocation);
          }
        } catch (_) {}
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
                final int? squad = int.tryParse(squadId);
                if (squad == null) return;
                // Refetch decrypted row via RPC on any change
                _supabase.rpc('get_user_location',
                    params: {'p_user': memberId, 'p_squad': squad}).then((res) {
                  dynamic row;
                  if (res is List && res.isNotEmpty) {
                    row = res.first;
                  } else if (res is Map<String, dynamic>) {
                    row = res;
                  } else {
                    row = null;
                  }
                  if (row == null) return;
                  final updatedLocation =
                      UserSquadLocation.fromJson(row as Map<String, dynamic>);
                  if (updatedLocation.updated_at != null) {
                    updatedLocation.updated_at =
                        updatedLocation.updated_at!.toUtc();
                  }
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
                  final updatedMembersLocation =
                      currentMembersLocation?.map((location) {
                    return location.user_id == memberId
                        ? updatedLocation
                        : location;
                  }).toList();
                  currentMembersLocation = updatedMembersLocation;
                });
              } catch (e) {
                // ignore
              }
            })
        .subscribe();

    membersLocationsChannels ??= {};
    membersLocationsChannels![memberId] = channel;
    if (kDebugMode) {
      debugPrint('Listener setup complete for member locations: $memberId');
    }
  }

  _updateMembersDistanceFromUser() {
    if (currentMembersLocation == null ||
        currentMembersLocation!.isEmpty ||
        currentUserLocation == null) {
      _currentMembersDistanceFromUser.clear();
      return;
    }

    final Set<String> presentMemberIds =
        currentMembersLocation!.map((e) => e.user_id).toSet();
    _currentMembersDistanceFromUser
        .removeWhere((memberId, _) => !presentMemberIds.contains(memberId));

    for (final location in currentMembersLocation!) {
      if (location.latitude != null && location.longitude != null) {
        _currentMembersDistanceFromUser[location.user_id] =
            distanceCalculatorService.calculateDistanceFromUser(
                location, currentUserLocation);
      }
    }
  }

  updateMemberDirectionFromUser(double? userDirection) {
    if (currentMembersLocation == null ||
        currentMembersLocation!.isEmpty ||
        currentUserLocation == null) {
      _currentMembersDirectionFromUser.clear();
      _currentMembersDirectionToMember.clear();
      return;
    }

    final Set<String> presentMemberIds =
        currentMembersLocation!.map((e) => e.user_id).toSet();
    _currentMembersDirectionFromUser
        .removeWhere((memberId, _) => !presentMemberIds.contains(memberId));
    _currentMembersDirectionToMember
        .removeWhere((memberId, _) => !presentMemberIds.contains(memberId));

    for (final location in currentMembersLocation!) {
      if (location.latitude != null && location.longitude != null) {
        _currentMembersDirectionFromUser[location.user_id] =
            distanceCalculatorService.calculateDirectionFromUser(
                location, currentUserLocation, userDirection);
        _currentMembersDirectionToMember[location.user_id] =
            distanceCalculatorService.calculateDirectionToMember(
                location, currentUserLocation);
      }
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
    _currentMembersLocationController.close();
  }
}
