import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';

class UserStatusButtons extends StatefulWidget {
  const UserStatusButtons({super.key});

  @override
  _UserStatusButtonsState createState() => _UserStatusButtonsState();
}

class _UserStatusButtonsState extends State<UserStatusButtons> {
  final userSquadSessionService = UserSquadSessionService();
  UserSquadSessionStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = userSquadSessionService.currentSquadSession?.user_status;
  }

  Widget _buildToggleButton(String text, String toggledText, Color color,
      UserSquadSessionStatus value) {
    return ElevatedButton(
      style: _currentStatus == value
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
          if (_currentStatus != value) {
            _currentStatus = value;
          } else {
            _currentStatus = UserSquadSessionStatus.alive;
          }
          userSquadSessionService
              .updateUserSquadSessionUserStatus(_currentStatus!);
        });
      },
      child: _currentStatus == value ? Text(toggledText) : Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleButton(
            'Died', 'Dead', Colors.grey, UserSquadSessionStatus.dead),
        const SizedBox(width: 10),
        _buildToggleButton(
            'Send help', 'Help asked', Colors.red, UserSquadSessionStatus.help),
        const SizedBox(width: 10),
        _buildToggleButton('Send medic', 'Medic asked', Colors.orange,
            UserSquadSessionStatus.medic),
      ],
    );
  }
}
