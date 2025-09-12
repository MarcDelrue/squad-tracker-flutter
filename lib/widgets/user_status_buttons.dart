import 'package:flutter/material.dart';
import 'dart:async';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class UserStatusButtons extends StatefulWidget {
  const UserStatusButtons({super.key});

  @override
  _UserStatusButtonsState createState() => _UserStatusButtonsState();
}

class _UserStatusButtonsState extends State<UserStatusButtons> {
  final userSquadSessionService = UserSquadSessionService();
  final gameService = GameService();
  final squadService = SquadService();
  final userService = UserService();

  UserSquadSessionStatus? _currentStatus;
  StreamSubscription<List<Map<String, dynamic>>>? _scoreboardSub;

  // Respawn countdown can be sourced from GameService in future

  @override
  void initState() {
    super.initState();
    _currentStatus = userSquadSessionService.currentSquadSession?.user_status;
    _subscribeToGameStatus();
  }

  @override
  void dispose() {
    _scoreboardSub?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToGameStatus() async {
    final currentSquad = squadService.currentSquad;
    if (currentSquad == null) return;

    final gameId =
        await gameService.getActiveGameId(int.parse(currentSquad.id));
    if (!mounted) return;
    _scoreboardSub?.cancel();

    if (gameId != null) {
      _scoreboardSub =
          gameService.streamScoreboardByGame(gameId).listen((rows) {
        final currentUserId = userService.currentUser?.id;
        if (currentUserId == null) return;

        // Find the current user's status from the game stats
        final userRow =
            rows.where((r) => r['user_id'] == currentUserId).firstOrNull;
        if (userRow != null) {
          final statusString = userRow['user_status'] as String?;
          if (statusString != null) {
            try {
              final newStatus =
                  UserSquadSessionStatusExtension.fromValue(statusString);
              if (mounted && _currentStatus != newStatus) {
                setState(() {
                  _currentStatus = newStatus;
                });
              }
            } catch (_) {
              // Handle invalid status values
            }
          }
        }
      });
    }
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
        try {
          final squadId = squadService.currentSquad?.id;
          if (squadId == null) return;

          // Determine the new status to set
          final newStatus =
              _currentStatus != value ? value : UserSquadSessionStatus.alive;

          await gameService.setStatus(
              squadId: squadId, status: newStatus.value);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.profileUpdated),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.failedToUpdateStatus),
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
              content: Text(AppLocalizations.of(context)!.plusOneKillRecorded),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.undo,
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
                content: Text(AppLocalizations.of(context)!.failedToAddKill),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.add_task),
      label: Text(AppLocalizations.of(context)!.plusOneKill),
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
