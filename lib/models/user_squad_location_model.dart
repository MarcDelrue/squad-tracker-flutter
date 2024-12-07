class UserSquadLocation {
  int id;
  String user_id;
  int squad_id;
  double? longitude;
  double? latitude;
  double? direction;

  UserSquadLocation({
    required this.id,
    required this.user_id,
    required this.squad_id,
    this.longitude,
    this.latitude,
    this.direction,
  });

  factory UserSquadLocation.fromJson(Map<String, dynamic> json) {
    return UserSquadLocation(
      id: json['id'],
      user_id: json['user_id'],
      squad_id: json['squad_id'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      direction: json['direction'],
    );
  }
}
