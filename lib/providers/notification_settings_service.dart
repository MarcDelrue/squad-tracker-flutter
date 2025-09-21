import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_tracker_flutter/models/notification_settings.dart';

class NotificationSettingsService with ChangeNotifier {
  static const String _key = 'notification_settings';

  NotificationSettings _settings = const NotificationSettings();
  bool _initialized = false;

  NotificationSettings get settings => _settings;
  bool get isInitialized => _initialized;

  // Convenience getters
  bool get enabled => _settings.enabled;
  bool get soundEnabled => _settings.soundEnabled;
  int get timeoutSeconds => _settings.timeoutSeconds;
  double get distanceThresholdMeters => _settings.distanceThresholdMeters;
  bool get showInAppBanner => _settings.showInAppBanner;
  bool get showSystemNotification => _settings.showSystemNotification;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_key);

      if (settingsJson != null) {
        // Parse JSON string to Map
        final Map<String, dynamic> settingsMap = Map<String, dynamic>.from(
            Uri.splitQueryString(settingsJson)
                .map((key, value) => MapEntry(key, _parseValue(value))));
        _settings = NotificationSettings.fromJson(settingsMap);
      } else {
        // Use default settings
        _settings = const NotificationSettings();
        await _saveSettings();
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      _settings = const NotificationSettings();
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    await updateSettings(_settings.copyWith(enabled: enabled));
  }

  Future<void> setSoundEnabled(bool soundEnabled) async {
    await updateSettings(_settings.copyWith(soundEnabled: soundEnabled));
  }

  Future<void> setTimeoutSeconds(int timeoutSeconds) async {
    await updateSettings(_settings.copyWith(timeoutSeconds: timeoutSeconds));
  }

  Future<void> setDistanceThresholdMeters(
      double distanceThresholdMeters) async {
    await updateSettings(
        _settings.copyWith(distanceThresholdMeters: distanceThresholdMeters));
  }

  Future<void> setShowInAppBanner(bool showInAppBanner) async {
    await updateSettings(_settings.copyWith(showInAppBanner: showInAppBanner));
  }

  Future<void> setShowSystemNotification(bool showSystemNotification) async {
    await updateSettings(
        _settings.copyWith(showSystemNotification: showSystemNotification));
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = _settings
          .toJson()
          .map((key, value) => MapEntry(key, value.toString()))
          .entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      await prefs.setString(_key, settingsJson);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  dynamic _parseValue(String value) {
    // Try to parse as different types
    if (value == 'true') return true;
    if (value == 'false') return false;
    if (value.contains('.')) {
      return double.tryParse(value) ?? value;
    }
    return int.tryParse(value) ?? value;
  }

  Future<void> resetToDefaults() async {
    await updateSettings(const NotificationSettings());
  }
}
