import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
  final List<DiscoveredDevice> _devices = <DiscoveredDevice>[];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _txNotifySub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic; // write
  BluetoothCharacteristic? _txCharacteristic; // notify

  final List<String> _receivedMessages = <String>[];
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isDisposed = false;

  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  List<String> get receivedMessages => List.unmodifiable(_receivedMessages);

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
      _txNotifySub = _txCharacteristic!.lastValueStream.listen((data) {
        if (_isDisposed || data.isEmpty) return;
        final String msg = utf8.decode(data, allowMalformed: true);
        _receivedMessages.add(msg);
        _notifyIfNotDisposed();
      });

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
    _notifyIfNotDisposed();
  }

  Future<void> sendString(String message) async {
    if (_rxCharacteristic == null) {
      throw Exception("Not connected");
    }
    final List<int> bytes = utf8.encode(message);
    await _rxCharacteristic!.write(bytes, withoutResponse: false);
  }

  Future<void> sendLines(List<String> lines) async {
    for (final line in lines) {
      await sendString(line);
      // Small delay helps some stacks process sequential writes
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
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
