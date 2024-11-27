class UserSquadSession {
  int id;
  String user_id;
  int squad_id;
  bool is_host;
  bool is_active;

  UserSquadSession(
      {required this.id,
      required this.user_id,
      required this.squad_id,
      required this.is_host,
      required this.is_active});

  factory UserSquadSession.fromJson(Map<String, dynamic> json) {
    return UserSquadSession(
      id: json['id'],
      user_id: json['user_id'],
      squad_id: json['squad_id'],
      is_host: json['is_host'],
      is_active: json['is_active'],
    );
  }
}

class UserSquadSessionOptions {
  bool is_host;
  bool is_you;
  bool can_interact;

  UserSquadSessionOptions(
      {required this.is_host,
      required this.is_you,
      required this.can_interact});
}
