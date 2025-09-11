import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserLocationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<UserSquadLocation?> getUserLocation({
    required String userId,
    required String squadId,
  }) async {
    try {
      final int? squad = int.tryParse(squadId);
      if (squad == null) return null;
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
      if (row == null) return null;
      return UserSquadLocation.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      debugPrint('UserLocationRepository.getUserLocation error: $e');
      return null;
    }
  }

  Future<List<UserSquadLocation>> getMembersLocations({
    required List<String> memberIds,
    required String squadId,
  }) async {
    try {
      final int? squad = int.tryParse(squadId);
      if (squad == null) return <UserSquadLocation>[];
      if (memberIds.isEmpty) return <UserSquadLocation>[];
      final response = await _supabase.rpc('get_members_locations', params: {
        'p_users': memberIds,
        'p_squad': squad,
      });
      final List<dynamic> rows =
          (response is List) ? response : (response == null ? [] : [response]);
      return rows
          .map((row) => UserSquadLocation.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('UserLocationRepository.getMembersLocations error: $e');
      return <UserSquadLocation>[];
    }
  }

  Future<void> updateUserLocation({
    required String userId,
    required String squadId,
    required double longitude,
    required double latitude,
    required double? direction,
  }) async {
    try {
      final int? squad = int.tryParse(squadId);
      if (squad == null) return;
      await _supabase.rpc('update_user_location', params: {
        'p_user': userId,
        'p_squad': squad,
        'p_long': longitude,
        'p_lat': latitude,
        'p_dir': direction,
      });
    } catch (e) {
      debugPrint('UserLocationRepository.updateUserLocation error: $e');
    }
  }
}
