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
  bool cameraInitialized = false;
  bool isProgrammaticCameraChange = false;
  late Uint8List soldierImage = Uint8List(0);

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
        userSquadLocationService.saveCurrentLocation(
            position.longitude, position.latitude, currentDirection);
        if (cameraInitialized == false) {
          flyToLocation(position.longitude, position.latitude);
          cameraInitialized = true;
        }
      }
      debugPrint(position == null
          ? 'Unknown'
          : 'Current position: ${position.latitude.toString()}, ${position.longitude.toString()}');
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
    double? currentDirection;

    compassStream = FlutterCompass.events!.listen((CompassEvent event) {
      if (event.heading == null) {
        debugPrint('Device does not have sensors!');
      } else {
        if (currentDirection != null &&
            (currentDirection! - event.heading!).abs() > 5) {
          currentDirection = event.heading;
          userSquadLocationService
              .updateMemberDirectionFromUser(currentDirection);
        }
      }
    });
  }

  setLocationSettingsPerPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = locator.AndroidSettings(
          accuracy: locator.LocationAccuracy.best,
          distanceFilter: 1,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 10),
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
        accuracy: locator.LocationAccuracy.best,
        activityType: locator.ActivityType.fitness,
        distanceFilter: 1,
        pauseLocationUpdatesAutomatically: true,
        // Only set to true if our app will be started up in the background.
        showBackgroundLocationIndicator: false,
      );
    } else if (kIsWeb) {
      locationSettings = locator.WebSettings(
        accuracy: locator.LocationAccuracy.best,
        distanceFilter: 1,
        maximumAge: const Duration(minutes: 5),
      );
    } else {
      locationSettings = const locator.LocationSettings(
        accuracy: locator.LocationAccuracy.high,
        distanceFilter: 1,
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
    if (hasPermission == true &&
        userSquadLocationService.currentUserLocation == null) return;
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
