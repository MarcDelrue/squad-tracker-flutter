import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';

class ColorPickerModal extends StatefulWidget {
  final Color initialColor;
  final Function(Color) onColorSelected;

  const ColorPickerModal({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  ColorPickerModalState createState() => ColorPickerModalState();
}

class ColorPickerModalState extends State<ColorPickerModal> {
  late Color selectedColor;

  // Define the color options with names and hex values

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select a Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          itemCount: colorOptions.length,
          itemBuilder: (context, index) {
            final colorOption = colorOptions[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colorOption.color,
              ),
              title: Text(colorOption.name),
              trailing: selectedColor == colorOption.color
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() {
                  selectedColor = colorOption.color;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorSelected(selectedColor);
            Navigator.of(context).pop();
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
