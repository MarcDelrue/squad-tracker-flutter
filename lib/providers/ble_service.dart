import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:squad_tracker_flutter/background/ble_foreground_task.dart';

/// BLE UART (Nordic UART Service) UUIDs
class BleUartUuids {
  static final Guid service = Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  // Phone -> Device
  static final Guid rxCharacteristic =
      Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
  // Device -> Phone
  static final Guid txCharacteristic =
      Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
}

class DiscoveredDevice {
  final BluetoothDevice device;
  final String name;
  final int rssi;

  DiscoveredDevice({
    required this.device,
    required this.name,
    required this.rssi,
  });
}

class BleService with ChangeNotifier {
  // Optional global handle for services that cannot use Provider context
  static BleService? _global;
  static void setGlobal(BleService service) {
    _global = service;
  }

  static BleService? get global => _global;
  final List<DiscoveredDevice> _devices = <DiscoveredDevice>[];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _txNotifySub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;
  SharedPreferences? _prefs;
  bool _autoReconnectAttempted = false;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic; // write
  BluetoothCharacteristic? _txCharacteristic; // notify

  final List<String> _receivedMessages = <String>[];
  String _rxLineBuffer = '';
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isDisposed = false;

  // Store the last built snapshot lines from the UI so we can
  // continue sending them periodically while in background.
  List<String> _lastSnapshotLines = <String>[];
  Timer? _snapshotTimer;
  static const Duration _snapshotInterval = Duration(seconds: 5);
  int _bgSeq = 0; // background sequence tracker derived from last snapshot

  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  List<String> get receivedMessages => List.unmodifiable(_receivedMessages);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String _keyForUser(String userId) => 'ble_last_device_$userId';

  Future<void> _saveLastDeviceIdForUser(String userId, String deviceId) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyForUser(userId), deviceId);
  }

  Future<String?> _getLastDeviceIdForUser(String userId) async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyForUser(userId));
  }

  /// Try to reconnect to the last device used by this user.
  ///
  /// Best-effort: scans briefly for the UART service and connects if the
  /// saved remoteId is discovered. No UI feedback; safe to call during startup.
  Future<void> tryAutoReconnect(String userId,
      {Duration timeout = const Duration(seconds: 12)}) async {
    if (_isDisposed) return;
    if (_connectedDevice != null || _isConnecting) return;
    if (_autoReconnectAttempted) return;
    _autoReconnectAttempted = true;

    final String? lastId = await _getLastDeviceIdForUser(userId);
    if (lastId == null || lastId.isEmpty) return;

    // Request permissions quietly; skip if not granted
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final bool hasBlePerms =
        (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
            (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
    if (!hasBlePerms) {
      return;
    }

    await ensureAdapterOn();

    final Completer<void> done = Completer<void>();
    StreamSubscription<List<ScanResult>>? sub;
    sub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) async {
      for (final ScanResult r in results) {
        if (r.device.remoteId.str == lastId) {
          try {
            await FlutterBluePlus.stopScan();
          } catch (_) {}
          await sub?.cancel();
          try {
            await connect(r.device);
          } catch (_) {
            // ignore failures silently in auto path
          } finally {
            if (!done.isCompleted) done.complete();
          }
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan();
    } catch (_) {
      await sub.cancel();
      return;
    }

    await Future.any(
        <Future<void>>[done.future, Future<void>.delayed(timeout)]);
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await sub.cancel();
  }

  Future<void> ensureAdapterOn() async {
    // Best-effort: some platforms support toggling, others not; caller should handle failures.
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      // On Android 13+, the system dialog may appear when scanning/connect is attempted.
      // We don't programmatically enable Bluetooth here.
    }
  }

  Future<void> startScan({String? nameFilter}) async {
    if (_isDisposed) return;
    if (_isScanning) return;
    _devices.clear();
    _isScanning = true;
    _notifyIfNotDisposed();

    // Using scan results stream so we can update incrementally.
    _scanSub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      for (final ScanResult r in results) {
        final String advName = r.advertisementData.advName;
        final String deviceName = r.device.platformName;
        final String name = advName.isNotEmpty ? advName : deviceName;
        final bool nameMatches = nameFilter == null
            ? true
            : (name.toLowerCase().contains(nameFilter.toLowerCase()));
        if (!nameMatches) continue;
        final bool already =
            _devices.any((d) => d.device.remoteId == r.device.remoteId);
        if (!already) {
          _devices.add(
              DiscoveredDevice(device: r.device, name: name, rssi: r.rssi));
        }
      }
      _devices.sort((a, b) => b.rssi.compareTo(a.rssi));
      _notifyIfNotDisposed();
    });

    if (_isDisposed) return;
    await FlutterBluePlus.startScan(withServices: <Guid>[BleUartUuids.service]);
  }

  Future<void> stopScan() async {
    if (_isDisposed) return;
    if (!_isScanning) return;
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _isScanning = false;
    _notifyIfNotDisposed();
  }

  Future<void> connect(BluetoothDevice device) async {
    if (_isDisposed) return;
    if (_connectedDevice?.remoteId == device.remoteId) return;
    _isConnecting = true;
    _notifyIfNotDisposed();
    try {
      await stopScan();
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Best-effort: request a higher MTU to reduce chunk count (Android only)
      try {
        await device.requestMtu(185);
      } catch (_) {}

      final List<BluetoothService> services = await device.discoverServices();
      BluetoothService? uart;
      for (final s in services) {
        if (s.uuid == BleUartUuids.service) {
          uart = s;
          break;
        }
      }

      if (uart == null) {
        throw Exception("UART service not found on device");
      }

      for (final BluetoothCharacteristic c in uart.characteristics) {
        if (c.uuid == BleUartUuids.rxCharacteristic) {
          _rxCharacteristic = c;
        } else if (c.uuid == BleUartUuids.txCharacteristic) {
          _txCharacteristic = c;
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        throw Exception("UART characteristics not found");
      }

      if (_isDisposed) return;
      await _txCharacteristic!.setNotifyValue(true);
      await _txNotifySub?.cancel();
      _txNotifySub = _txCharacteristic!.onValueReceived.listen((data) {
        if (_isDisposed || data.isEmpty) return;
        final String chunk = utf8.decode(data, allowMalformed: true);
        _rxLineBuffer += chunk;
        int idx;
        // Emit complete newline-delimited lines
        while ((idx = _rxLineBuffer.indexOf('\n')) >= 0) {
          final String line = _rxLineBuffer.substring(0, idx).trim();
          _rxLineBuffer = _rxLineBuffer.substring(idx + 1);
          if (line.isNotEmpty) {
            _receivedMessages.add(line);
          }
        }
        _notifyIfNotDisposed();
      });

      // Keep device awake while a BLE device is connected to ensure
      // continuous communication even when the screen would otherwise sleep.
      try {
        await WakelockPlus.enable();
      } catch (_) {}

      // Start a minimal foreground service on Android to keep BLE alive when
      // the app is backgrounded. No-op on iOS.
      try {
        await startBleForegroundService();
      } catch (_) {}

      // Start periodic snapshot sender so updates continue while app is backgrounded
      _startSnapshotTimer();

      // Persist last connected device for this user
      final String? uid = UserService().currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        try {
          await _saveLastDeviceIdForUser(uid, device.remoteId.str);
        } catch (_) {}
      }

      // Listen for unexpected disconnections (e.g., device powered off)
      await _deviceStateSub?.cancel();
      _deviceStateSub = device.connectionState.listen((state) async {
        if (_isDisposed) return;
        if (state == BluetoothConnectionState.disconnected) {
          await _txNotifySub?.cancel();
          _txNotifySub = null;
          _rxCharacteristic = null;
          _txCharacteristic = null;
          _connectedDevice = null;
          try {
            await WakelockPlus.disable();
          } catch (_) {}
          try {
            await stopBleForegroundService();
          } catch (_) {}
          _snapshotTimer?.cancel();
          _snapshotTimer = null;
          _notifyIfNotDisposed();
        }
      });
    } finally {
      if (!_isDisposed) {
        _isConnecting = false;
        _notifyIfNotDisposed();
      }
    }
  }

  Future<void> disconnect() async {
    if (_isDisposed) return;
    await _deviceStateSub?.cancel();
    _deviceStateSub = null;
    await _txNotifySub?.cancel();
    _txNotifySub = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
    _connectedDevice = null;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await stopBleForegroundService();
    } catch (_) {}
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _notifyIfNotDisposed();
  }

  Future<void> sendString(String message) async {
    if (_rxCharacteristic == null) {
      throw Exception("Not connected");
    }
    final String withNewline =
        message.endsWith('\n') ? message : ('$message\n');
    final List<int> bytes = utf8.encode(withNewline);
    // Prefer write without response for throughput; fall back if not supported
    try {
      // Prefer reliability in background: use write WITH response
      await _rxCharacteristic!.write(bytes, withoutResponse: false);
    } catch (_) {
      // Best-effort fallback
      await _rxCharacteristic!.write(bytes, withoutResponse: true);
    }
  }

  Future<void> sendLines(List<String> lines) async {
    if (_rxCharacteristic == null) {
      throw Exception("Not connected");
    }
    _markSeqSentIfPresent(lines);
    // Join lines into larger chunks separated by \n, then split by an MTU-safe size
    // Assume payload around 180 bytes per write after ATT overhead when MTU=185.
    const int maxChunkBytes = 180;
    String buffer = '';
    for (final line in lines) {
      final String withNl = line.endsWith('\n') ? line : ('$line\n');
      final int prospective =
          utf8.encode(buffer).length + utf8.encode(withNl).length;
      if (prospective > maxChunkBytes && buffer.isNotEmpty) {
        await _writeChunk(buffer);
        buffer = withNl;
      } else {
        buffer += withNl;
      }
    }
    if (buffer.isNotEmpty) {
      await _writeChunk(buffer);
    }
  }

  Future<void> _writeChunk(String data) async {
    final List<int> bytes = utf8.encode(data);
    try {
      await _rxCharacteristic!.write(bytes, withoutResponse: false);
    } catch (_) {
      await _rxCharacteristic!.write(bytes, withoutResponse: true);
    }
  }

  // Public API for UI to provide latest snapshot lines.
  // Sends immediately if connected, and stores for periodic resends.
  Future<void> updateSnapshot(List<String> lines) async {
    _lastSnapshotLines = List<String>.from(lines);
    // derive starting bg seq from provided lines if present
    try {
      final seqLine = _lastSnapshotLines.firstWhere((l) => l.startsWith('SEQ '),
          orElse: () => '');
      if (seqLine.isNotEmpty) {
        final v = int.tryParse(seqLine.substring(4));
        if (v != null) _bgSeq = v;
      }
    } catch (_) {}
    if (_rxCharacteristic != null) {
      try {
        await sendLines(lines);
      } catch (_) {}
    }
  }

  void _startSnapshotTimer() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(_snapshotInterval, (_) async {
      if (_rxCharacteristic == null) return;
      if (_lastSnapshotLines.isEmpty) return;
      try {
        // Bump SEQ so device applies snapshot
        final List<String> copy = List<String>.from(_lastSnapshotLines);
        bool replaced = false;
        for (int i = 0; i < copy.length; i++) {
          if (copy[i].startsWith('SEQ ')) {
            _bgSeq = _bgSeq + 1;
            copy[i] = 'SEQ $_bgSeq';
            replaced = true;
            break;
          }
        }
        if (!replaced) {
          _bgSeq = _bgSeq + 1;
          copy.add('SEQ $_bgSeq');
        }
        if (!copy.isNotEmpty || copy.last != 'EOT') {
          // ensure EOT at end
          copy.add('EOT');
        }
        await sendLines(copy);
      } catch (_) {}
    });
  }

  // --- Simple RTT tracking by SEQ ---
  final Map<int, DateTime> _seqSendTimes = <int, DateTime>{};
  void _markSeqSentIfPresent(List<String> lines) {
    try {
      final seqLine =
          lines.lastWhere((l) => l.startsWith('SEQ '), orElse: () => '');
      if (seqLine.isEmpty) return;
      final v = int.tryParse(seqLine.substring(4));
      if (v == null) return;
      _seqSendTimes[v] = DateTime.now();
    } catch (_) {}
  }

  void _notifyIfNotDisposed() {
    if (!_isDisposed) {
      try {
        // ignore: invalid_use_of_protected_member
        notifyListeners();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Cancel subscriptions first to prevent late callbacks
    _deviceStateSub?.cancel();
    _deviceStateSub = null;
    _txNotifySub?.cancel();
    _txNotifySub = null;
    _scanSub?.cancel();
    _scanSub = null;

    // Best-effort cleanup without notifying listeners
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      _connectedDevice?.disconnect();
    } catch (_) {}

    super.dispose();
  }
}
