import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/battle_log_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/providers/battle_logs_service.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class BattleLogsWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const BattleLogsWidget({super.key, this.onClose});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  final battleLogsService = BattleLogsService();
  final userService = UserService();

  @override
  void initState() {
    super.initState();
    // Start listening to battle logs when widget is created
    battleLogsService.startListening();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: battleLogsService,
      builder: (context, child) {
        final battleLogs = battleLogsService.battleLogs;

        if (battleLogs.isEmpty) {
          return const Center(
            child: Text(
              "No battle logs yet",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: battleLogs.length,
          itemBuilder: (context, index) {
            final battleLog = battleLogs[index];
            return battleLogToWidget(battleLog);
          },
        );
      },
    );
  }

  Widget battleLogToWidget(BattleLogModel battleLog) {
    return Container(
      color: Colors.black, // Fully opaque background
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          battleLog.text,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          timeago.format(battleLog.date, locale: 'en_short'),
          style: const TextStyle(color: Colors.grey),
        ),
        onTap: () {
          // Don't do anything if it's the current user's log
          if (battleLog.user.id == userService.currentUser?.id) {
            return;
          }
          // Fly to the member and close battle logs
          _flyToMember(battleLog.user);
          widget.onClose?.call();
        },
      ),
    );
  }

  void _flyToMember(User user) {
    // Import the map user location service to fly to the member
    final mapUserLocationService = MapUserLocationService();
    final userSquadLocationService = UserSquadLocationService();

    // Find the member's location
    final memberLocation = userSquadLocationService.currentMembersLocation
        ?.where((location) => location.user_id == user.id)
        .firstOrNull;

    if (memberLocation != null &&
        memberLocation.latitude != null &&
        memberLocation.longitude != null) {
      // Fly to the member's location
      mapUserLocationService.flyToLocation(
        memberLocation.longitude!,
        memberLocation.latitude!,
      );
    }
  }
}
