import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/help_notification_service.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class HelpBanner extends StatelessWidget {
  const HelpBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HelpNotificationService>(
      builder: (context, helpService, child) {
        if (!helpService.hasActiveBanners) {
          return const SizedBox.shrink();
        }

        final request = helpService.firstActiveBanner;
        if (request == null) return const SizedBox.shrink();

        final isMedic = request.status == UserSquadSessionStatus.medic;
        final statusText = isMedic ? 'medic' : 'help';
        final statusIcon =
            isMedic ? Icons.medical_services : Icons.warning_amber_rounded;
        final statusColor =
            isMedic ? Colors.red.shade600 : Colors.orange.shade600;

        // Build distance and direction info
        final distanceText = request.distanceMeters != null
            ? '${request.distanceMeters!.round()}m'
            : null;
        final directionText = request.directionDegrees != null
            ? _bearingToCardinal(request.directionDegrees!)
            : null;
        final locationInfo =
            [distanceText, directionText].where((s) => s != null).join(' • ');

        // Build K/D info
        final kdText = '${request.requesterKills}/${request.requesterDeaths}';

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${request.requesterName} needs $statusText',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (locationInfo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            locationInfo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'K/D: $kdText',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (request.requesterColorHex != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(request
                                      .requesterColorHex!
                                      .replaceFirst('#', '0xff'))),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 1),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        helpService.handleResponse(
                            request.requestId, HelpResponse.ignore);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Ignore'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        helpService.handleResponse(
                            request.requestId, HelpResponse.accept);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: statusColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Go Help'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _bearingToCardinal(double degrees) {
    const List<String> dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((degrees % 360) / 45).round() % 8;
    return dirs[idx];
  }
}
