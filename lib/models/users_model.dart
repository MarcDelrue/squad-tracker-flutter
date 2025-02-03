class User {
  String id;
  String? username;
  String? full_name;
  String? avatar_url;
  String? main_role;
  String? main_color;

  User(
      {required this.id,
      this.username,
      this.full_name,
      this.avatar_url,
      this.main_role,
      this.main_color});

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': full_name,
        'avatar_url': avatar_url,
        'main_role': main_role,
        'main_color': main_color,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String?,
        full_name: json['full_name'] as String?,
        avatar_url: json['avatar_url'] as String?,
        main_role: json['main_role'] as String?,
        main_color: json['main_color'] as String?,
      );
}
