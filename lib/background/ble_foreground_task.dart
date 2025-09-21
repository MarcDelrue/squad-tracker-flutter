import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String bleNotificationChannelId = 'squad_tracker_ble';
const int bleNotificationId = 42;

Future<void> initializeBleBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    bleNotificationChannelId,
    'Bluetooth Sync',
    description: 'Keeps Bluetooth connection active in background',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: bleServiceOnStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: bleNotificationChannelId,
      initialNotificationTitle: 'Squad Tracker',
      initialNotificationContent: 'Bluetooth sync in progress',
      foregroundServiceNotificationId: bleNotificationId,
      foregroundServiceTypes: [
        AndroidForegroundType.connectedDevice,
        AndroidForegroundType.dataSync
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: bleServiceOnStart,
    ),
  );
}

@pragma('vm:entry-point')
void bleServiceOnStart(ServiceInstance service) async {
  // No heavy logic; the presence of the foreground service keeps the process alive
  // If needed, we could post heartbeats or monitor state here later.
  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      // Ensure ongoing notification remains
      final plugin = FlutterLocalNotificationsPlugin();
      plugin.show(
        bleNotificationId,
        'Squad Tracker',
        'Bluetooth sync in progress',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            bleNotificationChannelId,
            'Bluetooth Sync',
            ongoing: true,
            importance: Importance.low,
            priority: Priority.low,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  service.on('stop').listen((event) {
    service.stopSelf();
  });
}

Future<void> startBleForegroundService() async {
  final service = FlutterBackgroundService();
  await service.startService();
}

Future<void> stopBleForegroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}
