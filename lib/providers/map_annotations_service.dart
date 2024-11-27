import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:squad_tracker_flutter/models/user_with_session.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';

class MapAnnotationsService extends ChangeNotifier {
  // Singleton setup
  static final MapAnnotationsService _singleton =
      MapAnnotationsService._internal();
  factory MapAnnotationsService() => _singleton;
  MapAnnotationsService._internal();

  final userSquadLocationService = UserSquadLocationService();
  final squadMembersService = SquadMembersService();

  late mapbox.PointAnnotationManager pointAnnotationManager;
  List<mapbox.PointAnnotation>? membersPointAnnotations;
  late Uint8List soldierImage = Uint8List(0);

  initMembersAnnotation(mapbox.MapboxMap mapboxMap) async {
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // Load the image from assets
    final ByteData bytes =
        await rootBundle.load('assets/images/soldiers/default_soldier.png');
    soldierImage = bytes.buffer.asUint8List();
  }

  updateMembersAnnotation() {
    if (membersPointAnnotations == null) {
      setInitialMembersAnnotation();
    }
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
}
