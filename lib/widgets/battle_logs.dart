import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'dart:convert';

class BattleLogsWidget extends StatefulWidget {
  const BattleLogsWidget({super.key});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  List<UserWithSession> _lastSquadMembersData = [];

  void getNewUpdate(List<UserWithSession> newSquadMembers) {
    // Creating a deep copy of _lastSquadMembersData for comparison
    final List<UserWithSession> lastSquadMembersDeepCopy = _lastSquadMembersData
        .map((member) =>
            UserWithSession.fromJson(json.decode(json.encode(member.toJson()))))
        .toList();

    final Map<String, UserWithSession> lastMembersMap = {
      for (var member in lastSquadMembersDeepCopy) member.user.id: member
    };

    final addedMembers = <UserWithSession>[];
    final removedMembers = <UserWithSession>[];
    final updatedMembers = <UserWithSession>[];

    for (final newMember in newSquadMembers) {
      final oldMember = lastMembersMap[newMember.user.id];

      if (oldMember == null ||
          (!oldMember.session.is_active && newMember.session.is_active)) {
        addedMembers.add(newMember);
      } else if (oldMember.session.user_status !=
          newMember.session.user_status) {
        updatedMembers.add(newMember);
      }
    }

    // Identifying removed members
    _lastSquadMembersData.forEach((oldMember) {
      if (!newSquadMembers
          .any((newMember) => newMember.user.id == oldMember.user.id)) {
        removedMembers.add(oldMember);
      }
    });

    // Debug prints to check the results
    print('Added members: ${addedMembers.map((m) => m.user.id)}');
    print('Removed members: ${removedMembers.map((m) => m.user.id)}');
    print('Updated members: ${updatedMembers.map((m) => m.user.id)}');

    // Updating _lastSquadMembersData with a deep copy of newSquadMembers
    _lastSquadMembersData = newSquadMembers
        .map((member) =>
            UserWithSession.fromJson(json.decode(json.encode(member.toJson()))))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final squadMembersService =
        SquadMembersService(); // Obtain the service instance appropriately

    return StreamBuilder<List<UserWithSession>?>(
      stream: squadMembersService.currentSquadMembersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text("Waiting for member events...");
        }

        getNewUpdate(snapshot.data!);

        final event = snapshot.data!;
        // Customize your widget based on the event
        String logMessage = "";
        // switch (event.type) {
        //   case MemberEventType.joined:
        //     logMessage = "${event.memberData!.user.username} joined the squad.";
        //     break;
        //   case MemberEventType.left:
        //     logMessage = "${event.memberData!.user.username} left the squad.";
        //     break;
        //   case MemberEventType.statusUpdated:
        //     logMessage = "${event.memberData!.user.username} status updated.";
        //     break;
        // }

        return ListTile(
          title: Text(logMessage),
        );
      },
    );
  }
}
