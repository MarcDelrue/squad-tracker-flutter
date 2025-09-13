import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class ScanControls extends StatelessWidget {
  const ScanControls({
    super.key,
    required this.filterController,
    required this.isScanning,
    required this.onStartScan,
    required this.onStopScan,
  });

  final TextEditingController filterController;
  final bool isScanning;
  final Future<void> Function(String? nameFilter) onStartScan;
  final VoidCallback? onStopScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: filterController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.nameFilterHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isScanning
                ? null
                : () async {
                    final raw = filterController.text.trim();
                    final nameFilter = raw.isEmpty ? null : raw;
                    await onStartScan(nameFilter);
                  },
            child: Text(AppLocalizations.of(context)!.scan),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isScanning ? onStopScan : null,
            child: Text(AppLocalizations.of(context)!.stop),
          ),
        ],
      ),
    );
  }
}
