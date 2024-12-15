import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/widgets/draggable_bottom_sheet_for_map.dart';
import 'package:squad_tracker_flutter/widgets/fly_to_user_fab.dart';
import 'package:squad_tracker_flutter/widgets/map_fab.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';
import 'package:squad_tracker_flutter/widgets/members_in_game_list.dart';
import 'package:squad_tracker_flutter/widgets/user_status_buttons.dart';

class MapWithLocation extends StatefulWidget {
  const MapWithLocation({super.key});

  @override
  MapWithLocationState createState() => MapWithLocationState();
}

class MapWithLocationState extends State<MapWithLocation> {
  int bottomSheetContentIndex = 0;

  final userSquadLocationService = UserSquadLocationService();

  static final List<Widget> bottomSheetContent = [
    MembersInGameList(),
    const UserStatusButtons(),
    // Add more widgets as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameMapWidget(),
          const FlyToUserFab(),
          _buildDraggableBottomSheet(),
          _buildFabPositioned(),
        ],
      ),
    );
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableBottomSheetForMap(
      content: IndexedStack(
        index: bottomSheetContentIndex,
        children: bottomSheetContent,
      ),
    );
  }

  Widget _buildFabPositioned() {
    return Positioned(
      top: 16,
      right: 16,
      child: MapFab(
        onFAB1Pressed: () => _onFabPressed(0),
        onFAB2Pressed: () => _onFabPressed(1),
        onFAB3Pressed: () => _onFabPressed(2),
      ),
    );
  }

  void _onFabPressed(int index) {
    setState(() {
      bottomSheetContentIndex = index;
    });
  }
}
