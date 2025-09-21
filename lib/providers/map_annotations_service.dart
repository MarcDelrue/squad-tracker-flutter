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

  static const Duration _staleThreshold = Duration(seconds: 45);

  // Status-based soldier images
  late Uint8List soldierAliveImage = Uint8List(0);
  late Uint8List soldierDeadImage = Uint8List(0);
  late Uint8List soldierHelpImage = Uint8List(0);
  late Uint8List soldierMedicImage = Uint8List(0);
  bool _imagesLoaded = false;

  // Per-game status map
  StreamSubscription<List<Map<String, dynamic>>>? _statusSub;
  final Map<String, UserSquadSessionStatus?> _statusByUserId = {};

  // Track previous status to detect transitions ALIVE↔DEAD
  final Map<String, UserSquadSessionStatus?> _prevStatusByUserId = {};

  // Separate layer for tombstones
  late mapbox.PointAnnotationManager tombstoneAnnotationManager;
  final Map<String, mapbox.PointAnnotation> _tombstoneByUserId = {};

  // Optional: per-user spawn override (if set, dead members render at spawn)
  final Map<String, mapbox.Point> _spawnByUserId = {};

  // Asset for tombstone (fallback to soldierDead if not provided)
  late Uint8List tombstoneImage = Uint8List(0);

  // Pulsating logic removed for performance

  Future<void> initMembersAnnotation(mapbox.MapboxMap mapboxMap) async {
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    pointAnnotationManager
        .setIconRotationAlignment(mapbox.IconRotationAlignment.MAP);

    tombstoneAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

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

      // Try to load a dedicated tombstone icon; fallback to soldierDead
      try {
        final ByteData tombBytes =
            await rootBundle.load('assets/images/markers/tombstone.png');
        tombstoneImage = tombBytes.buffer.asUint8List();
      } catch (_) {
        tombstoneImage = soldierDeadImage;
      }
      _imagesLoaded = soldierAliveImage.isNotEmpty &&
          soldierDeadImage.isNotEmpty &&
          soldierHelpImage.isNotEmpty &&
          soldierMedicImage.isNotEmpty;
    } catch (e) {
      debugPrint('Error loading soldier images: $e');
      _imagesLoaded = false;
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
      final previous =
          Map<String, UserSquadSessionStatus?>.from(_statusByUserId);
      final next = <String, UserSquadSessionStatus?>{};
      for (final r in rows) {
        final userId = r['user_id'] as String?;
        if (userId == null) continue;
        final s = r['user_status'];
        if (s is String) {
          try {
            next[userId] = UserSquadSessionStatusExtension.fromValue(s);
          } catch (_) {
            next[userId] = null;
          }
        }
      }

      // Handle transitions: ALIVE->DEAD => drop; DEAD->ALIVE => remove
      for (final entry in next.entries) {
        final userId = entry.key;
        final newS = entry.value;
        final oldS = previous[userId];
        if (oldS != UserSquadSessionStatus.dead &&
            newS == UserSquadSessionStatus.dead) {
          _dropTombstoneFor(userId);
        } else if (oldS == UserSquadSessionStatus.dead &&
            newS != UserSquadSessionStatus.dead) {
          _removeTombstoneFor(userId);
        }
      }

      _statusByUserId
        ..clear()
        ..addAll(next);
      _prevStatusByUserId
        ..clear()
        ..addAll(next);

      // Force update icons when statuses change
      _forceRecreateAnnotations();
    });
  }

  void removeEveryAnnotations() {
    try {
      pointAnnotationManager.deleteAll();
    } catch (e) {
      // PointAnnotationManager might not be initialized yet
      debugPrint('Could not delete annotations: $e');
    }
    try {
      tombstoneAnnotationManager.deleteAll();
    } catch (e) {
      debugPrint('Could not delete tombstone annotations: $e');
    }
    membersPointAnnotations = null;
    _tombstoneByUserId.clear();
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

  bool _isStale(DateTime? updatedAt) {
    if (updatedAt == null) return true;
    return DateTime.now().toUtc().difference(updatedAt.toUtc()) >
        _staleThreshold;
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

  void updateMembersAnnotation() {
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

  Future<void> setInitialMembersAnnotation() async {
    // Avoid creating annotations until images are loaded to prevent
    // native decodeByteArray(...) null crashes inside Mapbox.
    if (!_imagesLoaded) {
      if (kDebugMode) {
        debugPrint('Soldier images not loaded yet; skipping annotations.');
      }
      return;
    }
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
      if (statusIcon.isEmpty) {
        // Skip if the icon bytes are empty as Mapbox will crash decoding it
        continue;
      }
      final statusColor =
          _getStatusColor(effectiveStatus, foundMember.user.main_color);
      final iconSize = _getStatusIconSize(effectiveStatus);
      final iconRotation =
          _getStatusIconRotation(effectiveStatus, location.direction);
      final isStale = _isStale(location.updated_at);

      // If user is dead and we know a spawn coordinate, render at spawn
      final maybeSpawn = effectiveStatus == UserSquadSessionStatus.dead
          ? _spawnByUserId[foundMember.user.id]
          : null;
      final point = maybeSpawn ??
          mapbox.Point(
              coordinates: mapbox.Position(
                  location.longitude as num, location.latitude as num));

      mapbox.PointAnnotationOptions pointAnnotationOptions =
          mapbox.PointAnnotationOptions(
        geometry: point,
        image: statusIcon,
        iconRotate: iconRotation,
        textField: foundMember.user.username,
        // Fade text color to gray when the location is stale
        textColor: (isStale ? Colors.grey : statusColor).value,
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

  Future<void> _dropTombstoneFor(String userId) async {
    try {
      // If we already have one, remove first (de-dup)
      _removeTombstoneFor(userId);

      // Find last known coordinates for this user
      final loc = userSquadLocationService.currentMembersLocation?.firstWhere(
          (l) => l.user_id == userId,
          orElse: () => throw StateError('no loc'));
      if (loc == null || loc.longitude == null || loc.latitude == null) return;

      final member = SquadMembersService().getMemberDataById(userId);
      final username = member.user.username ?? '';

      final opts = mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
          coordinates:
              mapbox.Position(loc.longitude as num, loc.latitude as num),
        ),
        image: tombstoneImage,
        textField: '☠ ' + username,
        textColor: Colors.white.value,
        textHaloColor: Colors.black.value,
        textHaloWidth: 1.0,
        textOffset: [0, 2.0],
        iconSize: 1.2,
      );

      final created = await tombstoneAnnotationManager.create(opts);
      _tombstoneByUserId[userId] = created;
    } catch (e) {
      debugPrint(
          'Failed to drop tombstone for ' + userId + ': ' + e.toString());
    }
  }

  void _removeTombstoneFor(String userId) {
    try {
      final ann = _tombstoneByUserId.remove(userId);
      if (ann != null) {
        tombstoneAnnotationManager.delete(ann);
      }
    } catch (e) {
      debugPrint(
          'Failed to remove tombstone for ' + userId + ': ' + e.toString());
    }
  }

  // Public APIs
  void removeTombstoneByUserId(String userId) => _removeTombstoneFor(userId);

  void setSpawnForUser(String userId,
      {required num longitude, required num latitude}) {
    _spawnByUserId[userId] =
        mapbox.Point(coordinates: mapbox.Position(longitude, latitude));
    _forceRecreateAnnotations();
  }

  void clearSpawnForUser(String userId) {
    _spawnByUserId.remove(userId);
    _forceRecreateAnnotations();
  }
}
