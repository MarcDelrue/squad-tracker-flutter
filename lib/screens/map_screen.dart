import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/widgets/draggable_bottom_sheet_for_map.dart';
import 'package:squad_tracker_flutter/widgets/map_fab.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';
import 'package:squad_tracker_flutter/widgets/member_in_game_row.dart';
import 'package:squad_tracker_flutter/widgets/user_status_buttons.dart';

class MapWithLocation extends StatefulWidget {
  const MapWithLocation({super.key});

  @override
  MapWithLocationState createState() => MapWithLocationState();
}

class MapWithLocationState extends State<MapWithLocation> {
  var bottomSheetContentIndex = 0;

  static List<Widget> bottomSheetContent = [
    const MemberInGameRow(),
    UserStatusButtons(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameMapWidget(),
          DraggableBottomSheetForMap(
            content: bottomSheetContent[bottomSheetContentIndex],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: MapFab(
              onFAB1Pressed: () {
                setState(() {
                  bottomSheetContentIndex = 0;
                });
              },
              onFAB2Pressed: () {
                setState(() {
                  bottomSheetContentIndex = 1;
                });
              },
              onFAB3Pressed: () {
                setState(() {
                  bottomSheetContentIndex = 2;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
