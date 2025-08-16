import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/battle_log_model.dart';
import 'package:squad_tracker_flutter/providers/battle_logs_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class BattleLogsWidget extends StatefulWidget {
  const BattleLogsWidget({super.key});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  final battleLogsService = BattleLogsService();

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
      ),
    );
  }
}
