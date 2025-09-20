import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';
import 'package:squad_tracker_flutter/l10n/localizations_extensions.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';

enum LeaderboardSort { kills, kdr, streak }

class LeaderboardView extends StatefulWidget {
  final int gameId;
  const LeaderboardView({super.key, required this.gameId});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  final _gameService = GameService();
  LeaderboardSort _sort = LeaderboardSort.kills;
  List<Map<String, dynamic>> _rows = const [];
  bool _hasStreakData = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _gameService.getFinalScoreboard(widget.gameId);
    final hasStreak = data.any((r) => r['max_kill_streak'] != null);
    setState(() {
      _rows = data;
      _hasStreakData = hasStreak;
    });
  }

  double _kdr(num kills, num deaths) {
    final k = kills.toDouble();
    final d = deaths.toDouble();
    if (k == 0 && d == 0) return -1; // special marker for display "—"
    if (d == 0) return k; // treat as kills
    return k / d;
  }

  List<Map<String, dynamic>> _sorted() {
    final copy = [..._rows];
    switch (_sort) {
      case LeaderboardSort.kills:
        copy.sort((a, b) {
          final ka = (a['kills'] as num?)?.toInt() ?? 0;
          final kb = (b['kills'] as num?)?.toInt() ?? 0;
          if (kb != ka) return kb.compareTo(ka);
          final da = (a['deaths'] as num?)?.toInt() ?? 0;
          final db = (b['deaths'] as num?)?.toInt() ?? 0;
          if (da != db) return da.compareTo(db);
          final ua = (a['username'] as String?) ?? '';
          final ub = (b['username'] as String?) ?? '';
          return ua.compareTo(ub);
        });
        break;
      case LeaderboardSort.kdr:
        copy.sort((a, b) {
          final kdra = _kdr(a['kills'] ?? 0, a['deaths'] ?? 0);
          final kdrb = _kdr(b['kills'] ?? 0, b['deaths'] ?? 0);
          if (kdrb != kdra) return kdrb.compareTo(kdra);
          final ka = (a['kills'] as num?)?.toInt() ?? 0;
          final kb = (b['kills'] as num?)?.toInt() ?? 0;
          if (kb != ka) return kb.compareTo(ka);
          final da = (a['deaths'] as num?)?.toInt() ?? 0;
          final db = (b['deaths'] as num?)?.toInt() ?? 0;
          if (da != db) return da.compareTo(db);
          final ua = (a['username'] as String?) ?? '';
          final ub = (b['username'] as String?) ?? '';
          return ua.compareTo(ub);
        });
        break;
      case LeaderboardSort.streak:
        copy.sort((a, b) {
          final sa = (a['max_kill_streak'] as num?)?.toInt() ?? -1;
          final sb = (b['max_kill_streak'] as num?)?.toInt() ?? -1;
          if (sb != sa) return sb.compareTo(sa);
          final ka = (a['kills'] as num?)?.toInt() ?? 0;
          final kb = (b['kills'] as num?)?.toInt() ?? 0;
          if (kb != ka) return kb.compareTo(ka);
          final da = (a['deaths'] as num?)?.toInt() ?? 0;
          final db = (b['deaths'] as num?)?.toInt() ?? 0;
          if (da != db) return da.compareTo(db);
          final ua = (a['username'] as String?) ?? '';
          final ub = (b['username'] as String?) ?? '';
          return ua.compareTo(ub);
        });
        break;
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = _sorted();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.sortByKills),
                selected: _sort == LeaderboardSort.kills,
                onSelected: (_) =>
                    setState(() => _sort = LeaderboardSort.kills),
              ),
              ChoiceChip(
                label: Text(l10n.sortByKDR),
                selected: _sort == LeaderboardSort.kdr,
                onSelected: (_) => setState(() => _sort = LeaderboardSort.kdr),
              ),
              if (_hasStreakData)
                ChoiceChip(
                  label: Text(l10n.sortByStreak),
                  selected: _sort == LeaderboardSort.streak,
                  onSelected: (_) =>
                      setState(() => _sort = LeaderboardSort.streak),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = rows[index];
              final kills = (r['kills'] as num?)?.toInt() ?? 0;
              final deaths = (r['deaths'] as num?)?.toInt() ?? 0;
              final kdr = _kdr(kills, deaths);
              final rank = index + 1;
              return ListTile(
                leading: CircleAvatar(child: Text(rank.toString())),
                title: Text((r['username'] as String?) ?? '—'),
                subtitle: Text(
                  '${l10n.killsLabel}: $kills · ${l10n.deathsLabel}: $deaths · ${l10n.kdLabel}: ${kdr < 0 ? '—' : kdr.toStringAsFixed(2)}',
                ),
                trailing: _hasStreakData
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('${r['max_kill_streak'] ?? 0}')
                        ],
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
