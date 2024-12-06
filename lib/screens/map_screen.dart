import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/widgets/draggable_bottom_sheet_for_map.dart';
import 'package:squad_tracker_flutter/widgets/map_fab.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';
import 'package:squad_tracker_flutter/widgets/user_status_buttons.dart';

class MapWithLocation extends StatefulWidget {
  const MapWithLocation({super.key});

  @override
  MapWithLocationState createState() => MapWithLocationState();
}

class MapWithLocationState extends State<MapWithLocation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameMapWidget(),
          DraggableBottomSheetForMap(
            content: UserStatusButtons(),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: MapFab(
              onFAB1Pressed: () {
                // Handle FAB 1 press
                print('FAB 1 pressed');
              },
              onFAB2Pressed: () {
                // Handle FAB 2 press
                print('FAB 2 pressed');
              },
              onFAB3Pressed: () {
                // Handle FAB 3 press
                print('FAB 3 pressed');
              },
            ),
          ),
        ],
      ),
    );
  }
}
