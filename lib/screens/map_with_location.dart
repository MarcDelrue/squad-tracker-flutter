import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/widgets/battle_logs.dart';
import 'package:squad_tracker_flutter/widgets/draggable_bottom_sheet_for_map.dart';
import 'package:squad_tracker_flutter/widgets/fly_to_user_fab.dart';
import 'package:squad_tracker_flutter/widgets/map_fab.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';
import 'package:squad_tracker_flutter/widgets/map_settings.dart';
import 'package:squad_tracker_flutter/widgets/user_status_buttons.dart';

class MapWithLocation extends StatefulWidget {
  const MapWithLocation({super.key});

  @override
  MapWithLocationState createState() => MapWithLocationState();
}

class MapWithLocationState extends State<MapWithLocation> {
  int bottomSheetContentIndex = 0;
  late final List<Widget> bottomSheetContent;
  bool _isGeolocationEnabled = true;
  bool _showBattleLogs = false;
  void _handleGeolocationToggle(bool isEnabled) {
    setState(() {
      _isGeolocationEnabled = isEnabled;
    });
  }

  @override
  void initState() {
    super.initState();
    bottomSheetContent = [
      // MembersInGameList(
      //   combinedStreamService: combinedStreamService,
      // ),
      const UserStatusButtons(),
      const Text('Salut'),
      MapSettings(onGeolocationToggled: _handleGeolocationToggle),
      // Add more widgets as needed
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameMapWidget(),
          MapControlButtons(
            isGeolocationDisabled: !_isGeolocationEnabled,
            onBattleLogsPressed: () {
              setState(() {
                _showBattleLogs = !_showBattleLogs;
              });
            },
          ),
          if (_showBattleLogs) _buildBattleLogsPositioned(),
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

  Widget _buildBattleLogsPositioned() {
    return Positioned(
      top: 80 + MediaQuery.of(context).padding.top,
      left: 16,
      right: 80, // Leave space for the FAB buttons on the right
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: const BattleLogsWidget(),
      ),
    );
  }

  Widget _buildFabPositioned() {
    return Positioned(
      top: 16 + MediaQuery.of(context).padding.top,
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
