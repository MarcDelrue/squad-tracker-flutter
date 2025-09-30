import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';

class DeviceList extends StatelessWidget {
  const DeviceList({
    super.key,
    required this.devices,
    required this.isConnecting,
    required this.onConnect,
  });

  final List<DiscoveredDevice> devices;
  final bool isConnecting;
  final Future<void> Function(DiscoveredDevice device) onConnect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final d = devices[index];
        final title = d.name.isNotEmpty ? d.name : d.device.remoteId.str;
        return ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(title),
          subtitle: Text('RSSI ${d.rssi}'),
          trailing: isConnecting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : ElevatedButton(
                  onPressed: () async {
                    await onConnect(d);
                  },
                  child: Text(AppLocalizations.of(context)!.connect),
                ),
        );
      },
    );
  }
}
