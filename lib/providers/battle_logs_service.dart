import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/battle_log_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';

class BattleLogsService extends ChangeNotifier {
  // Singleton setup
  static final BattleLogsService _singleton = BattleLogsService._internal();
  factory BattleLogsService() => _singleton;
  BattleLogsService._internal();

  final userService = UserService();
  final squadMembersService = SquadMembersService();
  final gameService = GameService();
  final squadService = SquadService();

  List<UserWithSession> _lastSquadMembersData = [];
  final List<BattleLogModel> _battleLogs = [];
  StreamSubscription<List<UserWithSession>?>? _subscription;
  StreamSubscription<List<Map<String, dynamic>>>? _gameStatsSub;
  final Map<String, Map<String, dynamic>> _lastStatsByUserId = {};

  List<BattleLogModel> get battleLogs => List.unmodifiable(_battleLogs);

  String youOrOtherUsername(User user) {
    final currentUserId = userService.currentUser?.id;
    return currentUserId != null && user.id == currentUserId
        ? "You"
        : (user.username ?? "");
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
        // Session status changed (fallback for non-game)
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
    for (var oldMember in _lastSquadMembersData) {
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
    }

    _pushLogs(newBattleLogs);

    // Updating _lastSquadMembersData with a deep copy of newSquadMembers
    _lastSquadMembersData = newSquadMembers
        .map((member) =>
            UserWithSession.fromJson(json.decode(json.encode(member.toJson()))))
        .toList();
  }

  void _pushLogs(List<BattleLogModel> newBattleLogs) {
    if (newBattleLogs.isEmpty) return;
    for (var battleLog in newBattleLogs) {
      _battleLogs.insert(0, battleLog);
      if (_battleLogs.length > 15) {
        _battleLogs.removeAt(15);
      }
    }
    notifyListeners();
  }

  Future<void> _startGameStatsListening() async {
    _gameStatsSub?.cancel();
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr == null) return;
    final gameId = await gameService.getActiveGameId(int.parse(squadIdStr));
    if (gameId == null) return;
    _gameStatsSub = gameService.streamScoreboardByGame(gameId).listen((rows) {
      final newLogs = <BattleLogModel>[];
      final members = squadMembersService.currentSquadMembers;
      final memberById = {for (final m in (members ?? [])) m.user.id: m.user};
      for (final r in rows) {
        final uid = r['user_id'] as String?;
        if (uid == null) continue;
        final user = memberById[uid];
        if (user == null) continue;
        final prev = _lastStatsByUserId[uid] ?? {};
        final prevKills = (prev['kills'] as int?) ?? 0;
        final prevDeaths = (prev['deaths'] as int?) ?? 0;
        final prevStatus = prev['user_status'] as String?;
        final kills = (r['kills'] as num? ?? 0).toInt();
        final deaths = (r['deaths'] as num? ?? 0).toInt();
        final statusStr = r['user_status'] as String?;

        // Kill bump
        if (kills > prevKills) {
          newLogs.add(BattleLogModel(
            user: user,
            status: 'KILL',
            date: DateTime.now(),
            text: "${youOrOtherUsername(user)} killed an enemy — kills: $kills",
          ));
        }
        // Death bump (status may or may not also change)
        if (deaths > prevDeaths) {
          newLogs.add(BattleLogModel(
            user: user,
            status: 'DEATH',
            date: DateTime.now(),
            text: "${youOrOtherUsername(user)} died — deaths: $deaths",
          ));
        }
        // Status change (per-game)
        if (statusStr != null && statusStr != prevStatus) {
          try {
            final oldS = prevStatus != null
                ? UserSquadSessionStatusExtension.fromValue(prevStatus)
                : UserSquadSessionStatus.alive;
            final newS = UserSquadSessionStatusExtension.fromValue(statusStr);
            newLogs.add(BattleLogModel(
              user: user,
              status: newS.toText,
              previousStatus: oldS.toText,
              date: DateTime.now(),
              text:
                  "${youOrOtherUsername(user)} ${generateLogText(oldS, newS)}",
            ));
          } catch (_) {}
        }

        _lastStatsByUserId[uid] = {
          'kills': kills,
          'deaths': deaths,
          'user_status': statusStr,
        };
      }
      _pushLogs(newLogs);
    });
  }

  void startListening() {
    // Always log and (re)emit initial state
    debugPrint('Starting battle logs listening');
    if (squadMembersService.currentSquadMembers != null) {
      _getNewUpdate(squadMembersService.currentSquadMembers!);
    }
    _startGameStatsListening();

    // Don't duplicate subscription
    if (_subscription != null) return;

    _subscription =
        squadMembersService.currentSquadMembersStream.listen((newSquadMembers) {
      // If newSquadMembers is null, user left squad
      if (newSquadMembers == null) {
        clearLogs();
        _lastSquadMembersData = [];
        _gameStatsSub?.cancel();
        _lastStatsByUserId.clear();
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
        _gameStatsSub?.cancel();
        _lastStatsByUserId.clear();
        return;
      }

      // If we have no previous data and new data is not empty, user joined new squad
      if (_lastSquadMembersData.isEmpty && newSquadMembers.isNotEmpty) {
        // Start fresh and emit join logs for initial snapshot
        clearLogs();
        _getNewUpdate(newSquadMembers);
        _startGameStatsListening();
      }
      // Normal update - only if we have existing data and new data
      else if (_lastSquadMembersData.isNotEmpty && newSquadMembers.isNotEmpty) {
        _getNewUpdate(newSquadMembers);
        _startGameStatsListening();
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _gameStatsSub?.cancel();
    _gameStatsSub = null;
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
