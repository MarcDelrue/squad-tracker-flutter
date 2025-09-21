class NotificationSettings {
  final bool enabled;
  final bool soundEnabled;
  final int timeoutSeconds;
  final double distanceThresholdMeters;
  final bool showInAppBanner;
  final bool showSystemNotification;

  const NotificationSettings({
    this.enabled = true,
    this.soundEnabled = true,
    this.timeoutSeconds = 20,
    this.distanceThresholdMeters = 1000.0, // 1km default
    this.showInAppBanner = true,
    this.showSystemNotification = true,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? soundEnabled,
    int? timeoutSeconds,
    double? distanceThresholdMeters,
    bool? showInAppBanner,
    bool? showSystemNotification,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      distanceThresholdMeters:
          distanceThresholdMeters ?? this.distanceThresholdMeters,
      showInAppBanner: showInAppBanner ?? this.showInAppBanner,
      showSystemNotification:
          showSystemNotification ?? this.showSystemNotification,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'soundEnabled': soundEnabled,
      'timeoutSeconds': timeoutSeconds,
      'distanceThresholdMeters': distanceThresholdMeters,
      'showInAppBanner': showInAppBanner,
      'showSystemNotification': showSystemNotification,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      soundEnabled: json['soundEnabled'] ?? true,
      timeoutSeconds: json['timeoutSeconds'] ?? 20,
      distanceThresholdMeters:
          (json['distanceThresholdMeters'] ?? 1000.0).toDouble(),
      showInAppBanner: json['showInAppBanner'] ?? true,
      showSystemNotification: json['showSystemNotification'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.enabled == enabled &&
        other.soundEnabled == soundEnabled &&
        other.timeoutSeconds == timeoutSeconds &&
        other.distanceThresholdMeters == distanceThresholdMeters &&
        other.showInAppBanner == showInAppBanner &&
        other.showSystemNotification == showSystemNotification;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      soundEnabled,
      timeoutSeconds,
      distanceThresholdMeters,
      showInAppBanner,
      showSystemNotification,
    );
  }
}
