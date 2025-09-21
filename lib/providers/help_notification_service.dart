import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/models/help_request.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/distance_calculator_service.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:squad_tracker_flutter/widgets/navigation.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/notification_settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

enum HelpResponse { ignore, accept }

class HelpNotificationService with ChangeNotifier {
  static final HelpNotificationService _singleton =
      HelpNotificationService._internal();
  factory HelpNotificationService() => _singleton;
  HelpNotificationService._internal();

  final SupabaseClient _sb = Supabase.instance.client;
  final DistanceCalculatorService _distance = DistanceCalculatorService();
  final UserSquadLocationService _loc = UserSquadLocationService();
  final FlutterLocalNotificationsPlugin _ln = FlutterLocalNotificationsPlugin();
  NotificationSettingsService? _settings;
  BuildContext? _context;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription<Map<String, dynamic>?>? _gameMetaSub;
  final Set<String> _activeNotifications = <String>{};
  final Map<String, HelpRequest> _activeBanners = <String, HelpRequest>{};
  bool _initialized = false;
  bool _isAppInForeground = true;

  static const String _channelId = 'help_requests';

  Future<void> initialize(BuildContext context) async {
    if (_initialized) return;

    // Store context and initialize settings
    _context = context;
    _settings = context.read<NotificationSettingsService>();
    await _settings!.initialize();

    // Listen to settings changes
    _settings!.addListener(_onSettingsChanged);
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _ln.initialize(initSettings, onDidReceiveNotificationResponse:
        (NotificationResponse response) async {
      final payload = response.payload ?? '';
      if (payload.startsWith('help:')) {
        final parts = payload.split(':');
        if (parts.length >= 3) {
          final requestId = parts[1];
          final actionFromPayload = parts[2];
          final actionId = response.actionId;
          final decided =
              (actionId == 'help_accept' || actionFromPayload == 'accept')
                  ? HelpResponse.accept
                  : HelpResponse.ignore;
          await handleResponse(requestId, decided);
        }
      }
    });

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      'Help Requests',
      description: 'Notifications for squad help/medic requests',
      importance: Importance.high,
    );
    await _ln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Listen to app lifecycle changes
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == AppLifecycleState.resumed.toString()) {
        _isAppInForeground = true;
      } else if (message == AppLifecycleState.paused.toString() ||
          message == AppLifecycleState.inactive.toString()) {
        _isAppInForeground = false;
      }
      return null;
    });

    _initialized = true;
  }

  void _onSettingsChanged() {
    // Restart listening when settings change
    if (_context != null && _initialized) {
      startListening(_context!);
    }
  }

  Future<void> startListening(BuildContext context) async {
    await initialize(context);
    await _sub?.cancel();
    await _gameMetaSub?.cancel();
    final squad = SquadService().currentSquad;
    if (squad == null) return;
    final squadId = int.parse(squad.id);
    _gameMetaSub =
        GameService().streamActiveGameMetaBySquad(squadId).listen((meta) async {
      final gameId = (meta == null) ? null : (meta['id'] as num?)?.toInt();
      await _sub?.cancel();
      _sub = null;
      if (gameId == null) return;
      _sub =
          _sb.from('help_requests').stream(primaryKey: ['id']).listen((rows) {
        final filtered = rows.where((r) =>
            (r['squad_id'] as int?) == squadId &&
            (r['game_id'] as int?) == gameId);
        for (final r in filtered) {
          final id = r['id']?.toString();
          if (id == null) continue;
          final resolvedAt = r['resolved_at'];
          if (resolvedAt != null) {
            _activeNotifications.remove(id);
            continue;
          }
          if (_activeNotifications.contains(id)) continue;
          final requesterId = r['requester_id']?.toString();
          final statusStr = r['status']?.toString() ?? 'HELP';
          final status = UserSquadSessionStatusExtension.fromValue(statusStr);
          if (requesterId == _sb.auth.currentUser?.id)
            continue; // don't notify self
          _emitNotificationForRow(r, status);
        }
      });

      // Fallback: fetch unresolved requests that already exist
      try {
        final existing = await _sb
            .from('help_requests')
            .select()
            .eq('squad_id', squadId)
            .eq('game_id', gameId)
            .isFilter('resolved_at', null);
        for (final r in existing) {
          final id = r['id']?.toString();
          if (id == null) continue;
          if (_activeNotifications.contains(id)) continue;
          final requesterId = r['requester_id']?.toString();
          if (requesterId == _sb.auth.currentUser?.id) continue;
          final statusStr = r['status']?.toString() ?? 'HELP';
          final status = UserSquadSessionStatusExtension.fromValue(statusStr);
          _emitNotificationForRow(r, status);
        }
      } catch (e) {
        debugPrint('[help] error fetching unresolved help_requests: $e');
      }
    });
  }

  Future<void> _emitNotificationForRow(
      Map<String, dynamic> row, UserSquadSessionStatus status) async {
    // Check if notifications are enabled
    if (_settings?.enabled != true) return;

    final requestId = row['id'].toString();
    final requesterId = row['requester_id']?.toString() ?? '';
    String requesterName = requesterId.substring(0, 6);
    String? colorHex;
    int kills = 0, deaths = 0;
    try {
      // Try to enrich with scoreboard/user data already cached via GameService if available
      final users = await GameService().getUsernamesByIds([requesterId]);
      requesterName = users[requesterId] ?? requesterName;
    } catch (_) {}

    // Distance and bearing
    double? distanceMeters;
    double? directionDegrees;
    try {
      final memberLoc = _loc.currentMembersLocation
          ?.firstWhereOrNull((l) => l.user_id == requesterId);
      final meLoc = _loc.currentUserLocation;
      if (memberLoc != null && meLoc != null) {
        distanceMeters = _distance.calculateDistanceFromUser(memberLoc, meLoc);
        directionDegrees =
            _distance.calculateDirectionToMember(memberLoc, meLoc);
      }
    } catch (_) {}

    // Check distance threshold
    if (distanceMeters != null &&
        _settings != null &&
        distanceMeters > _settings!.distanceThresholdMeters) {
      return; // Skip notification if too far
    }

    final req = HelpRequest(
      requestId: requestId,
      requesterId: requesterId,
      requesterName: requesterName,
      status: status,
      distanceMeters: distanceMeters,
      directionDegrees: directionDegrees,
      timestamp: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      requesterAvatarUrl: null,
      requesterKills: kills,
      requesterDeaths: deaths,
      requesterColorHex: colorHex,
    );

    _activeNotifications.add(requestId);
    await showForegroundAlert(req);
    await showBackgroundNotification(req);

    // Also forward to TTGO device if connected
    try {
      final ble = BleService.global;
      if (ble != null && ble.connectedDevice != null) {
        final dirCard = directionDegrees != null
            ? _bearingToCardinal(directionDegrees)
            : '';
        final color = (colorHex ?? '#8410').replaceAll('#', '').toUpperCase();
        final name = requesterName.replaceAll(' ', '_');
        final distInt = (distanceMeters ?? -1).round();
        final statusToken =
            status == UserSquadSessionStatus.medic ? 'medic' : 'help';
        final line =
            'HELP_REQ $requestId $name $statusToken $distInt $dirCard $color';
        await ble.sendString(line);
      }
    } catch (_) {}
  }

  Future<void> showForegroundAlert(HelpRequest request) async {
    final title =
        '${request.requesterName} needs ${request.status == UserSquadSessionStatus.help ? 'help' : 'medic'}';
    final distancePart = request.distanceMeters != null
        ? '${request.distanceMeters!.round()}m'
        : null;
    final dirPart = request.directionDegrees != null
        ? _bearingToCardinal(request.directionDegrees!)
        : null;
    final bodyParts = <String>[];
    if (distancePart != null) bodyParts.add(distancePart);
    if (dirPart != null) bodyParts.add(dirPart);
    final body = bodyParts.join(' • ');

    if (_isAppInForeground && _settings?.showInAppBanner == true) {
      // App is in foreground - show in-app banner only
      _showInAppBanner(request, title, body);
    } else if (!_isAppInForeground &&
        _settings?.showSystemNotification == true) {
      // App is in background - show system notification only
      await _ln.show(
        _hashId(request.requestId),
        title,
        body.isEmpty ? null : body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Help Requests',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.call,
            playSound: _settings?.soundEnabled ?? true,
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction('help_ignore', 'Ignore',
                  showsUserInterface: true, cancelNotification: true),
              const AndroidNotificationAction('help_accept', 'Go Help',
                  showsUserInterface: true, cancelNotification: true),
            ],
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'help_category',
            presentSound: _settings?.soundEnabled ?? true,
          ),
        ),
        payload: 'help:${request.requestId}:none',
      );
    }

    // Auto dismiss after configured timeout
    Future.delayed(Duration(seconds: _settings?.timeoutSeconds ?? 20),
        () async {
      await _ln.cancel(_hashId(request.requestId));
      _activeNotifications.remove(request.requestId);
      _dismissInAppBanner(request.requestId);
    });
  }

  Future<void> showBackgroundNotification(HelpRequest request) async {
    // Same as foreground; platform will show appropriately
    return; // already shown via showForegroundAlert
  }

  Future<void> handleResponse(String requestId, HelpResponse response) async {
    // Mark resolved in DB if accepting/ignoring as self action
    try {
      await _sb
          .from('help_requests')
          .update({
            'resolved_at': DateTime.now().toIso8601String(),
            'resolved_by': _sb.auth.currentUser?.id,
            'resolution':
                response == HelpResponse.accept ? 'accepted' : 'ignored',
          })
          .eq('id', requestId)
          .isFilter('resolved_at', null);
    } catch (_) {}
    _activeNotifications.remove(requestId);
    _dismissInAppBanner(requestId);
    // If accepted, fly map to requester
    if (response == HelpResponse.accept) {
      try {
        final reqRow = await _sb
            .from('help_requests')
            .select('requester_id')
            .eq('id', requestId)
            .maybeSingle();
        final requesterId = reqRow?['requester_id']?.toString();
        if (requesterId != null) {
          // Compute location and fly camera
          final memberLoc = _loc.currentMembersLocation
              ?.firstWhereOrNull((l) => l.user_id == requesterId);
          if (memberLoc?.latitude != null && memberLoc?.longitude != null) {
            try {
              NavigationWidget.goToTab(2); // Map tab
              await MapUserLocationService().flyToLocation(
                memberLoc!.longitude!,
                memberLoc.latitude!,
              );
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  String _bearingToCardinal(double degrees) {
    const List<String> dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((degrees % 360) / 45).round() % 8;
    return dirs[idx];
  }

  int _hashId(String id) {
    return id.hashCode & 0x7fffffff;
  }

  void _showInAppBanner(HelpRequest request, String title, String body) {
    _activeBanners[request.requestId] = request;
    notifyListeners(); // Trigger UI rebuild to show banner
  }

  void _dismissInAppBanner(String requestId) {
    _activeBanners.remove(requestId);
    notifyListeners(); // Trigger UI rebuild to hide banner
  }

  // Getter for UI to check if there are active banners
  bool get hasActiveBanners => _activeBanners.isNotEmpty;

  // Getter for UI to get the first active banner (for simplicity, show one at a time)
  HelpRequest? get firstActiveBanner =>
      _activeBanners.isNotEmpty ? _activeBanners.values.first : null;

  // Getter for settings service
  NotificationSettingsService? get settingsService => _settings;

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    _sub?.cancel();
    _gameMetaSub?.cancel();
    super.dispose();
  }
}
