import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScoreboardWidget extends StatefulWidget {
  const ScoreboardWidget({super.key});

  @override
  State<ScoreboardWidget> createState() => _ScoreboardWidgetState();
}

class _ScoreboardWidgetState extends State<ScoreboardWidget> {
  final gameService = GameService();
  final squadService = SquadService();
  Future<int?>? _activeGameFuture;

  @override
  void initState() {
    super.initState();
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr != null) {
      _activeGameFuture = gameService.getActiveGameId(int.parse(squadIdStr));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: FutureBuilder<int?>(
        future: _activeGameFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final gameId = snap.data;
          if (gameId == null) {
            return const Center(child: Text('No active game'));
          }
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: gameService.streamScoreboardByGame(gameId),
            builder: (context, s) {
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = [...s.data!];
              rows.sort((a, b) {
                final ak = (a['kills'] as num? ?? 0).toInt();
                final bk = (b['kills'] as num? ?? 0).toInt();
                final ad = (a['deaths'] as num? ?? 0).toInt();
                final bd = (b['deaths'] as num? ?? 0).toInt();
                if (bk != ak) return bk.compareTo(ak);
                return ad.compareTo(bd);
              });
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final r = rows[index];
                  final username = r['username'] ?? r['user_id'];
                  final kills = (r['kills'] as num? ?? 0).toInt();
                  final deaths = (r['deaths'] as num? ?? 0).toInt();
                  final kd = deaths == 0 ? kills.toDouble() : kills / deaths;
                  final isMe = r['user_id'] == myId;
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      '$username',
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text('K/D: ${kd.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_martial_arts, size: 16),
                        const SizedBox(width: 4),
                        Text('$kills'),
                        const SizedBox(width: 12),
                        const Icon(Icons.heart_broken, size: 16),
                        const SizedBox(width: 4),
                        Text('$deaths'),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
