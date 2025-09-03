import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _filterController =
      TextEditingController(text: "TTGO");

  @override
  void dispose() {
    _messageController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    // Just surface denied in UI through button enable/disable; no extra handling here.
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bluetooth permissions permanently denied')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BleService>(
      create: (_) => BleService(),
      child: Consumer<BleService>(
        builder: (context, ble, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tracker (BLE)'),
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
                  tooltip: 'Scan',
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: ble.isScanning ? () => ble.stopScan() : null,
                  tooltip: 'Stop scan',
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _filterController,
                          decoration: const InputDecoration(
                            labelText: 'Name filter (e.g. TTGO)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: ble.isScanning
                            ? null
                            : () async {
                                await _ensurePermissions();
                                await ble.ensureAdapterOn();
                                await ble.startScan(
                                    nameFilter:
                                        _filterController.text.trim().isEmpty
                                            ? null
                                            : _filterController.text.trim());
                              },
                        child: const Text('Scan'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: ble.isScanning ? () => ble.stopScan() : null,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ),
                if (ble.connectedDevice == null)
                  Expanded(
                    child: ListView.separated(
                      itemCount: ble.devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = ble.devices[index];
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(d.name.isNotEmpty
                              ? d.name
                              : d.device.remoteId.str),
                          subtitle: Text('RSSI ${d.rssi}'),
                          trailing: ble.isConnecting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: () async {
                                    await ble.connect(d.device);
                                  },
                                  child: const Text('Connect'),
                                ),
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.bluetooth_connected),
                          title: Text(
                              ble.connectedDevice!.platformName.isNotEmpty
                                  ? ble.connectedDevice!.platformName
                                  : ble.connectedDevice!.remoteId.str),
                          trailing: ElevatedButton(
                            onPressed: () => ble.disconnect(),
                            child: const Text('Disconnect'),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Message to TTGO',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final text = _messageController.text.trim();
                                  if (text.isNotEmpty) {
                                    await ble.sendString(text);
                                    _messageController.clear();
                                  }
                                },
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('Received messages'),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: ble.receivedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = ble.receivedMessages[index];
                              return ListTile(
                                dense: true,
                                title: Text(msg),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
