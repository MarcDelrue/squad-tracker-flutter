import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/battle_log_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'dart:convert';
import 'dart:async';

class BattleLogsService extends ChangeNotifier {
  // Singleton setup
  static final BattleLogsService _singleton = BattleLogsService._internal();
  factory BattleLogsService() => _singleton;
  BattleLogsService._internal();

  final userService = UserService();
  final squadMembersService = SquadMembersService();

  List<UserWithSession> _lastSquadMembersData = [];
  final List<BattleLogModel> _battleLogs = [];
  StreamSubscription<List<UserWithSession>?>? _subscription;

  List<BattleLogModel> get battleLogs => List.unmodifiable(_battleLogs);

  String youOrOtherUsername(User user) {
    return user.id == userService.currentUser!.id ? "You" : user.username ?? "";
  }

  String generateLogText(
      UserSquadSessionStatus oldStatus, UserSquadSessionStatus newStatus) {
    if (oldStatus == UserSquadSessionStatus.dead &&
        newStatus == UserSquadSessionStatus.alive) {
      return newStatus.toText;
    }
    if (newStatus == UserSquadSessionStatus.alive) {
      return "don't ${oldStatus.toText} anymore";
    }
    return newStatus.toText;
  }

  void _getNewUpdate(List<UserWithSession> newSquadMembers) {
    // Creating a deep copy of _lastSquadMembersData for comparison
    final List<UserWithSession> lastSquadMembersDeepCopy = _lastSquadMembersData
        .map((member) =>
            UserWithSession.fromJson(json.decode(json.encode(member.toJson()))))
        .toList();

    final Map<String, UserWithSession> lastMembersMap = {
      for (var member in lastSquadMembersDeepCopy) member.user.id: member
    };

    List<BattleLogModel> newBattleLogs = [];

    for (final newMember in newSquadMembers) {
      final oldMember = lastMembersMap[newMember.user.id];

      if (oldMember == null) {
        // New member joined
        newBattleLogs.add(BattleLogModel(
          user: newMember.user,
          status: "Joined",
          date: DateTime.now(),
          text: "${youOrOtherUsername(newMember.user)} joined the squad",
        ));
      } else if (oldMember.session.user_status !=
          newMember.session.user_status) {
        // Status changed - only log if both members are active
        if (oldMember.session.is_active && newMember.session.is_active) {
          newBattleLogs.add(BattleLogModel(
            user: newMember.user,
            status: newMember.session.user_status?.toText ?? "",
            previousStatus: oldMember.session.user_status?.toText,
            date: DateTime.now(),
            text:
                "${youOrOtherUsername(newMember.user)} ${generateLogText(oldMember.session.user_status ?? UserSquadSessionStatus.alive, newMember.session.user_status ?? UserSquadSessionStatus.alive)}",
          ));
        }
      }
    }

    // Identifying removed members (those who are no longer active)
    _lastSquadMembersData.forEach((oldMember) {
      if (!newSquadMembers.any((newMember) =>
          newMember.user.id == oldMember.user.id &&
          newMember.session.is_active)) {
        newBattleLogs.add(BattleLogModel(
          user: oldMember.user,
          status: "Left",
          date: DateTime.now(),
          text: "${youOrOtherUsername(oldMember.user)} left the squad",
        ));
      }
    });

    // Only update if there are new battle logs
    if (newBattleLogs.isNotEmpty) {
      for (var battleLog in newBattleLogs) {
        // Add new log at the beginning of the list
        _battleLogs.insert(0, battleLog);

        // If list exceeds 5 items, remove the last one
        if (_battleLogs.length > 15) {
          _battleLogs.removeAt(15);
        }
      }

      // Notify listeners that battle logs have changed
      notifyListeners();
    }

    // Updating _lastSquadMembersData with a deep copy of newSquadMembers
    _lastSquadMembersData = newSquadMembers
        .map((member) =>
            UserWithSession.fromJson(json.decode(json.encode(member.toJson()))))
        .toList();
  }

  void startListening() {
    // Don't start if already listening
    if (_subscription != null) return;

    // Initialize with current squad members if available
    if (squadMembersService.currentSquadMembers != null) {
      _lastSquadMembersData = squadMembersService.currentSquadMembers!
          .map((member) => UserWithSession.fromJson(
              json.decode(json.encode(member.toJson()))))
          .toList();
    }

    _subscription =
        squadMembersService.currentSquadMembersStream.listen((newSquadMembers) {
      // If newSquadMembers is null, user left squad
      if (newSquadMembers == null) {
        clearLogs();
        _lastSquadMembersData = [];
        return;
      }

      // Check if current user is still in the squad
      final currentUserId = userService.currentUser?.id;
      final currentUserStillInSquad =
          newSquadMembers.any((member) => member.user.id == currentUserId);

      // If current user is no longer in the squad, clear logs
      if (!currentUserStillInSquad && _lastSquadMembersData.isNotEmpty) {
        clearLogs();
        _lastSquadMembersData = [];
        return;
      }

      // If we have no previous data and new data is not empty, user joined new squad
      if (_lastSquadMembersData.isEmpty && newSquadMembers.isNotEmpty) {
        clearLogs();
        _lastSquadMembersData = newSquadMembers
            .map((member) => UserWithSession.fromJson(
                json.decode(json.encode(member.toJson()))))
            .toList();
      }
      // Normal update - only if we have existing data and new data
      else if (_lastSquadMembersData.isNotEmpty && newSquadMembers.isNotEmpty) {
        _getNewUpdate(newSquadMembers);
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void clearLogs() {
    _battleLogs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
