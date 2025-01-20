import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';

class BattleLogsWidget extends StatefulWidget {
  const BattleLogsWidget({super.key});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  getNewUpdate(List<UserWithSession> event) {
    debugPrint('BattleLogs: ' + event.toString());
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
