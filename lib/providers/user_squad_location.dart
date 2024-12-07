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
      debugPrint('Error in createInitialUserSquadLocation: $e');
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
          locations.add(UserSquadLocation(
              id: response['id'],
              user_id: response['user_id'],
              squad_id: response['squad_id'],
              longitude: response['longitude'],
              latitude: response['latitude'],
              direction: response['direction']));
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
              final updatedLocation = UserSquadLocation(
                id: payload.newRecord['id'],
                user_id: payload.newRecord['user_id'],
                squad_id: payload.newRecord['squad_id'],
                longitude: payload.newRecord['longitude'],
                latitude: payload.newRecord['latitude'],
                direction: payload.newRecord['direction'],
              );

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
