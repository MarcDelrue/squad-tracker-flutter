import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squad_tracker_flutter/providers/map_annotations_service.dart';

class UserSquadSessionService extends ChangeNotifier {
  // Singleton setup
  static final UserSquadSessionService _singleton =
      UserSquadSessionService._internal();
  factory UserSquadSessionService() => _singleton;
  UserSquadSessionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  MapAnnotationsService get mapAnnotationsService => MapAnnotationsService();

  UserSquadSession? _currentSquadSession;
  UserSquadSession? get currentSquadSession => _currentSquadSession;

  set currentSquadSession(UserSquadSession? value) {
    _currentSquadSession = value;
    notifyListeners();
  }

  /// Creates a new squad session for the user
  Future<void> createUserSquadSession({
    required String userId,
    required String squadId,
    required bool isHost,
  }) async {
    try {
      await _supabase.from('user_squad_sessions').insert({
        'user_id': userId,
        'squad_id': squadId,
        'is_host': isHost,
      });
    } catch (e) {
      throw Exception('Failed to join squad: $e');
    }
  }

  /// Marks the squad session as active for the user to join the squad
  Future<bool> joinSquad(String userId, String squadId) async {
    try {
      final response = await _supabase
          .from('user_squad_sessions')
          .select()
          .eq('user_id', userId)
          .eq('squad_id', squadId)
          .maybeSingle();

      if (response != null) {
        await _supabase
            .from('user_squad_sessions')
            .update({'is_active': true})
            .eq('user_id', userId)
            .eq('squad_id', squadId);
      } else {
        await createUserSquadSession(
            userId: userId, squadId: squadId, isHost: false);
      }

      return true;
    } catch (e) {
      debugPrint("Failed to join squad: $e");
      return false;
    }
  }

  /// Marks the squad session as inactive for the user to leave the squad
  Future<void> leaveSquad(String userId, String squadId) async {
    try {
      final response = await _supabase
          .from('user_squad_sessions')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('squad_id', squadId)
          .select();
      mapAnnotationsService.removeEveryAnnotations();
      debugPrint('User left squad: $response');
    } catch (e) {
      debugPrint("Failed to leave squad: $e");
    }
  }

  /// Fetches active squad ID for the user's session
  Future<String?> getUserSquadSessionId(String userId) async {
    try {
      final response = await _supabase
          .from('user_squad_sessions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .single();
      currentSquadSession = UserSquadSession(
        id: response['id'],
        user_id: response['user_id'],
        squad_id: response['squad_id'],
        is_host: response['is_host'],
        is_active: response['is_active'],
        user_status: response['user_status'] != null
            ? UserSquadSessionStatusExtension.fromValue(response['user_status'])
            : UserSquadSessionStatus.alive,
      );
      debugPrint('Current squad session: ${response['user_status']}');
      return response.isNotEmpty ? response['squad_id'].toString() : null;
    } catch (e) {
      debugPrint("Failed to get squad session squad ID: $e");
      return null;
    }
  }

  Future<void> updateUserSquadSessionUserStatus(
      UserSquadSessionStatus userStatus) async {
    try {
      // Route through RPC to update per-game status and apply respawn rules
      final squadId = currentSquadSession!.squad_id;
      await Supabase.instance.client.rpc('set_user_status', params: {
        'p_squad_id': squadId,
        'p_status': userStatus.value,
      });
    } catch (e) {
      debugPrint("Failed to update user squad session user status: $e");
    }
  }
}
