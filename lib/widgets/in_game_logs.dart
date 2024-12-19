import 'package:flutter/material.dart';

class Notification {
  final String message;
  final DateTime time;

  Notification(this.message, this.time);
}

class InGameLogsWidget extends StatelessWidget {
  final Notification notification;
  final Duration displayDuration;

  const InGameLogsWidget(
      {super.key,
      required this.notification,
      this.displayDuration = const Duration(seconds: 5)});

  @override
  Widget build(BuildContext context) {
    final timeSinceCreation = DateTime.now().difference(notification.time);

    // Calculate opacity based on the age of the notification
    double opacity = 1.0 -
        (timeSinceCreation.inMilliseconds / displayDuration.inMilliseconds);
    if (opacity < 0) opacity = 0;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0),
        padding: EdgeInsets.all(8.0),
        color: Colors.black54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              notification.message,
              style: TextStyle(color: Colors.white),
            ),
            Text(
              "${timeSinceCreation.inSeconds}s ago",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class InGameLogsOverlay extends StatefulWidget {
  final List<Notification> notifications;

  const InGameLogsOverlay({super.key, required this.notifications});

  @override
  InGameLogsOverlayState createState() => InGameLogsOverlayState();
}

class InGameLogsOverlayState extends State<InGameLogsOverlay> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        children: widget.notifications.map((notification) {
          return InGameLogsWidget(notification: notification);
        }).toList(),
      ),
    );
  }
}
