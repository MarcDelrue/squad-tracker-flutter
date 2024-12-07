import 'dart:ffi';

import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class MemberCoordinates {
  Int direction;
  Int distance;

  MemberCoordinates({required this.direction, required this.distance});
}

class MemberInGame {
  User user;
  UserSquadSession session;
  MemberCoordinates coordinates;

  MemberInGame({
    required this.user,
    required this.session,
    required this.coordinates,
  });
}
