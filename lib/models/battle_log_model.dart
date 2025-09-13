import 'package:squad_tracker_flutter/models/users_model.dart';

class BattleLogModel {
  User user;
  String text;
  DateTime date;
  String status;
  String? previousStatus;
  int? kills; // Final kills count after this log (only for KILL logs)
  int mergedCount; // Number of consecutive merged events (for KILL series)

  BattleLogModel({
    required this.user,
    required this.text,
    required this.date,
    required this.status,
    this.previousStatus,
    this.kills,
    this.mergedCount = 1,
  });
}
