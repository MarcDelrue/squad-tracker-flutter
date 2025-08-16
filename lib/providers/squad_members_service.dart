import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart' as users_model;
import 'package:squad_tracker_flutter/providers/map_annotations_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SquadMembersService {
  // Singleton setup
  static final SquadMembersService _singleton = SquadMembersService._internal();
  factory SquadMembersService() => _singleton;
  SquadMembersService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final userSquadLocationService = UserSquadLocationService();
  final mapAnnotationsService = MapAnnotationsService();
  RealtimeChannel? currentSquadChannel;
  Map<String, RealtimeChannel>? currentMembersChannels;

  final _currentSquadMembersController =
      StreamController<List<UserWithSession>?>.broadcast();
  Stream<List<UserWithSession>?> get currentSquadMembersStream =>
      _currentSquadMembersController.stream;

  List<UserWithSession>? _currentSquadMembers;
  List<UserWithSession>? get currentSquadMembers => _currentSquadMembers;

  set currentSquadMembers(List<UserWithSession>? value) {
    _currentSquadMembers = value;
    _currentSquadMembersController.add(value);
  }

  Future<void> getCurrentSquadMembers(String userId, String squadId) async {
    try {
      final response = await _supabase
          .from('user_squad_sessions')
          .select()
          .eq('squad_id', squadId)
          .eq('is_active', true);

      final List<dynamic> sessionsData = response;

      if (sessionsData.isEmpty) {
        return;
      }

      final squadMembers = await _fetchUsersFromSquadSession(sessionsData);
      final filteredUserIds = sessionsData
          .map<String>((session) => session['user_id'] as String)
          .where((id) => id != userId)
          .toList();
      userSquadLocationService.fetchMembersLocation(filteredUserIds, squadId);

      currentSquadMembers = squadMembers;
    } catch (e) {
      debugPrint('Error getting current squad members: $e');
      return;
    }
  }

  Future<List<UserWithSession>> _fetchUsersFromSquadSession(
      List<dynamic> sessionsData) async {
    try {
      final List<String> userIdList =
          sessionsData.map((item) => item['user_id'] as String).toList();

      debugPrint('User IDs: $userIdList');
      // Now fetch user details from the users table
      final userResponse =
          await _supabase.from('users').select().inFilter('id', userIdList);

      final List<dynamic> usersData = userResponse;

      final List<UserWithSession> userWithSessions =
          sessionsData.map((sessionData) {
        final userData = usersData
            .firstWhere((user) => user['id'] == sessionData['user_id']);
        final userWithSession = UserWithSession(
          user: users_model.User.fromJson(userData),
          session: UserSquadSession.fromJson(sessionData),
        );
        // Listen to real-time changes for each user
        listenToMembersData(userData['id']);
        return userWithSession;
      }).toList();

      return userWithSessions;
    } catch (e) {
      debugPrint('Error fetching users with sessions: $e');
      return [];
    }
  }

  void listenToSquadMembers(String userId, String squadId) {
    if (currentSquadChannel != null) {
      return;
    }
    currentSquadChannel = _supabase
        .channel('squad-session-channel')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_squad_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'squad_id',
              value: squadId,
            ),
            callback: (PostgresChangePayload payload) async {
              debugPrint('Squad member session change detected: $payload');
              if (payload.newRecord['is_active'] == true) {
                if (currentMembersChannels
                        ?.containsKey(payload.newRecord['user_id']) ==
                    true) {
                  _updateMemberSession(
                      UserSquadSession.fromJson(payload.newRecord));
                } else {
                  debugPrint('User joined the squad');
                  final newSquadMember =
                      await _fetchUsersFromSquadSession([payload.newRecord]);
                  if (payload.newRecord['user_id'] != userId) {
                    userSquadLocationService.fetchMembersLocation(
                        [payload.newRecord['user_id']], squadId);
                  }
                  currentSquadMembers = [
                    ...currentSquadMembers!,
                    ...newSquadMember
                  ];
                }
              } else if (payload.newRecord['is_active'] == false) {
                _removeSquadMember(payload.newRecord['user_id']);
                // mapAnnotationsService
                //     .removeMembersAnnotation(payload.newRecord['username']);
                userSquadLocationService
                    .unsubscribeMemberLocations(payload.newRecord['user_id']);
                unsubscribeFromMembersData(payload.newRecord['user_id']);
                debugPrint('User left the squad');
              }
            })
        .subscribe();
  }

  void listenToMembersData(String memberId) {
    // Check if a channel for this memberId already exists
    if (currentMembersChannels != null &&
        currentMembersChannels!.containsKey(memberId)) {
      return; // Exit early if the channel already exists
    }

    final channel = _supabase
        .channel('member-$memberId-channel')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: memberId,
            ),
            callback: (PostgresChangePayload payload) {
              debugPrint('Callback triggered for member data change: $payload');
              _updateMemberData(users_model.User.fromJson(payload.newRecord));
              debugPrint('Squad member data change detected: $payload');
            })
        .subscribe();

    currentMembersChannels ??= {};
    currentMembersChannels![memberId] = channel;
    debugPrint('Listener setup complete for member: $memberId');
  }

  _updateMemberData(users_model.User user) {
    currentSquadMembers?.forEach((member) {
      if (member.user.id == user.id) {
        member.user = user;
      }
    });
    _currentSquadMembersController.add(currentSquadMembers);
  }

  _updateMemberSession(UserSquadSession session) {
    debugPrint('Updating member session: $session');
    currentSquadMembers?.forEach((member) {
      if (member.session.id == session.id) {
        member.session = session;
      }
    });
    _currentSquadMembersController.add(currentSquadMembers);
  }

  _removeSquadMember(String memberId) {
    currentSquadMembers?.removeWhere((member) => member.user.id == memberId);
    _currentSquadMembersController.add(currentSquadMembers);
  }

  UserWithSession getMemberDataById(String memberId) {
    return currentSquadMembers!
        .firstWhere((member) => member.user.id == memberId);
  }

  unsubscribeFromMembersData(String memberId) {
    currentMembersChannels?[memberId]?.unsubscribe();
    currentMembersChannels?.remove(memberId);
  }

  unsubscribeFromSquadMembers() {
    if (currentSquadChannel == null) {
      return;
    }
    _supabase.removeChannel(currentSquadChannel!);
    currentSquadChannel?.unsubscribe();
    // Clear all markers when unsubscribing from squad members (leaving squad)
    mapAnnotationsService.removeEveryAnnotations();
  }

  kickFromSquad(String userId, String squadId) async {
    try {
      await _supabase
          .from('user_squad_sessions')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('squad_id', squadId);
    } catch (e) {
      debugPrint("Failed to kick user from squad: $e");
    }
  }

  setUserAsHost(String userId, String newHostId, String squadId) async {
    try {
      await _supabase
          .from('user_squad_sessions')
          .update({'is_host': true})
          .eq('user_id', newHostId)
          .eq('squad_id', squadId);

      await _supabase
          .from('user_squad_sessions')
          .update({'is_host': false})
          .eq('user_id', userId)
          .eq('squad_id', squadId);
    } catch (e) {
      debugPrint("Failed to set user as host: $e");
    }
  }
}
