import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/distance_calculator_service.dart';

class LocationDerivedState {
  final DistanceCalculatorService distanceCalculatorService;
  LocationDerivedState({DistanceCalculatorService? calculator})
      : distanceCalculatorService = calculator ?? DistanceCalculatorService();

  Map<String, double> computeDistances(
      {required List<UserSquadLocation> members,
      required UserSquadLocation? currentUser}) {
    final Map<String, double> distances = {};
    if (currentUser == null) return distances;
    for (final m in members) {
      if (m.latitude != null && m.longitude != null) {
        distances[m.user_id] =
            distanceCalculatorService.calculateDistanceFromUser(m, currentUser);
      }
    }
    return distances;
  }

  Map<String, double> computeDirectionsFromUser(
      {required List<UserSquadLocation> members,
      required UserSquadLocation? currentUser,
      required double? userDirection}) {
    final Map<String, double> dirs = {};
    if (currentUser == null) return dirs;
    for (final m in members) {
      if (m.latitude != null && m.longitude != null) {
        dirs[m.user_id] = distanceCalculatorService.calculateDirectionFromUser(
            m, currentUser, userDirection);
      }
    }
    return dirs;
  }

  Map<String, double> computeDirectionsToMember(
      {required List<UserSquadLocation> members,
      required UserSquadLocation? currentUser}) {
    final Map<String, double> dirs = {};
    if (currentUser == null) return dirs;
    for (final m in members) {
      if (m.latitude != null && m.longitude != null) {
        dirs[m.user_id] = distanceCalculatorService.calculateDirectionToMember(
            m, currentUser);
      }
    }
    return dirs;
  }
}
