import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/notification_settings_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Consumer<NotificationSettingsService>(
          builder: (context, settingsService, child) {
            if (!settingsService.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            final settings = settingsService.settings;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Enable Notifications
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable Help Notifications'),
                    subtitle: const Text(
                        'Receive notifications when squad members need help'),
                    value: settings.enabled,
                    onChanged: (value) {
                      settingsService.setEnabled(value);
                    },
                    secondary: const Icon(Icons.notifications),
                  ),
                ),

                if (settings.enabled) ...[
                  const SizedBox(height: 16),

                  // Sound Settings
                  Card(
                    child: SwitchListTile(
                      title: const Text('Notification Sound'),
                      subtitle: const Text(
                          'Play sound when receiving help notifications'),
                      value: settings.soundEnabled,
                      onChanged: (value) {
                        settingsService.setSoundEnabled(value);
                      },
                      secondary: const Icon(Icons.volume_up),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timeout Settings
                  Card(
                    child: ListTile(
                      title: const Text('Auto-dismiss Timeout'),
                      subtitle: Text('${settings.timeoutSeconds} seconds'),
                      leading: const Icon(Icons.timer),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showTimeoutDialog(context, settingsService),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Distance Threshold
                  Card(
                    child: ListTile(
                      title: const Text('Distance Threshold'),
                      subtitle:
                          Text('${settings.distanceThresholdMeters.round()}m'),
                      leading: const Icon(Icons.location_on),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showDistanceDialog(context, settingsService),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Display Options
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('In-App Banner'),
                          subtitle: const Text(
                              'Show banner when app is in foreground'),
                          value: settings.showInAppBanner,
                          onChanged: (value) {
                            settingsService.setShowInAppBanner(value);
                          },
                          secondary: const Icon(Icons.notifications_active),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('System Notification'),
                          subtitle: const Text(
                              'Show notification when app is in background'),
                          value: settings.showSystemNotification,
                          onChanged: (value) {
                            settingsService.setShowSystemNotification(value);
                          },
                          secondary: const Icon(Icons.notifications_outlined),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Reset Button
                  Card(
                    child: ListTile(
                      title: const Text('Reset to Defaults'),
                      subtitle:
                          const Text('Restore all settings to default values'),
                      leading: const Icon(Icons.restore, color: Colors.orange),
                      onTap: () => _showResetDialog(context, settingsService),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showTimeoutDialog(
      BuildContext context, NotificationSettingsService settingsService) {
    final currentTimeout = settingsService.timeoutSeconds;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-dismiss Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How long should notifications stay visible?'),
            const SizedBox(height: 16),
            ...([10, 15, 20, 30, 45, 60].map((seconds) => RadioListTile<int>(
                  title: Text('$seconds seconds'),
                  value: seconds,
                  groupValue: currentTimeout,
                  onChanged: (value) {
                    if (value != null) {
                      settingsService.setTimeoutSeconds(value);
                      Navigator.of(context).pop();
                    }
                  },
                ))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDistanceDialog(
      BuildContext context, NotificationSettingsService settingsService) {
    final currentDistance = settingsService.distanceThresholdMeters;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Distance Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Only show notifications for help requests within this distance:'),
            const SizedBox(height: 16),
            ...([100, 250, 500, 1000, 2000, 5000]
                .map((meters) => RadioListTile<double>(
                      title: Text('${meters}m'),
                      value: meters.toDouble(),
                      groupValue: currentDistance,
                      onChanged: (value) {
                        if (value != null) {
                          settingsService.setDistanceThresholdMeters(value);
                          Navigator.of(context).pop();
                        }
                      },
                    ))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(
      BuildContext context, NotificationSettingsService settingsService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
            'Are you sure you want to reset all notification settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settingsService.resetToDefaults();
              Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
