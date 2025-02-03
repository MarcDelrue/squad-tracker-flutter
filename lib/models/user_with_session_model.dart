import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class UserWithSession {
  User user;
  UserSquadSession session;

  UserWithSession({
    required this.user,
    required this.session,
  });

  UserWithSession.deepCopy(UserWithSession userWithSession)
      : user = User.copy(userWithSession.user),
        session = UserSquadSession.copy(userWithSession.session);
}
