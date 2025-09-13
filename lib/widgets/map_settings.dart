import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class MapSettings extends StatefulWidget {
  final Function(bool) onGeolocationToggled;
  const MapSettings({super.key, required this.onGeolocationToggled});

  @override
  MapSettingsState createState() => MapSettingsState();
}

class MapSettingsState extends State<MapSettings> {
  final mapUserLocationService = MapUserLocationService();
  bool _isGeolocationEnabled = true;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isGeolocationEnabled = !(mapUserLocationService.isPositionStreamPaused);
    });
  }

  void _toggleGeolocation() {
    setState(() {
      _isGeolocationEnabled = !_isGeolocationEnabled;
    });

    if (_isGeolocationEnabled) {
      mapUserLocationService.unpauseTrackingUserLocation();
    } else {
      mapUserLocationService.pauseTrackingUserLocation();
    }

    widget.onGeolocationToggled(_isGeolocationEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: _toggleGeolocation,
        child: Text(_isGeolocationEnabled
            ? AppLocalizations.of(context)!.disableGeolocation
            : AppLocalizations.of(context)!.enableGeolocation),
      ),
    );
  }
}
