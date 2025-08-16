import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/battle_log_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:timeago/timeago.dart' as timeago;

class BattleLogsWidget extends StatefulWidget {
  const BattleLogsWidget({super.key});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  final userService = UserService();
  List<UserWithSession> _lastSquadMembersData = [];
  final List<BattleLogModel> _battleLogs = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  StreamSubscription<List<UserWithSession>?>? _subscription;

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

  void getNewUpdate(List<UserWithSession> newSquadMembers) {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;

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

      if (oldMember == null ||
          (!oldMember.session.is_active && newMember.session.is_active)) {
        newBattleLogs.add(BattleLogModel(
          user: newMember.user,
          status: "Joined",
          date: DateTime.now(),
          text: "${youOrOtherUsername(newMember.user)} joined the squad",
        ));
      } else if (oldMember.session.user_status !=
          newMember.session.user_status) {
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

    // Identifying removed members
    _lastSquadMembersData.forEach((oldMember) {
      if (!newSquadMembers
          .any((newMember) => newMember.user.id == oldMember.user.id)) {
        // removedMembers.add(oldMember);
        newBattleLogs.add(BattleLogModel(
          user: oldMember.user,
          status: "Left",
          date: DateTime.now(),
          text: "${youOrOtherUsername(oldMember.user)} left the squad",
        ));
      }
    });

    setState(() {
      for (var battleLog in newBattleLogs) {
        // Add new log at the beginning of the list
        _battleLogs.insert(0, battleLog);
        _listKey.currentState?.insertItem(0);

        // If list exceeds 5 items, remove the last one
        if (_battleLogs.length > 5) {
          // Correct index to remove is always 5, since we want to remove
          // the "oldest" item which now is the last item visually and in the list
          var removedItem = _battleLogs.removeAt(
              5); // This actually removes the 6th item, making the list have 5 items again
          _listKey.currentState?.removeItem(
            5, // This is the visual index of the item to remove
            (context, animation) => FadeTransition(
              opacity: animation,
              child: battleLogToWidget(removedItem),
            ),
            duration: const Duration(
                milliseconds: 300), // Duration of the fade transition
          );
        }
      }
    });

    // Updating _lastSquadMembersData with a deep copy of newSquadMembers
    _lastSquadMembersData = newSquadMembers
        .map((member) =>
            UserWithSession.fromJson(json.decode(json.encode(member.toJson()))))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final squadMembersService = SquadMembersService();
    _subscription =
        squadMembersService.currentSquadMembersStream.listen((newSquadMembers) {
      if (newSquadMembers != null) {
        getNewUpdate(newSquadMembers);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserWithSession>?>(
      stream: SquadMembersService().currentSquadMembersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text("Waiting for member events...");
        }

        return AnimatedList(
          key: _listKey,
          initialItemCount: _battleLogs.length,
          itemBuilder: (context, index, animation) {
            final battleLog = _battleLogs[index];
            return FadeTransition(
                opacity: animation, child: battleLogToWidget(battleLog));
          },
        );
      },
    );
  }

  Widget battleLogToWidget(BattleLogModel battleLog) {
    final now = DateTime.now();
    final difference = now.difference(battleLog.date);

    return Container(
      color: Colors.black.withOpacity(0.5), // Semi-transparent background
      child: ListTile(
        dense: true,
        title: Text(
          battleLog.text,
          style: TextStyle(color: Colors.white), // White text for readability
        ),
        subtitle: Text(
          timeago.format(now.subtract(difference)),
          style: TextStyle(color: Colors.grey[300]), // Light grey text
        ),
      ),
    );
  }
}
