import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class ConnectedPanel extends StatelessWidget {
  const ConnectedPanel({
    super.key,
    required this.connectedDeviceName,
    required this.onDisconnect,
    required this.onSync,
  });

  final String connectedDeviceName;
  final VoidCallback onDisconnect;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.bluetooth_connected),
          title: Text(connectedDeviceName),
          trailing: ElevatedButton(
            onPressed: onDisconnect,
            child: Text(AppLocalizations.of(context)!.disconnect),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton(
                onPressed: onSync,
                child: Text(AppLocalizations.of(context)!.syncToDevice),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
