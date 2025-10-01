import 'package:flutter/material.dart';
import 'dart:async';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';

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
  int? _activeGameId;
  int _kills = 0;
  int _deaths = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _scoreboardSub;
  StreamSubscription<Map<String, dynamic>?>? _gameMetaSub;

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
    _gameMetaSub?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToGameStatus() async {
    final currentSquad = squadService.currentSquad;
    if (currentSquad == null) return;

    // Cancel existing subscriptions
    _scoreboardSub?.cancel();
    _gameMetaSub?.cancel();

    // Listen to game meta changes to track active game ID
    _gameMetaSub = gameService
        .streamActiveGameMetaBySquad(int.parse(currentSquad.id))
        .listen((meta) {
      if (!mounted) return;

      setState(() {
        _activeGameId = meta != null ? (meta['id'] as num?)?.toInt() : null;
      });

      // Subscribe to scoreboard if there's an active game
      if (_activeGameId != null) {
        _scoreboardSub =
            gameService.streamScoreboardByGame(_activeGameId!).listen((rows) {
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

            // Update kills and deaths
            final kills = (userRow['kills'] as num?)?.toInt() ?? 0;
            final deaths = (userRow['deaths'] as num?)?.toInt() ?? 0;
            if (mounted && (_kills != kills || _deaths != deaths)) {
              setState(() {
                _kills = kills;
                _deaths = deaths;
              });
            }
          }
        });
      } else {
        // No active game, cancel scoreboard subscription
        _scoreboardSub?.cancel();
        _scoreboardSub = null;
      }
    });
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
    final canKill = (_currentStatus == UserSquadSessionStatus.alive ||
            _currentStatus == UserSquadSessionStatus.help) &&
        _activeGameId != null;

    String? disabledReason;
    if (squadId == null) {
      disabledReason = "No squad selected";
    } else if (_activeGameId == null) {
      disabledReason = AppLocalizations.of(context)!.noActiveGame;
    } else if (_currentStatus != UserSquadSessionStatus.alive &&
        _currentStatus != UserSquadSessionStatus.help) {
      disabledReason = "You must be alive or need help to record kills";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canKill
                ? () async {
                    try {
                      await gameService.bumpKill(int.parse(squadId!));
                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!
                              .plusOneKillRecorded),
                          action: SnackBarAction(
                            label: AppLocalizations.of(context)!.undo,
                            onPressed: () async {
                              try {
                                await gameService
                                    .decrementKill(int.parse(squadId));
                              } catch (_) {}
                            },
                          ),
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                AppLocalizations.of(context)!.failedToAddKill),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    }
                  }
                : () {
                    // Show reason why button is disabled
                    if (disabledReason != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(disabledReason),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: canKill ? null : Colors.grey[300],
              foregroundColor: canKill ? null : Colors.grey[600],
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
            ),
            icon: const Icon(Icons.add_task),
            label: Text(AppLocalizations.of(context)!.plusOneKill),
          ),
        ),
      ],
    );
  }

  // In future, wire to GameService.streamMyStats to show server countdown

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kill/Death count display
          if (_activeGameId != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_kills',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Kills',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_deaths',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Deaths',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildKillButton(),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildToggleButton(
                l10n.statusDied,
                l10n.statusDead,
                Colors.grey,
                UserSquadSessionStatus.dead,
              ),
              _buildToggleButton(
                l10n.statusSendHelp,
                l10n.statusHelpAsked,
                Colors.orange,
                UserSquadSessionStatus.help,
              ),
              _buildToggleButton(
                l10n.statusSendMedic,
                l10n.statusMedicAsked,
                Colors.red,
                UserSquadSessionStatus.medic,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_activeGameId != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.fixMistakes,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final squadId = squadService.currentSquad?.id;
                        if (squadId == null) return;
                        try {
                          await gameService.decrementKill(int.parse(squadId));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.killDecremented),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.failedToDecrementKill),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.killMinusOne),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final squadId = squadService.currentSquad?.id;
                        if (squadId == null) return;
                        try {
                          await gameService.decrementDeath(int.parse(squadId));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.deathDecremented),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.failedToDecrementDeath),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.deathMinusOne),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
