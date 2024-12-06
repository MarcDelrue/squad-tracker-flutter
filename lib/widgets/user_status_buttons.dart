import 'package:flutter/material.dart';

class UserStatusButtons extends StatefulWidget {
  @override
  _UserStatusButtonsState createState() => _UserStatusButtonsState();
}

class _UserStatusButtonsState extends State<UserStatusButtons> {
  List<bool> _isSelected = [false, false, false];

  Widget _buildToggleButton(
      String text, String toggledText, Color color, int index) {
    return ElevatedButton(
      style: _isSelected[index]
          ? ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: color,
              side: BorderSide(color: color),
            )
          : OutlinedButton.styleFrom(
              foregroundColor: color,
              backgroundColor: Colors.transparent,
              side: BorderSide(color: color),
            ),
      onPressed: () {
        setState(() {
          _isSelected = [
            index == 0 ? !_isSelected[0] : false,
            index == 1 ? !_isSelected[1] : false,
            index == 2 ? !_isSelected[2] : false
          ];
        });
      },
      child: _isSelected[index] ? Text(toggledText) : Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleButton('Died', 'Dead', Colors.grey, 0),
        const SizedBox(width: 10),
        _buildToggleButton('Send help', 'Help asked', Colors.red, 1),
        const SizedBox(width: 10),
        _buildToggleButton('Send medic', 'Medic asked', Colors.orange, 2),
      ],
    );
  }
}
