import 'package:flutter/material.dart';

class ColorOption {
  final String name;
  final Color color;

  ColorOption(this.name, this.color);
}

String colorToHex(Color color) {
  return '#${color.r.toInt().toRadixString(16).padLeft(2, '0')}${color.g.toInt().toRadixString(16).padLeft(2, '0')}${color.b.toInt().toRadixString(16).padLeft(2, '0')}';
}

// Convert a hex string to a Color
Color hexToColor(String hex) {
  return Color(
      int.parse(hex.replaceFirst('#', '0xFF'))); // Adds full opacity if missing
}

final List<ColorOption> colorOptions = [
  ColorOption("Navy", const Color(0xFF000080)),
  ColorOption("Dark Green", const Color(0xFF008000)),
  ColorOption("Dark Cyan", const Color(0xFF008080)),
  ColorOption("Maroon", const Color(0xFF800000)),
  ColorOption("Purple", const Color(0xFF800080)),
  ColorOption("Olive", const Color(0xFF808000)),
  ColorOption("Light Grey", const Color(0xFFD3D3D3)),
  ColorOption("Dark Grey", const Color(0xFF808080)),
  ColorOption("Blue", const Color(0xFF0000FF)),
  ColorOption("Green", const Color(0xFF00FF00)),
  ColorOption("Cyan", const Color(0xFF00FFFF)),
  ColorOption("Red", const Color(0xFFFF0000)),
  ColorOption("Magenta", const Color(0xFFFF00FF)),
  ColorOption("Yellow", const Color(0xFFFFFF00)),
  ColorOption("White", const Color(0xFFFFFFFF)),
  ColorOption("Orange", const Color(0xFFFFB400)),
  ColorOption("Green Yellow", const Color(0xFFB4FF00)),
  ColorOption("Pink", const Color(0xFFFFC0CB)),
  ColorOption("Brown", const Color(0xFF964B00)),
  ColorOption("Gold", const Color(0xFFFFD700)),
  ColorOption("Silver", const Color(0xFFC0C0C0)),
  ColorOption("Sky Blue", const Color(0xFF87CEEB)),
  ColorOption("Violet", const Color(0xFFB42EE2)),
];
