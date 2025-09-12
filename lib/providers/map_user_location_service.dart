import 'dart:async';
import 'dart:math' as math;

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
  bool isCameraAnimationInProgress = false;
  DateTime? followModeActivatedAt;

  // Follow mode is a manual toggle: when true, keep camera centered on user.
  final ValueNotifier<bool> isFollowingUser = ValueNotifier<bool>(false);
  // Current map camera bearing in degrees [0, 360).
  final ValueNotifier<double> cameraBearingDegrees = ValueNotifier<double>(0.0);
  static const double _centerThresholdPixels = 60.0;

  // Throttling/power settings for saving location to backend
  DateTime? _lastSavedLocationAt;
  locator.Position? _lastSavedPosition;
  final Duration _minSaveInterval = const Duration(seconds: 15);
  final double _minSaveDistanceMeters = 10.0;

  Future<void> init(mapbox.MapboxMap mapboxMapReference) async {
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

  Future<void> trackUserLocation() async {
    positionStream =
        locator.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((locator.Position? position) async {
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
          // One-time auto-center on first fix; follow remains manual.
          await flyToLocation(position.longitude, position.latitude,
              zoom: 17, duration: const Duration(milliseconds: 700));
          cameraInitialized = true;
        } else {
          if (isFollowingUser.value) {
            await _setCameraCenter(position.longitude, position.latitude,
                animate: false);
          }
        }
      }
      if (kDebugMode) {
        debugPrint(position == null
            ? 'Unknown'
            : 'Current position: ${position.latitude.toString()}, ${position.longitude.toString()}');
      }

      // No auto-enable/disable based on camera proximity. Follow is manual.
    });
    _isStreamInitialized = true;
  }

  void pauseTrackingUserLocation() {
    positionStream?.pause();
    compassStream?.pause();
    mapboxMap?.location
        .updateSettings(mapbox.LocationComponentSettings(enabled: false));
  }

  void unpauseTrackingUserLocation() {
    positionStream?.resume();
    compassStream?.resume();
    loadUserPuck();
  }

  void getUserDirection() {
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

  void setLocationSettingsPerPlatform() {
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

  Future<void> loadUserPuck() async {
    final ByteData bytes =
        await rootBundle.load('assets/images/soldiers/default_soldier.png');
    final list = bytes.buffer.asUint8List();

    mapboxMap?.location.updateSettings(mapbox.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        showAccuracyRing: true,
        locationPuck: mapbox.LocationPuck(
            locationPuck2D: mapbox.DefaultLocationPuck2D(topImage: list))));
  }

  Future<void> enableFollow() async {
    final hasPermission = await getLocationPermission();
    if (!hasPermission ||
        userSquadLocationService.currentUserLocation == null) {
      return;
    }
    isFollowingUser.value = true;
    followModeActivatedAt = DateTime.now();
    await flyToLocation(
      userSquadLocationService.currentUserLocation!.longitude!,
      userSquadLocationService.currentUserLocation!.latitude!,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> disableFollow() async {
    isFollowingUser.value = false;
  }

  Future<void> toggleFollow() async {
    if (isFollowingUser.value) {
      await disableFollow();
    } else {
      await enableFollow();
    }
  }

  // Determine if the given camera center is still close enough to the user's
  // location to consider it centered, using a pixel-based threshold adapted to zoom.
  bool isCameraCenteredOnUser(mapbox.CameraState cameraState) {
    final lat = userSquadLocationService.currentUserLocation?.latitude;
    final lng = userSquadLocationService.currentUserLocation?.longitude;
    if (lat == null || lng == null) return false;

    final centerLat = cameraState.center.coordinates.lat.toDouble();
    final centerLng = cameraState.center.coordinates.lng.toDouble();
    final distanceMeters = locator.Geolocator.distanceBetween(
        lat.toDouble(), lng.toDouble(), centerLat, centerLng);
    final metersPerPixel = 156543.03392 *
        math.cos(centerLat * math.pi / 180.0) /
        math.pow(2.0, cameraState.zoom);
    final thresholdMeters =
        math.max(15.0, _centerThresholdPixels * metersPerPixel);
    return distanceMeters <= thresholdMeters;
  }

  Future<void> flyToLocation(num longitude, num latitude,
      {double? zoom,
      Duration duration = const Duration(milliseconds: 800)}) async {
    isProgrammaticCameraChange = true;
    isCameraAnimationInProgress = true;
    double? effectiveZoom = zoom;
    if (effectiveZoom == null) {
      try {
        final cameraState = await mapboxMap?.getCameraState();
        if (cameraState != null && cameraState.zoom < 15) {
          effectiveZoom = 17;
        }
      } catch (_) {}
    }
    await mapboxMap?.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(longitude, latitude)),
        // Only set zoom when requested; otherwise preserve current zoom
        zoom: effectiveZoom,
      ),
      mapbox.MapAnimationOptions(
          duration: duration.inMilliseconds, startDelay: 0),
    );
    isProgrammaticCameraChange = false;
    isCameraAnimationInProgress = false;
  }

  // Set camera center immediately or with a short ease, preserving current zoom
  Future<void> _setCameraCenter(num longitude, num latitude,
      {bool animate = false,
      Duration duration = const Duration(milliseconds: 250)}) async {
    isProgrammaticCameraChange = true;
    final cameraOptions = mapbox.CameraOptions(
      center: mapbox.Point(coordinates: mapbox.Position(longitude, latitude)),
    );
    if (animate) {
      await mapboxMap?.easeTo(
        cameraOptions,
        mapbox.MapAnimationOptions(
            duration: duration.inMilliseconds, startDelay: 0),
      );
    } else {
      await mapboxMap?.setCamera(cameraOptions);
    }
    isProgrammaticCameraChange = false;
  }

  // Update the current camera bearing (degrees). Normalizes to [0, 360).
  void updateBearingDegrees(double degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    cameraBearingDegrees.value = normalized;
  }

  // Smoothly reset the map bearing to face north (0 degrees).
  Future<void> resetNorth({
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    isProgrammaticCameraChange = true;
    isCameraAnimationInProgress = true;
    await mapboxMap?.easeTo(
      mapbox.CameraOptions(
        bearing: 0.0,
      ),
      mapbox.MapAnimationOptions(
        duration: duration.inMilliseconds,
        startDelay: 0,
      ),
    );
    isProgrammaticCameraChange = false;
    isCameraAnimationInProgress = false;
  }
}
