import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_annotations_service.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
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
  final squadService = SquadService();
  final mapAnnotationsService = MapAnnotationsService();
  final mapUserLocationService = MapUserLocationService();

  StreamSubscription<List<UserSquadLocation>>? _locationSubscription;
  StreamSubscription<List<UserWithSession>?>? _squadMembersSubscription;
  VoidCallback? _squadListener;

  mapbox.MapboxMap? mapboxMap;

  _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.loadStyleURI(mapbox.MapboxStyles.SATELLITE);
    mapUserLocationService.init(mapboxMap);
    mapAnnotationsService.initMembersAnnotation(mapboxMap);
    _setupLocationSubscription();
  }

  void _setupLocationSubscription() {
    // Cancel existing subscription if any
    _locationSubscription?.cancel();

    // Set up new subscription
    _locationSubscription = userSquadLocationService
        .currentMembersLocationStream
        .listen((location) {
      if (mapboxMap != null) {
        mapAnnotationsService.updateMembersAnnotation();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Set up location subscription immediately
    _setupLocationSubscription();

    // Listen to squad changes to re-setup location subscription
    _squadListener = () {
      _setupLocationSubscription();
    };
    squadService.addListener(_squadListener!);

    // Listen to squad members changes to update markers when status changes
    _squadMembersSubscription =
        squadMembersService.currentSquadMembersStream.listen((members) {
      if (mapboxMap != null && members != null) {
        mapAnnotationsService.updateMembersAnnotation();
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _squadMembersSubscription?.cancel();
    if (_squadListener != null) {
      squadService.removeListener(_squadListener!);
    }
    mapAnnotationsService.removeEveryAnnotations();
    mapUserLocationService.positionStream?.cancel();
    mapUserLocationService.compassStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapbox.MapWidget mapWidget = mapbox.MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        onCameraChangeListener: (cameraChangedEventData) => {
              // Camera change listener - removed debug log
            });

    return Center(
      child: SizedBox(
          width: MediaQuery.of(context).size.shortestSide, child: mapWidget),
    );
  }
}
