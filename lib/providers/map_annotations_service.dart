import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'dart:async';

class MapAnnotationsService extends ChangeNotifier {
  // Singleton setup
  static final MapAnnotationsService _singleton =
      MapAnnotationsService._internal();
  factory MapAnnotationsService() => _singleton;
  MapAnnotationsService._internal();

  final userSquadLocationService = UserSquadLocationService();
  final gameService = GameService();
  SquadService get squadService => SquadService();

  late mapbox.PointAnnotationManager pointAnnotationManager;
  List<mapbox.PointAnnotation>? membersPointAnnotations;

  // Status-based soldier images
  late Uint8List soldierAliveImage = Uint8List(0);
  late Uint8List soldierDeadImage = Uint8List(0);
  late Uint8List soldierHelpImage = Uint8List(0);
  late Uint8List soldierMedicImage = Uint8List(0);

  // Per-game status map
  StreamSubscription<List<Map<String, dynamic>>>? _statusSub;
  final Map<String, UserSquadSessionStatus?> _statusByUserId = {};

  // Pulsating logic removed for performance

  initMembersAnnotation(mapbox.MapboxMap mapboxMap) async {
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    pointAnnotationManager
        .setIconRotationAlignment(mapbox.IconRotationAlignment.MAP);

    // Load all status-based soldier images
    try {
      final ByteData aliveBytes =
          await rootBundle.load('assets/images/soldiers/default_soldier.png');
      soldierAliveImage = aliveBytes.buffer.asUint8List();
      if (kDebugMode) {
        debugPrint('Loaded alive image, size: ${soldierAliveImage.length}');
      }

      final ByteData deadBytes =
          await rootBundle.load('assets/images/soldiers/soldier_dead.png');
      soldierDeadImage = deadBytes.buffer.asUint8List();
      if (kDebugMode) {
        debugPrint('Loaded dead image, size: ${soldierDeadImage.length}');
      }

      final ByteData helpBytes =
          await rootBundle.load('assets/images/soldiers/soldier_help.png');
      soldierHelpImage = helpBytes.buffer.asUint8List();
      if (kDebugMode) {
        debugPrint('Loaded help image, size: ${soldierHelpImage.length}');
      }

      final ByteData medicBytes =
          await rootBundle.load('assets/images/soldiers/soldier_medic.png');
      soldierMedicImage = medicBytes.buffer.asUint8List();
      if (kDebugMode) {
        debugPrint('Loaded medic image, size: ${soldierMedicImage.length}');
      }
    } catch (e) {
      debugPrint('Error loading soldier images: $e');
    }

    // Subscribe to per-game status
    await subscribeToGameStatus();
  }

  Future<void> subscribeToGameStatus() async {
    _statusSub?.cancel();
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr == null) return;
    final gameId = await gameService.getActiveGameId(int.parse(squadIdStr));
    if (gameId == null) return;
    _statusSub = gameService.streamScoreboardByGame(gameId).listen((rows) {
      _statusByUserId.clear();
      for (final r in rows) {
        final userId = r['user_id'] as String?;
        if (userId == null) continue;
        final s = r['user_status'];
        if (s is String) {
          try {
            _statusByUserId[userId] =
                UserSquadSessionStatusExtension.fromValue(s);
          } catch (_) {
            _statusByUserId[userId] = null;
          }
        }
      }
      // Force update icons when statuses change
      _forceRecreateAnnotations();
    });
  }

  removeEveryAnnotations() {
    try {
      pointAnnotationManager.deleteAll();
    } catch (e) {
      // PointAnnotationManager might not be initialized yet
      debugPrint('Could not delete annotations: $e');
    }
    membersPointAnnotations = null;
  }

  Uint8List _getStatusIcon(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return soldierAliveImage;
      case UserSquadSessionStatus.dead:
        return soldierDeadImage;
      case UserSquadSessionStatus.help:
        return soldierHelpImage;
      case UserSquadSessionStatus.medic:
        return soldierMedicImage;
      default:
        return soldierAliveImage;
    }
  }

  Color _getStatusColor(UserSquadSessionStatus? status, String? userColor) {
    // Always use the user's main color for text, regardless of status
    return hexToColor(userColor ?? '#000000');
  }

  double _getStatusIconSize(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return 1.0; // 250px image - normal scale
      case UserSquadSessionStatus.dead:
        return 1.5; // 64px image - scale up to match 250px (250/64 ≈ 3.9)
      case UserSquadSessionStatus.help:
        return 1.5; // Base size for help (pulsating will be applied separately)
      case UserSquadSessionStatus.medic:
        return 1.5; // Base size for medic (pulsating will be applied separately)
      default:
        return 1.0;
    }
  }

  double _getStatusIconRotation(
      UserSquadSessionStatus? status, num? direction) {
    // Only rotate if user is alive and has a direction
    if (status == UserSquadSessionStatus.alive && direction != null) {
      return direction.toDouble();
    }
    // Dead, help, and medic statuses don't rotate
    return 0.0;
  }

  void removeMembersAnnotation(String username) {
    if (membersPointAnnotations == null) return;
    // Find the annotation with the matching username
    final foundMemberAnnotation = membersPointAnnotations!.firstWhere(
      (annotation) => annotation.textField == username,
    );

    pointAnnotationManager.delete(foundMemberAnnotation);
    membersPointAnnotations!.remove(foundMemberAnnotation);
  }

  updateMembersAnnotation() {
    if (membersPointAnnotations == null) {
      setInitialMembersAnnotation();
    } else {
      // Force recreate annotations when status changes to ensure icons update
      _forceRecreateAnnotations();
    }
  }

  // Removed _updateExistingAnnotations as pulsating updates are no longer used

  void _forceRecreateAnnotations() async {
    try {
      // Clear existing annotations
      await pointAnnotationManager.deleteAll();
      membersPointAnnotations = null;

      // Recreate with new status-based icons
      await setInitialMembersAnnotation();
    } catch (e) {
      debugPrint('Error recreating annotations: $e');
    }
  }

  setInitialMembersAnnotation() async {
    if (userSquadLocationService.currentMembersLocation == null ||
        userSquadLocationService.currentMembersLocation!.isEmpty) {
      return;
    }

    List<mapbox.PointAnnotationOptions> annotations = [];
    // Iterate through each member's location and create a PointAnnotationOptions
    for (var location in userSquadLocationService.currentMembersLocation!) {
      if (location.longitude == null || location.latitude == null) {
        continue;
      }
      UserWithSession foundMember =
          SquadMembersService().getMemberDataById(location.user_id);
      final effectiveStatus = _statusByUserId[foundMember.user.id] ??
          foundMember.session.user_status;
      final statusIcon = _getStatusIcon(effectiveStatus);
      final statusColor =
          _getStatusColor(effectiveStatus, foundMember.user.main_color);
      final iconSize = _getStatusIconSize(effectiveStatus);
      final iconRotation =
          _getStatusIconRotation(effectiveStatus, location.direction);

      mapbox.PointAnnotationOptions pointAnnotationOptions =
          mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
            coordinates: mapbox.Position(
                location.longitude as num, location.latitude as num)),
        image: statusIcon,
        iconRotate: iconRotation,
        textField: foundMember.user.username,
        textColor: statusColor.value,
        textOffset: [0, 2.0],
        textHaloBlur: 1.0,
        textHaloWidth: 1.0,
        textHaloColor: Colors.black.value,
        iconSize: iconSize,
      );

      annotations.add(pointAnnotationOptions);
    }

    if (annotations.isNotEmpty) {
      membersPointAnnotations =
          (await pointAnnotationManager.createMulti(annotations))
              .cast<mapbox.PointAnnotation>();
    }
  }
}
