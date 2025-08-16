import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/squad_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_annotations_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SquadService extends ChangeNotifier {
  // Singleton setup
  static final SquadService _singleton = SquadService._internal();
  factory SquadService() => _singleton;
  SquadService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final userSquadSessionService = UserSquadSessionService();
  final squadMembersService = SquadMembersService();
  final userSquadLocationService = UserSquadLocationService();
  final userService = UserService();
  final mapAnnotationsService = MapAnnotationsService();
  RealtimeChannel? currentSquadChannel;

  List<Squad>? recentSquads;
  Squad? _currentSquad;
  Squad? get currentSquad => _currentSquad;

  set currentSquad(Squad? value) {
    if (value != null) {
      squadMembersService.listenToSquadMembers(
          userService.currentUser!.id, value.id);
      // Load initial squad members data
      squadMembersService.getCurrentSquadMembers(
          userService.currentUser!.id, value.id);
      userSquadLocationService.getLastUserLocation(
          userService.currentUser!.id, value.id);
    } else {
      squadMembersService.unsubscribeFromSquadMembers();
      unsubscribeSquad();
    }
    _currentSquad = value;
    notifyListeners();
  }

  /// Fetches squad ID by UUID
  Future<String?> squadIdByUuid(String squadUuid) async {
    try {
      final response = await _supabase
          .from('squads')
          .select('id')
          .eq('uuid', squadUuid)
          .single();
      return response['id']?.toString();
    } catch (e) {
      debugPrint("Failed to get squad ID by UUID: $e");
      return null;
    }
  }

  /// Creates a new squad and returns the created squad's details
  Future<Squad?> createSquad(String squadName) async {
    try {
      final response = await _supabase
          .from('squads')
          .insert({'name': squadName})
          .select()
          .single();

      final createdSquad = Squad(
        id: response['id'].toString(),
        name: response['name'],
        uuid: response['uuid'],
      );
      return createdSquad;
    } catch (e) {
      debugPrint("Failed to create squad: $e");
      return null;
    }
  }

  Future<bool> updateSquadName(String squadId, String newName) async {
    try {
      await _supabase
          .from('squads')
          .update({'name': newName}).eq('id', squadId);
      return true;
    } catch (e) {
      debugPrint("Failed to update squad name: $e");
      return false;
    }
  }

  /// Sets the current squad based on user’s active session
  Future<void> setCurrentSquad(
      {required String userId, String? squadId}) async {
    try {
      squadId ??= await userSquadSessionService.getUserSquadSessionId(userId);

      if (squadId != null) {
        final response =
            await _supabase.from('squads').select().eq('id', squadId).single();

        if (response.isNotEmpty) {
          currentSquad = Squad(
            id: response['id'].toString(),
            name: response['name'],
            uuid: response['uuid'],
          );
          listenToSquad();
        } else {
          debugPrint('No squad found with ID: $squadId');
        }
      } else {
        debugPrint('No active squad session found for user ID: $userId');
      }
    } catch (e) {
      debugPrint("Failed to set current squad: $e");
    }
  }

  void listenToSquad() {
    if (currentSquadChannel != null) {
      return;
    }

    currentSquadChannel = _supabase
        .channel('squad-channel')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'squads',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: currentSquad!.id,
            ),
            callback: (PostgresChangePayload payload) {
              debugPrint('Squad change detected: $payload');
              currentSquad = Squad(
                id: payload.newRecord['id'].toString(),
                name: payload.newRecord['name'],
                uuid: payload.newRecord['uuid'],
              );
            })
        .subscribe();
  }

  void listenToUserSquadSession(String userId) {
    _supabase
        .channel('user-squad-session-channel')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_squad_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (PostgresChangePayload payload) {
              debugPrint('User squad session change detected: $payload');

              if (payload.newRecord['is_active'] == true) {
                // User joined a squad
                userSquadSessionService.currentSquadSession = UserSquadSession(
                    id: payload.newRecord['id'],
                    user_id: payload.newRecord['user_id'],
                    squad_id: payload.newRecord['squad_id'],
                    is_host: payload.newRecord['is_host'],
                    is_active: payload.newRecord['is_active'],
                    user_status: payload.newRecord['user_status'] != null
                        ? UserSquadSessionStatusExtension.fromValue(
                            payload.newRecord['user_status'])
                        : UserSquadSessionStatus.alive);
                setCurrentSquad(
                    userId: userId,
                    squadId: payload.newRecord['squad_id'].toString());
              } else if (payload.newRecord['is_active'] == false) {
                // User left the squad
                mapAnnotationsService.removeEveryAnnotations();
                currentSquad = null;
                userSquadSessionService.currentSquadSession = null;
                debugPrint('User left the squad');
              }
            })
        .subscribe();
  }

  Future<List<SquadWithUpdatedAt>?> getRecentSquads(String userId) async {
    try {
      final recentSessionsResponse = await _supabase
          .from('user_squad_sessions')
          .select('squad_id, updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(6);

      if (recentSessionsResponse.isEmpty) {
        return null;
      }

      // Create a map to store updated_at values for each squad_id
      final updatedAtMap = {
        for (var item in recentSessionsResponse)
          item['squad_id']: DateTime.parse(item['updated_at'])
      };

      final squadIds = updatedAtMap.keys.toList();

      final recentSquadsResponse =
          await _supabase.from('squads').select().inFilter('id', squadIds);

      if (recentSquadsResponse.isEmpty) {
        return null;
      }

      final recentSquads = recentSquadsResponse
          .map((item) => SquadWithUpdatedAt(
                id: item['id'].toString(),
                name: item['name'],
                uuid: item['uuid'],
                updatedAt: updatedAtMap[item['id']]!,
              ))
          .toList();

      // Sort recentSquads based on updated_at values
      recentSquads.sort((a, b) {
        final aId = int.parse(a.id);
        final bId = int.parse(b.id);
        return updatedAtMap[bId]!.compareTo(updatedAtMap[aId]!);
      });

      return recentSquads;
    } catch (e) {
      debugPrint("Failed to get recent squads: $e");
    }
    return null;
  }

  unsubscribeSquad() {
    debugPrint('Unsubscribing from squad changes...');
    if (currentSquadChannel != null) {
      currentSquadChannel!.unsubscribe();
    }
  }
}
