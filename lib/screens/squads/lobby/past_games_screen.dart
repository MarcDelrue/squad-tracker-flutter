import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/widgets/scoreboard/final_report_overlay.dart';

class PastGamesScreen extends StatefulWidget {
  const PastGamesScreen({super.key});

  @override
  State<PastGamesScreen> createState() => _PastGamesScreenState();
}

class _PastGamesScreenState extends State<PastGamesScreen> {
  final _gameService = GameService();
  final _squadService = SquadService();
  List<Map<String, dynamic>> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPastGames();
  }

  Future<void> _loadPastGames() async {
    final squadId = _squadService.currentSquad?.id;
    if (squadId == null) return;

    setState(() => _isLoading = true);
    try {
      final games = await _gameService.listPastGames(int.parse(squadId));
      setState(() {
        _games = games;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load past games: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pastGamesTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noEventsYet,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPastGames,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _games.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final game = _games[index];
                      final started = DateTime.tryParse(
                          game['started_at']?.toString() ?? '');
                      final ended =
                          DateTime.tryParse(game['ended_at']?.toString() ?? '');
                      final duration = (started != null && ended != null)
                          ? ended.difference(started)
                          : null;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('#${game['id']}'),
                        ),
                        title: Text(
                          started?.toLocal().toString().substring(0, 16) ??
                              'Unknown date',
                        ),
                        subtitle: Text(
                          duration != null
                              ? '${l10n.durationLabel}: ${duration.inMinutes}m'
                              : l10n.endedJustNow,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (ctx) => SizedBox(
                                height: MediaQuery.of(ctx).size.height * 0.92,
                                child: FinalReportOverlay(
                                  gameId: (game['id'] as num).toInt(),
                                  onBackToLobby: () {
                                    Navigator.of(ctx).pop(); // Close the modal
                                    Navigator.of(context)
                                        .pop(); // Go back to main lobby screen
                                  },
                                ),
                              ),
                            );
                          },
                          child: Text(l10n.viewReport),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
