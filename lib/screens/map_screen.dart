import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';

class MapWithLocation extends StatefulWidget {
  const MapWithLocation({super.key});

  @override
  MapWithLocationState createState() => MapWithLocationState();
}

class MapWithLocationState extends State<MapWithLocation> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GameMapWidget(),
    );
  }
}
