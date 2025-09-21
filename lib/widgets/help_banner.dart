import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/help_notification_service.dart';

class HelpBanner extends StatelessWidget {
  const HelpBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HelpNotificationService>(
      builder: (context, helpService, child) {
        if (!helpService.hasActiveBanners) {
          return const SizedBox.shrink();
        }

        final bannerId = helpService.firstActiveBannerId;
        if (bannerId == null) return const SizedBox.shrink();

        // For now, we'll show a simple banner. In a real implementation,
        // we'd need to store the full HelpRequest data to display details
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Help Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Someone needs help!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      helpService.handleResponse(bannerId, HelpResponse.ignore);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                    child: const Text('Ignore'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      helpService.handleResponse(bannerId, HelpResponse.accept);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade600,
                    ),
                    child: const Text('Go Help'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
