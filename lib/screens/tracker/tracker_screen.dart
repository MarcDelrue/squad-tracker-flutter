import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:squad_tracker_flutter/providers/combined_stream_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/help_notification_service.dart';
import 'package:squad_tracker_flutter/models/user_with_location_session_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';
import 'package:squad_tracker_flutter/screens/tracker/widgets/scan_controls.dart';
import 'package:squad_tracker_flutter/screens/tracker/widgets/device_list.dart';
import 'package:squad_tracker_flutter/screens/tracker/widgets/connected_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
part 'tracker_screen_logic.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final TextEditingController _filterController =
      TextEditingController(text: "TTGO");

  // Background state for BLE sync (not shown in UI)
  String _myStatus = 'alive';
  int _myKills = 0;
  int _myDeaths = 0;
  String _myName = 'me';
  String _myColorHex = '000000'; // RRGGBB (no '#')
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  CombinedStreamService? _combinedService;
  StreamSubscription<List<UserWithLocationSession>?>? _combinedSub;
  StreamSubscription<List<Map<String, dynamic>>>? _scoreboardSub;
  StreamSubscription<Map<String, dynamic>>? _myStatsSub;
  StreamSubscription<Map<String, dynamic>?>? _gameMetaSub;
  StreamSubscription<List<dynamic>>? _locationsSub; // members location updates
  Map<String, Map<String, dynamic>> _scoreByUserId =
      <String, Map<String, dynamic>>{};
  // Track the most recent activity timestamp per user across location, sessions, and game stats
  final Map<String, DateTime> _lastActivityByUserId = <String, DateTime>{};
  int _lastProcessedMsgCount = 0;
  String? _lastConnectedRemoteId;
  int? _activeGameId;
  int _seqCounter = 0; // BLE snapshot sequence number
  int _ackOpId = 0; // last OP id received from device
  DateTime? _gameStartedAt;
  Timer? _gameTicker;
  int _gameElapsedSec = -1; // -1 means no game
  int _lastTimerSyncSec = -1;
  String _gameState = 'none'; // active | ended | none

  // No extra boilerplate needed: mixin now targets _TrackerScreenState directly

  @override
  void dispose() {
    _gameTicker?.cancel();
    _combinedSub?.cancel();
    _scoreboardSub?.cancel();
    _myStatsSub?.cancel();
    _gameMetaSub?.cancel();
    _locationsSub?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, ble, _) {
        _maybeStartDataSync(ble);
        final currentId = ble.connectedDevice?.remoteId.str;
        if (currentId != _lastConnectedRemoteId) {
          _lastConnectedRemoteId = currentId;
          _lastProcessedMsgCount = ble.receivedMessages.length;
          _seqCounter = 0; // reset sequence for new connection
          _ackOpId = 0; // reset ack id on new connection
          _sendSnapshotIfConnected(ble);
        }
        _processNewMessages(ble);
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.trackerBleTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: ble.isScanning
                    ? null
                    : () async {
                        await _ensurePermissions();
                        await ble.ensureAdapterOn();
                        await ble.startScan(
                            nameFilter: _filterController.text.trim().isEmpty
                                ? null
                                : _filterController.text.trim());
                      },
                tooltip: AppLocalizations.of(context)!.scan,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: ble.isScanning ? () => ble.stopScan() : null,
                tooltip: AppLocalizations.of(context)!.stopScanTooltip,
              ),
            ],
          ),
          body: Column(
            children: [
              ScanControls(
                filterController: _filterController,
                isScanning: ble.isScanning,
                onStartScan: (String? nameFilter) async {
                  await _ensurePermissions();
                  await ble.ensureAdapterOn();
                  await ble.startScan(nameFilter: nameFilter);
                },
                onStopScan: ble.isScanning ? () => ble.stopScan() : null,
              ),
              if (ble.connectedDevice == null)
                Expanded(
                  child: DeviceList(
                    devices: ble.devices,
                    isConnecting: ble.isConnecting,
                    onConnect: (d) async {
                      await ble.connect(d.device);
                    },
                  ),
                )
              else
                Expanded(
                  child: ConnectedPanel(
                    connectedDeviceName:
                        ble.connectedDevice!.platformName.isNotEmpty
                            ? ble.connectedDevice!.platformName
                            : ble.connectedDevice!.remoteId.str,
                    onDisconnect: () => ble.disconnect(),
                    onSync: () {
                      _sendSnapshotIfConnected(ble);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
