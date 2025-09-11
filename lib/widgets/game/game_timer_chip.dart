import 'package:flutter/material.dart';

class GameTimerChip extends StatelessWidget {
  final DateTime? startedAt;
  final Duration elapsed;

  const GameTimerChip(
      {super.key, required this.startedAt, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    if (startedAt == null) return const SizedBox.shrink();
    return Positioned(
      top: 16 + MediaQuery.of(context).padding.top,
      right: 88,
      child: Chip(
        label: Text(_formatElapsed(elapsed)),
        backgroundColor: Colors.black,
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
