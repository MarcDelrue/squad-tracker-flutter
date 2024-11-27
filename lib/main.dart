import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:squad_tracker_flutter/screens/login/login_form.dart';
import 'package:squad_tracker_flutter/widgets/navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Flutter code sample for [NavigationBar].

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://gqpznsicyqvthcfpngms.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxcHpuc2ljeXF2dGhjZnBuZ21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjg4MzQxMjUsImV4cCI6MjA0NDQxMDEyNX0.j38omnpIUud1tbTP68Fpk09XwVPoBxp9UVgKupDj020',
  );
  String accessToken = const String.fromEnvironment("ACCESS_TOKEN");
  // Uncomment to work on map
  MapboxOptions.setAccessToken(accessToken);
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: supabase.auth.currentSession == null
          ? const LoginForm()
          : const NavigationWidget(),
    );
  }
}
