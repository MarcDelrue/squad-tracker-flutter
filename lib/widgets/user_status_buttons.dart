import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';

class UserStatusButtons extends StatefulWidget {
  const UserStatusButtons({super.key});

  @override
  _UserStatusButtonsState createState() => _UserStatusButtonsState();
}

class _UserStatusButtonsState extends State<UserStatusButtons> {
  final userSquadSessionService = UserSquadSessionService();
  final gameService = GameService();
  final squadService = SquadService();
  UserSquadSessionStatus? _currentStatus;
  // Respawn countdown can be sourced from GameService in future

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
      onPressed: () async {
        setState(() {
          if (_currentStatus != value) {
            _currentStatus = value;
          } else {
            _currentStatus = UserSquadSessionStatus.alive;
          }
        });

        try {
          final squadId = squadService.currentSquad?.id;
          if (squadId == null) return;
          await gameService.setStatus(
              squadId: int.parse(squadId), status: _currentStatus!.value);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Successfully updated status to ${_currentStatus!.value.toLowerCase()}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update status. Please try again.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
      child: _currentStatus == value ? Text(toggledText) : Text(text),
    );
  }

  // In future, wire to GameService.streamMyStats to show server countdown

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
