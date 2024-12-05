import 'package:flutter/material.dart';

class DraggableBottomSheetContent extends StatelessWidget {
  final String title;
  final Widget content;

  const DraggableBottomSheetContent(
      {super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(),
        Expanded(child: content),
      ],
    );
  }
}
