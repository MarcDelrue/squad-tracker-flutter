import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class UserWithSession {
  User user;
  UserSquadSession session;

  UserWithSession({
    required this.user,
    required this.session,
  });

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'session': session.toJson(),
      };

  factory UserWithSession.fromJson(Map<String, dynamic> json) {
    return UserWithSession(
      user: User.fromJson(json['user']),
      session: UserSquadSession.fromJson(json['session']),
    );
  }
}
