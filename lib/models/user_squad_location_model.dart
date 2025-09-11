class UserSquadLocation {
  int id;
  String user_id;
  int squad_id;
  num? longitude;
  num? latitude;
  num? direction;
  DateTime? updated_at;

  UserSquadLocation({
    required this.id,
    required this.user_id,
    required this.squad_id,
    this.longitude,
    this.latitude,
    this.direction,
    this.updated_at,
  });

  factory UserSquadLocation.fromJson(Map<String, dynamic> json) {
    DateTime? _parseSupabaseTimestamp(String? raw) {
      if (raw == null) return null;
      String s = raw.trim();
      // Normalize space separator to 'T'
      if (s.contains(' ') && !s.contains('T')) {
        s = s.replaceFirst(' ', 'T');
      }
      // If no timezone designator present, assume UTC
      final hasTz = s.endsWith('Z') || s.contains('+', 10) || s.contains('Z');
      final candidate = hasTz ? s : (s + 'Z');
      return DateTime.tryParse(candidate);
    }

    return UserSquadLocation(
      id: json['id'],
      user_id: json['user_id'],
      squad_id: json['squad_id'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      direction: json['direction'],
      updated_at: _parseSupabaseTimestamp(json['updated_at']?.toString()),
    );
  }
}
