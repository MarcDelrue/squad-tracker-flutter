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
              squadId: squadId, status: _currentStatus!.value);
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

  Widget _buildKillButton() {
    final squadId = squadService.currentSquad?.id;
    final canKill = _currentStatus == UserSquadSessionStatus.alive ||
        _currentStatus == UserSquadSessionStatus.help;
    if (squadId == null || !canKill) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          await gameService.bumpKill(int.parse(squadId));
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text('+1 Kill recorded'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  // Optional: requires adjust_stats RPC; noop for now
                },
              ),
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to add kill'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.add_task),
      label: const Text('+1 Kill'),
    );
  }

  // In future, wire to GameService.streamMyStats to show server countdown

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildToggleButton(
                'Died', 'Dead', Colors.grey, UserSquadSessionStatus.dead),
            const SizedBox(width: 10),
            _buildToggleButton('Send help', 'Help asked', Colors.red,
                UserSquadSessionStatus.help),
            const SizedBox(width: 10),
            _buildToggleButton('Send medic', 'Medic asked', Colors.orange,
                UserSquadSessionStatus.medic),
          ],
        ),
        const SizedBox(height: 12),
        _buildKillButton(),
      ],
    );
  }
}
