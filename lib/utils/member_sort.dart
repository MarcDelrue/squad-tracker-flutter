import 'package:squad_tracker_flutter/models/user_with_session_model.dart';

void sortByDistance(
    List<UserWithSession> members, Map<String, double>? distances) {
  members.sort((a, b) {
    final da = distances != null
        ? (distances[a.user.id] ?? double.infinity)
        : double.infinity;
    final db = distances != null
        ? (distances[b.user.id] ?? double.infinity)
        : double.infinity;
    return da.compareTo(db);
  });
}

void sortByKills(List<UserWithSession> members,
    Map<String, Map<String, int>> statsByUserId) {
  members.sort((a, b) {
    final sa = statsByUserId[a.user.id];
    final sb = statsByUserId[b.user.id];
    final ka = (sa?['kills'] ?? 0);
    final kb = (sb?['kills'] ?? 0);
    final da = (sa?['deaths'] ?? 0);
    final db = (sb?['deaths'] ?? 0);
    final kda = da == 0 ? ka.toDouble() : ka / da;
    final kdb = db == 0 ? kb.toDouble() : kb / db;
    if (kb != ka) return kb.compareTo(ka);
    if (kdb != kda) return kdb.compareTo(kda);
    return da.compareTo(db);
  });
}

void sortByKd(List<UserWithSession> members,
    Map<String, Map<String, int>> statsByUserId) {
  members.sort((a, b) {
    final sa = statsByUserId[a.user.id];
    final sb = statsByUserId[b.user.id];
    final ka = (sa?['kills'] ?? 0);
    final kb = (sb?['kills'] ?? 0);
    final da = (sa?['deaths'] ?? 0);
    final db = (sb?['deaths'] ?? 0);
    final kda = da == 0 ? ka.toDouble() : ka / da;
    final kdb = db == 0 ? kb.toDouble() : kb / db;
    if (kdb != kda) return kdb.compareTo(kda);
    if (kb != ka) return kb.compareTo(ka);
    return da.compareTo(db);
  });
}
