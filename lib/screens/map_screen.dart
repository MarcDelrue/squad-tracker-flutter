import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/widgets/map_fab.dart';
import 'package:squad_tracker_flutter/widgets/map.dart';
import 'package:squad_tracker_flutter/widgets/draggable_bottom_sheet_content.dart';

class MapWithLocation extends StatefulWidget {
  const MapWithLocation({super.key});

  @override
  MapWithLocationState createState() => MapWithLocationState();
}

class MapWithLocationState extends State<MapWithLocation> {
  void _showDraggableBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
              child: DraggableBottomSheetContent(
                title: 'Draggable Bottom Sheet',
                content: ListView.builder(
                  controller: scrollController,
                  itemCount: 50,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('Item $index'),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameMapWidget(),
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
                _showDraggableBottomSheet(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
