import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/providers/map_annotations_service.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';

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

  late StreamSubscription<List<UserSquadLocation>> _locationSubscription;

  mapbox.MapboxMap? mapboxMap;

  _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.loadStyleURI(mapbox.MapboxStyles.SATELLITE);
    mapUserLocationService.init(mapboxMap);
    mapAnnotationsService.initMembersAnnotation(mapboxMap);
    _locationSubscription = userSquadLocationService
        .currentMembersLocationStream
        .listen((location) {
      mapAnnotationsService.updateMembersAnnotation();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    mapAnnotationsService.pointAnnotationManager.deleteAll();
    mapUserLocationService.positionStream.cancel();
    mapUserLocationService.compassStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapbox.MapWidget mapWidget = mapbox.MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        onCameraChangeListener: (cameraChangedEventData) => {
              debugPrint(
                  'cameraChangedEventData: ${mapUserLocationService.isProgrammaticCameraChange}'),
            });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height - 80,
              child: mapWidget),
        ),
      ],
    );
  }
}
