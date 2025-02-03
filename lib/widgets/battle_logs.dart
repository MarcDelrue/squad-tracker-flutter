import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';

class BattleLogsWidget extends StatefulWidget {
  const BattleLogsWidget({super.key});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  List<UserWithSession> _lastSquadMembersData = [];

// TODO: Still not working
  void getNewUpdate(List<UserWithSession> newSquadMembers) {
    final Map<String, UserWithSession> lastMembersMap = {
      for (var member in _lastSquadMembersData)
        member.user.id: UserWithSession.deepCopy(member)
    };

    final addedMembers = <UserWithSession>[];
    final removedMembers = <UserWithSession>[];
    final updatedMembers = <UserWithSession>[];

    for (final newMember in newSquadMembers) {
      final oldMember = lastMembersMap[newMember.user.id];

      print(
          'Old status: ${oldMember?.session.user_status}, New status: ${newMember.session.user_status}');

      // If old member doesn't exist or is_active went from false to true
      if (oldMember == null ||
          (!oldMember.session.is_active && newMember.session.is_active)) {
        addedMembers.add(newMember);
      }

      // Check for updates in sessions.status
      else if (oldMember.session.user_status != newMember.session.user_status) {
        updatedMembers.add(newMember);
      }
    }

    for (final oldMember in _lastSquadMembersData) {
      final UserWithSession? newMember = newSquadMembers
          .firstWhereOrNull((m) => m.user.id == oldMember.user.id);

      if (newMember == null) {
        removedMembers.add(oldMember);
      }

      if (newMember != null) {
        // If new member doesn't exist or is_active went from true to false
        if (oldMember.session.is_active == true &&
            (newMember.session.is_active == false)) {
          removedMembers.add(oldMember);
        }
      }
    }

    // Debug prints or handle the updates as needed
    print('Added members: ${addedMembers.map((m) => m.user.id)}');
    print('Removed members: ${removedMembers.map((m) => m.user.id)}');
    print('Updated members: ${updatedMembers.map((m) => m.user.id)}');

    // Update the last known state
    _lastSquadMembersData = List<UserWithSession>.from(newSquadMembers);

    print('getNewUpdate completed. Last squad members data updated.');
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
