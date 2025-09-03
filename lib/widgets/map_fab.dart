import 'package:flutter/material.dart';

class MapFab extends StatefulWidget {
  final VoidCallback onFAB1Pressed;
  final VoidCallback onFAB2Pressed;
  final VoidCallback onFAB3Pressed;
  final VoidCallback onFAB4Pressed;
  final int? selectedIndex; // External control of selected index

  const MapFab({
    super.key,
    required this.onFAB1Pressed,
    required this.onFAB2Pressed,
    required this.onFAB3Pressed,
    required this.onFAB4Pressed,
    this.selectedIndex,
  });

  @override
  _MapFabState createState() => _MapFabState();
}

class _MapFabState extends State<MapFab> {
  int _selectedIndex = -1; // Start with no button selected

  @override
  void didUpdateWidget(MapFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal state when external selectedIndex changes
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      setState(() {
        _selectedIndex = widget.selectedIndex ?? -1;
      });
    }
  }

  void _onFabPressed(int index, VoidCallback onPressed) {
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = -1;
      } else {
        _selectedIndex = index;
      }
    });
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FloatingActionButton.small(
          heroTag: 'fab1',
          onPressed: () => _onFabPressed(0, widget.onFAB1Pressed),
          backgroundColor: _selectedIndex == 0 ? Colors.green : Colors.white,
          child: Icon(
            Icons.group,
            color: _selectedIndex == 0 ? Colors.white : Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'fab2',
          onPressed: () => _onFabPressed(1, widget.onFAB2Pressed),
          backgroundColor: _selectedIndex == 1 ? Colors.green : Colors.white,
          child: Icon(
            Icons.manage_accounts,
            color: _selectedIndex == 1 ? Colors.white : Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'fab3',
          onPressed: () => _onFabPressed(2, widget.onFAB3Pressed),
          backgroundColor: _selectedIndex == 2 ? Colors.green : Colors.white,
          child: Icon(
            Icons.settings,
            color: _selectedIndex == 2 ? Colors.white : Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'fab4',
          onPressed: () => _onFabPressed(3, widget.onFAB4Pressed),
          backgroundColor: _selectedIndex == 3 ? Colors.green : Colors.white,
          child: Icon(
            Icons.leaderboard,
            color: _selectedIndex == 3 ? Colors.white : Colors.green,
          ),
        ),
      ],
    );
  }
}
