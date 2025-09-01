import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as locator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:permission_handler/permission_handler.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';

class MapUserLocationService {
  // Singleton setup
  static final MapUserLocationService _singleton =
      MapUserLocationService._internal();
  factory MapUserLocationService() => _singleton;
  MapUserLocationService._internal();

  final userSquadLocationService = UserSquadLocationService();

  late StreamSubscription<locator.Position>? positionStream;
  bool _isStreamInitialized = false;

  bool get isPositionStreamPaused {
    if (!_isStreamInitialized) {
      return true;
    }
    return positionStream?.isPaused ?? true;
  }

  late StreamSubscription<CompassEvent>? compassStream;
  mapbox.MapboxMap? mapboxMap;
  late locator.LocationSettings? locationSettings;
  var currentDirection = 0.0;
  DateTime? _lastHeadingUpdateAt;
  final Duration _minHeadingUpdateInterval = const Duration(milliseconds: 500);
  final double _headingDeltaThresholdDegrees = 5.0;
  bool cameraInitialized = false;
  bool isProgrammaticCameraChange = false;
  late Uint8List soldierImage = Uint8List(0);

  // Throttling/power settings for saving location to backend
  DateTime? _lastSavedLocationAt;
  locator.Position? _lastSavedPosition;
  final Duration _minSaveInterval = const Duration(seconds: 15);
  final double _minSaveDistanceMeters = 10.0;

  init(mapbox.MapboxMap mapboxMapReference) async {
    mapboxMap = mapboxMapReference;

    final hasPermission = await getLocationPermission();
    if (hasPermission) {
      setLocationSettingsPerPlatform();
      loadUserPuck();
      trackUserLocation();
      getUserDirection();
    }
  }

  Future<bool> getLocationPermission() async {
    locator.LocationPermission permission =
        await locator.Geolocator.checkPermission();
    if (permission == locator.LocationPermission.denied) {
      await Permission.locationWhenInUse.request();
      if (permission == locator.LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
      return true;
    }
    return true;
  }

  trackUserLocation() async {
    positionStream =
        locator.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((locator.Position? position) {
      if (position != null) {
        userSquadLocationService.currentUserLocation?.latitude =
            position.latitude;
        userSquadLocationService.currentUserLocation?.longitude =
            position.longitude;
        // Throttle backend writes based on time and distance moved
        final now = DateTime.now();
        final bool timeOk = _lastSavedLocationAt == null ||
            now.difference(_lastSavedLocationAt!) >= _minSaveInterval;

        double movedMeters = 0.0;
        if (_lastSavedPosition != null) {
          movedMeters = locator.Geolocator.distanceBetween(
            _lastSavedPosition!.latitude,
            _lastSavedPosition!.longitude,
            position.latitude,
            position.longitude,
          );
        }
        final bool distanceOk =
            _lastSavedPosition == null || movedMeters >= _minSaveDistanceMeters;

        if (timeOk || distanceOk) {
          if (userSquadLocationService.currentUserLocation != null) {
            userSquadLocationService.saveCurrentLocation(
                position.longitude, position.latitude, currentDirection);
          }
          _lastSavedLocationAt = now;
          _lastSavedPosition = position;
        }
        if (cameraInitialized == false) {
          flyToLocation(position.longitude, position.latitude);
          cameraInitialized = true;
        }
      }
      if (kDebugMode) {
        debugPrint(position == null
            ? 'Unknown'
            : 'Current position: ${position.latitude.toString()}, ${position.longitude.toString()}');
      }
    });
    _isStreamInitialized = true;
  }

  pauseTrackingUserLocation() {
    positionStream?.pause();
    compassStream?.pause();
    mapboxMap?.location
        .updateSettings(mapbox.LocationComponentSettings(enabled: false));
  }

  unpauseTrackingUserLocation() {
    positionStream?.resume();
    compassStream?.resume();
    loadUserPuck();
  }

  getUserDirection() {
    compassStream = FlutterCompass.events!.listen((CompassEvent event) {
      final heading = event.heading;
      if (heading == null) {
        if (kDebugMode) debugPrint('Device does not have sensors!');
        return;
      }

      final now = DateTime.now();
      final bool timeOk = _lastHeadingUpdateAt == null ||
          now.difference(_lastHeadingUpdateAt!) >= _minHeadingUpdateInterval;
      final double delta = (currentDirection - heading).abs();
      final bool deltaOk = delta >= _headingDeltaThresholdDegrees;

      if (timeOk && (deltaOk || currentDirection == 0.0)) {
        currentDirection = heading;
        _lastHeadingUpdateAt = now;
        userSquadLocationService
            .updateMemberDirectionFromUser(currentDirection);
      }
    });
  }

  setLocationSettingsPerPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = locator.AndroidSettings(
          accuracy: locator.LocationAccuracy.low,
          distanceFilter: 10,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 20),
          //(Optional) Set foreground notification config to keep the app alive
          //when going to the background
          foregroundNotificationConfig:
              const locator.ForegroundNotificationConfig(
            notificationText:
                "Squad Tracker will continue to receive your location even when you aren't using it",
            notificationTitle: "Listening to position",
            // enableWakeLock: true,
          ));
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = locator.AppleSettings(
        accuracy: locator.LocationAccuracy.low,
        activityType: locator.ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: true,
        // Only set to true if our app will be started up in the background.
        showBackgroundLocationIndicator: false,
      );
    } else if (kIsWeb) {
      locationSettings = locator.WebSettings(
        accuracy: locator.LocationAccuracy.medium,
        distanceFilter: 10,
        maximumAge: const Duration(minutes: 5),
      );
    } else {
      locationSettings = const locator.LocationSettings(
        accuracy: locator.LocationAccuracy.low,
        distanceFilter: 10,
      );
    }
  }

  loadUserPuck() async {
    final ByteData bytes =
        await rootBundle.load('assets/images/soldiers/default_soldier.png');
    final Uint8List list = bytes.buffer.asUint8List();

    mapboxMap?.location.updateSettings(mapbox.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        showAccuracyRing: true,
        locationPuck: mapbox.LocationPuck(
            locationPuck2D: mapbox.DefaultLocationPuck2D(topImage: list))));
  }

  flyToUserLocation() async {
    final hasPermission = await getLocationPermission();
    if (hasPermission == false ||
        userSquadLocationService.currentUserLocation == null) {
      return;
    }
    flyToLocation(userSquadLocationService.currentUserLocation!.longitude!,
        userSquadLocationService.currentUserLocation!.latitude!);
  }

  flyToLocation(num longitude, num latitude) async {
    isProgrammaticCameraChange = true;
    await mapboxMap?.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(longitude, latitude)),
        zoom: 17,
      ),
      mapbox.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
    isProgrammaticCameraChange = false;
  }
}
