import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:squad_tracker_flutter/screens/login/login_form.dart';
import 'package:squad_tracker_flutter/widgets/navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Flutter code sample for [NavigationBar].

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://uglsleerwgatuemmodfv.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnbHNsZWVyd2dhdHVlbW1vZGZ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTY0NDMsImV4cCI6MjA3MDkzMjQ0M30.v3UsXfqhzeqQCT-f4WZOjSDWKawdh6M1qh3wg3qaShM',
  );
  String mapboxToken = const String.fromEnvironment("MAPBOX_TOKEN");
  // Uncomment to work on map
  MapboxOptions.setAccessToken(mapboxToken);
  timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _checkSession() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final expiresAt = session.expiresAt ?? 0;
    final isExpiringSoon =
        expiresAt - now < 60; // Refresh if expiring within 60 seconds

    if (isExpiringSoon) {
      try {
        await supabase.auth.refreshSession();
        return true;
      } catch (e) {
        debugPrint('Failed to refresh token: $e');
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Flutter',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.green,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green,
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _checkSession(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!) {
            return const LoginForm();
          } else {
            return const NavigationWidget();
          }
        },
      ),
    );
  }
}
