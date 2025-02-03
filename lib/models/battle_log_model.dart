import 'package:squad_tracker_flutter/models/users_model.dart';

class BattleLogModel {
  User user;
  String text;
  DateTime date;
  String status;
  String? previousStatus;

  BattleLogModel({
    required this.user,
    required this.text,
    required this.date,
    required this.status,
    this.previousStatus,
  });
}
