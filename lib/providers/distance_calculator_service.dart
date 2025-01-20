import 'dart:math';

import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';

class DistanceCalculatorService {
  calculateDirectionFromUser(UserSquadLocation location,
      UserSquadLocation? currentUserLocation, double? userDirection) {
    if (location.latitude == null ||
        location.longitude == null ||
        currentUserLocation == null) {
      return 0.0;
    }
    double memberDirection = calculateBearing(
        location.latitude!,
        location.longitude!,
        currentUserLocation.latitude!,
        currentUserLocation.longitude!);
    double directionDifference = memberDirection - (userDirection ?? 0.0);

    return directionDifference;
  }

  double calculateBearing(num lat1, num lon1, num lat2, num lon2) {
    lat1 = _degreesToRadians(lat1);
    lon1 = _degreesToRadians(lon1);
    lat2 = _degreesToRadians(lat2);
    lon2 = _degreesToRadians(lon2);

    num dLon = lon2 - lon1;

    double x = sin(dLon) * cos(lat2);
    double y = cos(lat1) * sin(lat2) - (sin(lat1) * cos(lat2) * cos(dLon));

    double initialBearing = atan2(x, y);

    initialBearing = initialBearing * 180 / pi;

    double compassBearing = (initialBearing + 360) % 360;

    return compassBearing;
  }

  calculateDistanceFromUser(
      UserSquadLocation? location, UserSquadLocation? currentUserLocation) {
    if (location == null ||
        location.latitude == null ||
        location.longitude == null ||
        currentUserLocation == null) {
      return 0.0;
    }
    final double distance = _calculateDistanceBetweenTwoLocations(
        location.latitude!,
        location.longitude!,
        currentUserLocation.latitude!,
        currentUserLocation.longitude!);
    return distance;
  }

  double _calculateDistanceBetweenTwoLocations(
      num lat1, num lon1, num lat2, num lon2) {
    const earthRadiusMeters = 6371000.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(num degrees) {
    return degrees * pi / 180;
  }
}
