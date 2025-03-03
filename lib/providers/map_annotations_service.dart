import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
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
    pointAnnotationManager
        .setIconRotationAlignment(mapbox.IconRotationAlignment.MAP);
    // Load the image from assets
    final ByteData bytes =
        await rootBundle.load('assets/images/soldiers/default_soldier.png');
    soldierImage = bytes.buffer.asUint8List();
  }

  removeEveryAnnotations() {
    pointAnnotationManager.deleteAll();
    membersPointAnnotations = null;
  }

  void removeMembersAnnotation(String username) {
    if (membersPointAnnotations == null) return;
    // Find the annotation with the matching username
    final foundMemberAnnotation = membersPointAnnotations!.firstWhere(
      (annotation) => annotation.textField == username,
    );

    pointAnnotationManager.delete(foundMemberAnnotation);
    membersPointAnnotations!.remove(foundMemberAnnotation);
    debugPrint('Removed member annotation for $username');
  }

  updateMembersAnnotation() {
    if (membersPointAnnotations == null) {
      setInitialMembersAnnotation();
    } else {
      for (var i = 0;
          i < userSquadLocationService.currentMembersLocation!.length;
          i++) {
        var location = userSquadLocationService.currentMembersLocation![i];
        var annotation = membersPointAnnotations![i];

        if (location.longitude == null ||
            location.latitude == null ||
            annotation == null) {
          continue;
        }

        annotation.geometry = mapbox.Point(
            coordinates: mapbox.Position(
                location.longitude as num, location.latitude as num));
        annotation.iconRotate = location.direction?.toDouble() ?? 0;

        // Optionally update the annotation manager to reflect these changes on the map
        pointAnnotationManager.update(annotation);
      }
      debugPrint('Updated members annotation $membersPointAnnotations');
    }
  }

  setInitialMembersAnnotation() async {
    List<mapbox.PointAnnotationOptions> annotations = [];
    // Iterate through each member's location and create a PointAnnotationOptions
    for (var location in userSquadLocationService.currentMembersLocation!) {
      if (location.longitude == null || location.latitude == null) {
        continue;
      }
      UserWithSession foundMember =
          squadMembersService.getMemberDataById(location.user_id);
      mapbox.PointAnnotationOptions pointAnnotationOptions =
          mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
            coordinates: mapbox.Position(
                location.longitude as num, location.latitude as num)),
        image: soldierImage,
        iconRotate: location.direction?.toDouble() ?? 0,
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
