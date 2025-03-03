enum UserSquadSessionStatus {
  alive,
  dead,
  help,
  medic,
}

extension UserSquadSessionStatusExtension on UserSquadSessionStatus {
  String get value {
    switch (this) {
      case UserSquadSessionStatus.alive:
        return 'ALIVE';
      case UserSquadSessionStatus.dead:
        return 'DEAD';
      case UserSquadSessionStatus.help:
        return 'HELP';
      case UserSquadSessionStatus.medic:
        return 'MEDIC';
    }
  }

  String get toText {
    switch (this) {
      case UserSquadSessionStatus.alive:
        return 'respawned';
      case UserSquadSessionStatus.dead:
        return 'died';
      case UserSquadSessionStatus.help:
        return 'need help';
      case UserSquadSessionStatus.medic:
        return 'need a medic';
    }
  }

  static UserSquadSessionStatus fromValue(String value) {
    switch (value) {
      case 'ALIVE':
        return UserSquadSessionStatus.alive;
      case 'DEAD':
        return UserSquadSessionStatus.dead;
      case 'HELP':
        return UserSquadSessionStatus.help;
      case 'MEDIC':
        return UserSquadSessionStatus.medic;
      default:
        throw ArgumentError('Invalid UserSquadSessionStatus value: $value');
    }
  }
}

class UserSquadSession {
  int id;
  String user_id;
  int squad_id;
  bool is_host;
  bool is_active;
  UserSquadSessionStatus? user_status = UserSquadSessionStatus.alive;

  UserSquadSession(
      {required this.id,
      required this.user_id,
      required this.squad_id,
      required this.is_host,
      required this.is_active,
      this.user_status});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': user_id,
      'squad_id': squad_id,
      'is_host': is_host,
      'is_active': is_active,
      'user_status': user_status?.value,
    };
  }

  factory UserSquadSession.fromJson(Map<String, dynamic> json) {
    return UserSquadSession(
      id: json['id'],
      user_id: json['user_id'],
      squad_id: json['squad_id'],
      is_host: json['is_host'],
      is_active: json['is_active'],
      user_status: json['user_status'] != null
          ? UserSquadSessionStatusExtension.fromValue(json['user_status'])
          : UserSquadSessionStatus.alive,
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
