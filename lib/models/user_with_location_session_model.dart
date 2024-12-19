import 'user_with_session_model.dart';
import 'user_squad_location_model.dart';

class UserWithLocationSession {
  final UserWithSession userWithSession;
  final UserSquadLocation? location;

  UserWithLocationSession({
    required this.userWithSession,
    this.location,
  });
}
