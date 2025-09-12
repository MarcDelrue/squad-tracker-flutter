import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:squad_tracker_flutter/providers/battle_logs_service.dart';
import 'package:squad_tracker_flutter/screens/login/login_form.dart';
import 'package:squad_tracker_flutter/widgets/navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter code sample for [NavigationBar].

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://uglsleerwgatuemmodfv.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnbHNsZWVyd2dhdHVlbW1vZGZ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTY0NDMsImV4cCI6MjA3MDkzMjQ0M30.v3UsXfqhzeqQCT-f4WZOjSDWKawdh6M1qh3wg3qaShM',
  );
  // Set Mapbox access token - it's now in AndroidManifest.xml
  MapboxOptions.setAccessToken(
      "sk.eyJ1IjoibWFyY2RlbHJ1ZSIsImEiOiJjbTNodW5sNmswZ3N0Mm1zNjk0aDVjYzM5In0.Mbv7uMcYheJ4bXHmzK707g");
  timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('fr_short', timeago.FrShortMessages());

  // Start battle logs service to listen continuously
  BattleLogsService().startListening();

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
    return ChangeNotifierProvider<BleService>(
      create: (_) => BleService(),
      child: MaterialApp(
        title: 'Supabase Flutter',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('fr'),
        ],
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale == null) {
            return const Locale('en');
          }
          final languageCode = locale.languageCode.toLowerCase();
          for (final supported in supportedLocales) {
            if (supported.languageCode.toLowerCase() == languageCode) {
              return supported;
            }
          }
          return const Locale('en');
        },
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
              return NavigationWidget(key: NavigationWidget.globalKey);
            }
          },
        ),
      ),
    );
  }
}
