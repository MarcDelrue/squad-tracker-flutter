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
import 'package:squad_tracker_flutter/providers/map_annotations_service.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
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
  final mapAnnotationsService = MapAnnotationsService();
  final mapUserLocationService = MapUserLocationService();

  mapbox.MapboxMap? mapboxMap;

  _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.loadStyleURI(mapbox.MapboxStyles.SATELLITE);
    mapUserLocationService.init(mapboxMap);
    mapAnnotationsService.initMembersAnnotation(mapboxMap);
    userSquadLocationService
        .addListener(mapAnnotationsService.updateMembersAnnotation);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    userSquadLocationService
        .removeListener(mapAnnotationsService.updateMembersAnnotation);
    super.dispose();
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
