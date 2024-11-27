class Squad {
  String id;
  String name;
  String uuid;

  Squad({required this.id, required this.name, required this.uuid});
}

class SquadWithUpdatedAt extends Squad {
  DateTime updatedAt;

  SquadWithUpdatedAt(
      {required super.id,
      required super.name,
      required super.uuid,
      required this.updatedAt});
}
