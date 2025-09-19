import 'package:flutter/material.dart';
import 'dart:async';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/widgets/battle_logs.dart';
import 'package:squad_tracker_flutter/widgets/draggable_bottom_sheet_for_map.dart';
import 'package:squad_tracker_flutter/widgets/fly_to_user_fab.dart';
import 'package:squad_tracker_flutter/widgets/map_fab.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';
import 'package:squad_tracker_flutter/widgets/map_settings.dart';
import 'package:squad_tracker_flutter/widgets/squad_members_list.dart';
import 'package:squad_tracker_flutter/widgets/user_status_buttons.dart';
import 'package:squad_tracker_flutter/widgets/game/game_timer_chip.dart';

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
  bool _showBottomSheet = false; // Track if bottom sheet should be shown
  final _gameService = GameService();
  final _squadService = SquadService();
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  void _handleGeolocationToggle(bool isEnabled) {
    setState(() {
      _isGeolocationEnabled = isEnabled;
    });
  }

  @override
  void initState() {
    super.initState();
    bottomSheetContent = [
      SquadMembersList(
        onFlyToMember: () {
          setState(() {
            _showBottomSheet = false;
            // Reset FAB state when flying to member
            bottomSheetContentIndex = -1;
          });
        },
      ),
      const UserStatusButtons(),
      MapSettings(onGeolocationToggled: _handleGeolocationToggle),
      // Add more widgets as needed
    ];
    _startGameMetaStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameMapWidget(),
          GameTimerChip(startedAt: _startedAt, elapsed: _elapsed),
          MapControlButtons(
            isGeolocationDisabled: !_isGeolocationEnabled,
            showBattleLogs: _showBattleLogs,
            onBattleLogsPressed: () {
              setState(() {
                _showBattleLogs = !_showBattleLogs;
              });
            },
          ),
          if (_showBattleLogs) _buildBattleLogsPositioned(),
          // const EdgeIndicators(), // Edge indicators for off-screen members TODO: TO BE IMPROVED
          if (_showBottomSheet) _buildDraggableBottomSheet(),
          _buildFabPositioned(),
        ],
      ),
    );
  }

  void _startGameMetaStream() {
    final sid = _squadService.currentSquad?.id;
    if (sid == null) return;
    _gameService.streamActiveGameMetaBySquad(int.parse(sid)).listen((meta) {
      if (!mounted) return;
      if (meta == null) {
        setState(() {
          _startedAt = null;
          _elapsed = Duration.zero;
          _ticker?.cancel();
          _ticker = null;
        });
        return;
      }
      final s = meta['started_at']?.toString();
      final start = s != null ? DateTime.tryParse(s) : null;
      setState(() {
        _startedAt = start;
      });
      _ensureTicker();
    });
  }

  void _ensureTicker() {
    if (_startedAt == null) return;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt!);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
      top: 16 + MediaQuery.of(context).padding.top,
      left: 72, // Leave space for the vertical control buttons on the left
      right: 80, // Leave space for the FAB buttons on the right
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: BattleLogsWidget(
          onClose: () {
            setState(() {
              _showBattleLogs = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFabPositioned() {
    return Positioned(
      top: 16 + MediaQuery.of(context).padding.top,
      right: 16,
      child: MapFab(
        selectedIndex: _showBottomSheet ? bottomSheetContentIndex : -1,
        onFAB1Pressed: () => _onFabPressed(0),
        onFAB2Pressed: () => _onFabPressed(1),
        onFAB3Pressed: () => _onFabPressed(2),
      ),
    );
  }

  void _onFabPressed(int index) {
    setState(() {
      if (_showBottomSheet && bottomSheetContentIndex == index) {
        // If clicking the same button that's already active, hide the bottom sheet
        _showBottomSheet = false;
      } else {
        // Show bottom sheet and set the content index
        _showBottomSheet = true;
        bottomSheetContentIndex = index;
      }
    });
  }
}
