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
// Removed navigation/map imports; navigation handled via named routes
import 'package:squad_tracker_flutter/providers/notification_settings_service.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';
// import removed: user_service is not used here
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
  StreamSubscription<List<Map<String, dynamic>>>? _responsesSub;
  StreamSubscription<Map<String, dynamic>?>? _gameMetaSub;
  final Set<String> _activeNotifications = <String>{};
  final Map<String, HelpRequest> _activeBanners = <String, HelpRequest>{};
  final Map<String, DateTime> _recentlyResolved = <String, DateTime>{};
  final Map<String, int> _requestProcessCount = <String, int>{};
  final Set<String> _cancelSentFor = <String>{};
  final Set<String> _openedRequesterScreens = <String>{};
  bool _initialized = false;
  bool _isAppInForeground = true;

  // Coalescing window for acceptance notifications (requester side)
  final Map<String, _AcceptCoalescer> _acceptCoalescers =
      <String, _AcceptCoalescer>{};

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
        debugPrint(
            '[help] Received ${rows.length} help_requests rows from stream');
        final filtered = rows.where((r) =>
            (r['squad_id'] as int?) == squadId &&
            (r['game_id'] as int?) == gameId);
        debugPrint(
            '[help] Filtered to ${filtered.length} rows for squad $squadId, game $gameId');
        for (final r in filtered) {
          final id = r['id']?.toString();
          if (id == null) continue;
          final resolvedAt = r['resolved_at'];
          final requesterId = r['requester_id']?.toString();
          final status = r['status']?.toString();
          _requestProcessCount[id] = (_requestProcessCount[id] ?? 0) + 1;
          debugPrint(
              '[help] Processing request $id (count: ${_requestProcessCount[id]}): requester=$requesterId, status=$status, resolved_at=$resolvedAt');
          if (resolvedAt != null) {
            debugPrint(
                '[help] Request $id resolved at $resolvedAt - dismissing notifications');
            _activeNotifications.remove(id);
            _recentlyResolved[id] = DateTime.now();
            // Dismiss in-app banner, system notification, and TTGO overlay exactly once
            if (!_cancelSentFor.contains(id)) {
              _cancelSentFor.add(id);
              _dismissInAppBanner(id);
              _ln.cancel(_hashId(id));
              _sendBleCancel(id);
              _openedRequesterScreens.remove(id);
            } else {
              debugPrint('[help] Cancel already sent for $id, skipping');
            }
            continue;
          }
          if (_activeNotifications.contains(id)) continue;

          // Check if this request was recently resolved (debounce)
          final recentlyResolved = _recentlyResolved[id];
          if (recentlyResolved != null &&
              DateTime.now().difference(recentlyResolved).inSeconds < 5) {
            debugPrint('[help] Skipping recently resolved request: $id');
            continue;
          }

          final requesterId2 = r['requester_id']?.toString();
          final statusStr = r['status']?.toString() ?? 'HELP';
          final status2 = UserSquadSessionStatusExtension.fromValue(statusStr);
          if (requesterId2 == _sb.auth.currentUser?.id) {
            continue; // don't notify self
          }
          debugPrint(
              '[help] New help request received: $id from $requesterId2 with status $statusStr');
          _emitNotificationForRow(r, status2);
        }
      });

      // Subscribe to help_responses for requests opened by me and unresolved
      await _responsesSub?.cancel();
      final myId = _sb.auth.currentUser?.id;
      if (myId != null) {
        _responsesSub = _sb
            .from('help_responses')
            .stream(primaryKey: ['id']).listen((rows) async {
          // We must join against help_requests to ensure requester_id == me and unresolved
          if (rows.isEmpty) return;
          final ids = rows
              .map((r) => r['request_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          if (ids.isEmpty) return;
          try {
            final reqRows = await _sb
                .from('help_requests')
                .select('id, requester_id, resolved_at, squad_id, game_id')
                .inFilter('id', ids);
            final byId = {for (final r in reqRows) r['id'].toString(): r};
            for (final r in rows) {
              final requestId = r['request_id']?.toString();
              final responderId = r['responder_id']?.toString();
              final response = r['response']?.toString();
              if (requestId == null || responderId == null) continue;
              final req = byId[requestId];
              if (req == null) continue;
              if (req['resolved_at'] != null) continue; // ignore resolved
              if (req['requester_id']?.toString() != myId)
                continue; // only my requests
              if (response != 'accepted') continue; // only accepted
              _onAccepted(requestId: requestId, responderId: responderId);
            }
          } catch (_) {}
        });
      }

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
        _settings!.distanceThresholdMeters != null &&
        distanceMeters > _settings!.distanceThresholdMeters!) {
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
      debugPrint('[help] BLE service: ${ble != null ? 'available' : 'null'}');
      if (ble != null) {
        debugPrint(
            '[help] BLE connected device: ${ble.connectedDevice != null ? 'connected' : 'not connected'}');
        if (ble.connectedDevice != null) {
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
          debugPrint('[help] Sending to TTGO: $line');
          await ble.sendString(line);
          debugPrint('[help] BLE send completed');
        }
      }
    } catch (e) {
      debugPrint('[help] BLE send error: $e');
    }
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
    }

    // Only auto-dismiss if timeout > 0
    final to = _settings?.timeoutSeconds ?? 0;
    if (to > 0) {
      Future.delayed(Duration(seconds: to), () async {
        await _ln.cancel(_hashId(request.requestId));
        _activeNotifications.remove(request.requestId);
        _dismissInAppBanner(request.requestId);
      });
    }
  }

  Future<void> showBackgroundNotification(HelpRequest request) async {
    // Same as foreground; platform will show appropriately
    return; // already shown via showForegroundAlert
  }

  Future<void> handleResponse(String requestId, HelpResponse response) async {
    // Upsert to prevent duplicates across devices
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid != null) {
        await _sb.from('help_responses').upsert({
          'request_id': requestId,
          'responder_id': uid,
          'response': response == HelpResponse.accept ? 'accepted' : 'ignored',
        }, onConflict: 'request_id,responder_id');
      }
    } catch (_) {}
    _activeNotifications.remove(requestId);
    _dismissInAppBanner(requestId);
    await _ln.cancel(_hashId(requestId));
    await _sendBleCancel(requestId);
    // If accepted, navigate to helper assist screen and fly map
    if (response == HelpResponse.accept) {
      try {
        final ctx = _context;
        if (ctx != null) {
          // ignore: use_build_context_synchronously
          Navigator.of(ctx, rootNavigator: true)
              .pushNamed('/help/assist', arguments: requestId);
        }
      } catch (_) {}
    }
  }

  // Handle an accepted response for my request; coalesce and notify
  void _onAccepted(
      {required String requestId, required String responderId}) async {
    // Resolve responder name and optional distance/direction (best-effort)
    String name = responderId.substring(0, 6);
    String colorHex = '#000000';
    double? distanceMeters;
    double? directionDegrees;
    try {
      final names = await GameService().getUsernamesByIds([responderId]);
      name = names[responderId] ?? name;
    } catch (_) {}
    try {
      final memberLoc = _loc.currentMembersLocation
          ?.firstWhereOrNull((l) => l.user_id == responderId);
      final meLoc = _loc.currentUserLocation;
      if (memberLoc != null && meLoc != null) {
        distanceMeters = _distance.calculateDistanceFromUser(memberLoc, meLoc);
        directionDegrees =
            _distance.calculateDirectionToMember(memberLoc, meLoc);
      }
    } catch (_) {}
    try {
      final rows = await _sb
          .from('users')
          .select('id, main_color')
          .inFilter('id', [responderId]);
      if (rows.isNotEmpty) {
        final c = rows.first['main_color']?.toString();
        if (c != null && c.isNotEmpty) colorHex = c;
      }
    } catch (_) {}

    // Immediately open requester screen on first acceptance
    try {
      final ctx = _context;
      if (ctx != null && !_openedRequesterScreens.contains(requestId)) {
        _openedRequesterScreens.add(requestId);
        // ignore: use_build_context_synchronously
        Navigator.of(ctx, rootNavigator: true)
            .pushNamed('/help/requester', arguments: requestId);
      }
    } catch (_) {}

    // Optional: foreground snackbar with a quick message
    try {
      final ctx = _context;
      if (_isAppInForeground && ctx != null) {
        final loc = AppLocalizations.of(ctx);
        final base = loc?.helpAcceptedSingle(name) ?? '$name is on the way';
        final parts = <String>[];
        if (distanceMeters != null) parts.add('${distanceMeters!.round()} m');
        if (directionDegrees != null)
          parts.add('${directionDegrees!.round()}°');
        final body = parts.isEmpty ? base : '$base — ${parts.join(', ')}';
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(body)));
      }
    } catch (_) {}

    // Send single BLE HELP_ACK entry immediately (device shows top 1 fine)
    try {
      final ble = BleService.global;
      if (ble != null && ble.connectedDevice != null) {
        final distInt = (distanceMeters ?? -1).round();
        final dirDeg = (directionDegrees ?? -1).round();
        final nameSafe = name.replaceAll(' ', '_');
        final color = colorHex.replaceAll('#', '').toUpperCase();
        final line = 'HELP_ACK $requestId $nameSafe $distInt $dirDeg $color';
        await ble.sendString(line);
      }
    } catch (_) {}
  }

  Future<void> _flushAccepts(String requestId) async {
    final coalescer = _acceptCoalescers.remove(requestId);
    if (coalescer == null) return;
    final accepts = coalescer.unique();
    if (accepts.isEmpty) return;

    // Prepare notification content
    final firstThree = accepts.take(3).toList();
    final names = firstThree.map((e) => e.name).join(', ');
    final extra = accepts.length - firstThree.length;

    // In-app/system notification
    try {
      final ctx = _context;
      final hasCtx = ctx != null;
      final loc = hasCtx ? AppLocalizations.of(ctx) : null;
      // ignore: unused_local_variable, undefined_getter
      final _title = loc?.helpAcceptedTitle ?? 'Help accepted';
      String body;
      if (accepts.length == 1) {
        final a = accepts.first;
        final dist = a.distanceMeters?.round();
        final bearing = a.directionDegrees?.round();
        final parts = <String>[];
        if (dist != null) parts.add('$dist m');
        if (bearing != null) parts.add('${bearing}°');
        final suffix = parts.isEmpty ? '' : ' — ${parts.join(', ')}';
        // ignore: undefined_method
        final base =
            loc?.helpAcceptedSingle(a.name) ?? '${a.name} is on the way';
        body = '$base$suffix';
      } else {
        if (extra > 0) {
          // ignore: undefined_method
          body = loc?.helpAcceptedManyCapped(names, extra) ??
              '$names and +$extra others are on the way';
        } else {
          // ignore: undefined_method
          body = loc?.helpAcceptedManyNoExtra(names) ?? '$names are on the way';
        }
      }
      if (_isAppInForeground && hasCtx) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(body)),
        );
        // Also open the requester screen the first time we see an accept
        if (!_openedRequesterScreens.contains(requestId)) {
          _openedRequesterScreens.add(requestId);
          try {
            // ignore: use_build_context_synchronously
            Navigator.of(ctx, rootNavigator: true)
                .pushNamed('/help/requester', arguments: requestId);
          } catch (_) {}
        }
      }
    } catch (_) {}

    // BLE HELP_ACK to device (up to 3 entries)
    try {
      final ble = BleService.global;
      if (ble != null && ble.connectedDevice != null) {
        for (final a in accepts.take(3)) {
          final distInt = (a.distanceMeters ?? -1).round();
          final dirDeg = (a.directionDegrees ?? -1).round();
          final nameSafe = a.name.replaceAll(' ', '_');
          final color = a.colorHex.replaceAll('#', '').toUpperCase();
          final line = 'HELP_ACK $requestId $nameSafe $distInt $dirDeg $color';
          await ble.sendString(line);
        }
      }
    } catch (_) {}
  }

  Future<void> _sendBleCancel(String requestId) async {
    try {
      final ble = BleService.global;
      if (ble != null && ble.connectedDevice != null) {
        final line = 'HELP_CANCEL $requestId';
        debugPrint('[help] Sending BLE cancel: $line');
        await ble.sendString(line);
        debugPrint('[help] BLE cancel completed');
      }
    } catch (e) {
      debugPrint('[help] BLE cancel error: $e');
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
    _responsesSub?.cancel();
    _gameMetaSub?.cancel();
    // Clean up old resolved entries
    final now = DateTime.now();
    _recentlyResolved
        .removeWhere((key, value) => now.difference(value).inSeconds > 10);
    super.dispose();
  }
}

class _AcceptCoalescer {
  final Duration window;
  final List<_AcceptedInfo> _items = <_AcceptedInfo>[];
  Timer? _timer;

  _AcceptCoalescer({required this.window});

  void add(_AcceptedInfo info) {
    // de-dupe by userId
    final exists = _items.any((e) => e.userId == info.userId);
    if (!exists) _items.add(info);
  }

  void schedule(VoidCallback onFire) {
    _timer?.cancel();
    _timer = Timer(window, onFire);
  }

  List<_AcceptedInfo> unique() => List<_AcceptedInfo>.from(_items);
}

class _AcceptedInfo {
  final String userId;
  final String name;
  final double? distanceMeters;
  final double? directionDegrees;
  final String colorHex;

  _AcceptedInfo({
    required this.userId,
    required this.name,
    required this.distanceMeters,
    required this.directionDegrees,
    required this.colorHex,
  });
}
