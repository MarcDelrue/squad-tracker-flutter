import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as locator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:permission_handler/permission_handler.dart';
import 'package:squad_tracker_flutter/models/user_squad_location.dart';
import 'package:squad_tracker_flutter/models/user_with_session.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';

class GameMapWidget extends StatefulWidget {
  const GameMapWidget({super.key});

  @override
  State<StatefulWidget> createState() => GameMapWidgetState();
}

class GameMapWidgetState extends State<GameMapWidget> {
  GameMapWidgetState();

  final userSquadLocationService = UserSquadLocationService();
  final squadMembersService = SquadMembersService();

  final membersAnnotations = [];
  late locator.LocationSettings? locationSettings;
  bool cameraInitialized = false;
  var currentDirection = 0.0;
  late Uint8List soldierImage = Uint8List(0);
  late mapbox.PointAnnotationManager pointAnnotationManager;
  List<mapbox.PointAnnotation>? membersPointAnnotations;
  Map<String, UserSquadLocation>? membersLocation;

  mapbox.MapboxMap? mapboxMap;

  _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.loadStyleURI(mapbox.MapboxStyles.SATELLITE);
    final hasPermission = await getLocationPermission();
    if (hasPermission) {
      trackUserLocation();
      getUserDirection();
    }
    initMembersAnnotation();
    userSquadLocationService.addListener(updateMembersAnnotation);
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
    loadUserPuck();

    setLocationSettingsPerPlatform();
    locator.Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((locator.Position? position) {
      if (position != null) {
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
  }

  getUserDirection() {
    FlutterCompass.events?.listen((CompassEvent event) {
      double? direction = event.heading;

      if (direction == null) {
        debugPrint('Device does not have sensors!');
      } else {
        currentDirection = direction;
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
    mapboxMap?.location.updateSettings(mapbox.LocationComponentSettings(
        enabled: true, showAccuracyRing: true));
    final ByteData bytes =
        await rootBundle.load('assets/images/soldiers/default_soldier.png');
    final Uint8List list = bytes.buffer.asUint8List();

    mapboxMap?.location.updateSettings(mapbox.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        locationPuck: mapbox.LocationPuck(
            locationPuck2D: mapbox.DefaultLocationPuck2D(
                topImage: list, shadowImage: Uint8List.fromList([])))));

    mapboxMap?.location
        .getSettings()
        .then((value) => {debugPrint('puckBearing: ${value.puckBearing}')});
  }

  flyToLocation(double longitude, double latitude) {
    mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(longitude, latitude)),
        zoom: 17,
      ),
      mapbox.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    userSquadLocationService.removeListener(updateMembersAnnotation);
    super.dispose();
  }

  initMembersAnnotation() async {
    // if (userSquadLocationService.currentMembersLocation == null) {
    //   return;
    // }

    pointAnnotationManager =
        await mapboxMap!.annotations.createPointAnnotationManager();

    // Load the image from assets
    final ByteData bytes =
        await rootBundle.load('assets/images/soldiers/default_soldier.png');
    soldierImage = bytes.buffer.asUint8List();
  }

  setInitialMembersAnnotation() async {
    List<mapbox.PointAnnotationOptions> annotations = [];
    // Iterate through each member's location and create a PointAnnotationOptions
    for (var location in userSquadLocationService.currentMembersLocation!) {
      debugPrint('The direction is ${location.direction ?? 0}');
      UserWithSession foundMember =
          squadMembersService.getMemberDataById(location.user_id);
      mapbox.PointAnnotationOptions pointAnnotationOptions =
          mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
            coordinates: mapbox.Position(
                location.longitude as num, location.latitude as num)),
        image: soldierImage,
        iconRotate: location.direction ?? 0,
        textField: foundMember.user.username,
        textColor: hexToColor(foundMember.user.main_color ?? '#000000').value,
        textOffset: [0, 2.0],
        textHaloBlur: 1.0,
        textHaloWidth: 1.0,
        textHaloColor: Colors.black.value,
        iconSize: 1.0,
      );

      annotations.add(pointAnnotationOptions);
    }
    membersPointAnnotations =
        (await pointAnnotationManager.createMulti(annotations))
            .cast<mapbox.PointAnnotation>();
  }

  updateMembersAnnotation() {
    if (membersPointAnnotations == null) {
      setInitialMembersAnnotation();
    }
  }

  // Widget _showBearing() {
  //   return TextButton(
  //     child: const Text('show location bearing'),
  //     onPressed: () {
  //       mapboxMap?.location.updateSettings(
  //           mapbox.LocationComponentSettings(puckBearingEnabled: true));
  //     },
  //   );
  // }

  // Widget _hideBearing() {
  //   return TextButton(
  //     child: const Text('hide location bearing'),
  //     onPressed: () {
  //       mapboxMap?.location.updateSettings(
  //           mapbox.LocationComponentSettings(puckBearingEnabled: false));
  //     },
  //   );
  // }

  // Widget _showAccuracy() {
  //   return TextButton(
  //     child: const Text('show accuracy'),
  //     onPressed: () {
  //       mapboxMap?.location.updateSettings(
  //           mapbox.LocationComponentSettings(showAccuracyRing: true));
  //     },
  //   );
  // }

  // Widget _hideAccuracy() {
  //   return TextButton(
  //     child: const Text('hide accuracy'),
  //     onPressed: () {
  //       mapboxMap?.location.updateSettings(
  //           mapbox.LocationComponentSettings(showAccuracyRing: false));
  //     },
  //   );
  // }

  // Widget _getPermission() {
  //   return TextButton(
  //     child: const Text('get location permission'),
  //     onPressed: () async {
  //       var status = await Permission.locationWhenInUse.request();
  //       debugPrint("Location granted : $status");
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final mapbox.MapWidget mapWidget = mapbox.MapWidget(
        key: const ValueKey("mapWidget"), onMapCreated: _onMapCreated);

    // final List<Widget> listViewChildren = <Widget>[];

    // listViewChildren.addAll(
    //   <Widget>[
    //     _getPermission(),
    //     _showBearing(),
    //     _hideBearing(),
    //     _showAccuracy(),
    //     _hideAccuracy(),
    //   ],
    // );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height - 80,
              child: mapWidget),
        ),
        // Expanded(
        //   child: ListView(
        //     children: listViewChildren,
        //   ),
        // )
      ],
    );
  }
}
