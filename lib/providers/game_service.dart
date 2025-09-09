import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameService extends ChangeNotifier {
  // Singleton
  static final GameService _singleton = GameService._internal();
  factory GameService() => _singleton;
  GameService._internal();

  final SupabaseClient _sb = Supabase.instance.client;

  Future<int?> startGame(int squadId) async {
    final resp = await _sb.rpc('start_game', params: {
      'p_squad_id': squadId,
    });
    if (resp == null) return null;
    return (resp as num).toInt();
  }

  Future<void> endGame(int squadId) async {
    await _sb.rpc('end_game', params: {
      'p_squad_id': squadId,
    });
  }

  Future<void> setStatus(
      {required String squadId, required String status}) async {
    await _sb.rpc('set_user_status', params: {
      'p_squad_id': squadId,
      'p_status': status,
    });
  }

  Future<void> bumpKill(int squadId) async {
    await _sb.rpc('bump_kill', params: {
      'p_squad_id': squadId,
    });
  }

  Future<int?> getActiveGameId(int squadId) async {
    final resp = await _sb.rpc('get_active_game_id', params: {
      'p_squad_id': squadId,
    });
    if (resp == null) return null;
    return (resp as num).toInt();
  }

  Future<Map<String, dynamic>?> getActiveGameMeta(int squadId) async {
    final id = await getActiveGameId(squadId);
    if (id == null) return null;
    try {
      final row = await _sb
          .from('squad_games')
          .select('id, started_at, ended_at, squad_id, host_user_id')
          .eq('id', id)
          .single();
      return row;
    } catch (_) {
      return null;
    }
  }

  Stream<Map<String, dynamic>?> streamActiveGameMetaBySquad(int squadId) {
    return _sb
        .from('squad_games')
        .stream(primaryKey: ['id'])
        .eq('squad_id', squadId)
        .map((rows) {
          final active = rows.where((r) => r['ended_at'] == null).toList();
          if (active.isEmpty) return null;
          active.sort((a, b) {
            final sa = DateTime.tryParse(a['started_at']?.toString() ?? '');
            final sb = DateTime.tryParse(b['started_at']?.toString() ?? '');
            if (sa == null && sb == null) return 0;
            if (sa == null) return 1;
            if (sb == null) return -1;
            return sb.compareTo(sa);
          });
          return active.first;
        });
  }

  // Stream scoreboard for a specific active game
  Stream<List<Map<String, dynamic>>> streamScoreboardByGame(int gameId) {
    return _sb.from('user_game_stats').stream(primaryKey: ['id']).map(
        (rows) => rows.where((r) => r['game_id'] == gameId).toList());
  }

  // Convenience: stream scoreboard for the active game of a squad
  Future<Stream<List<Map<String, dynamic>>>?> streamScoreboardBySquad(
      int squadId) async {
    final gameId = await getActiveGameId(squadId);
    if (gameId == null) return null;
    return streamScoreboardByGame(gameId);
  }

  // Stream current user's game stats for active game in a squad
  Future<Stream<Map<String, dynamic>>?> streamMyStats(int squadId) async {
    final gameId = await getActiveGameId(squadId);
    if (gameId == null) return null;
    final myId = _sb.auth.currentUser?.id;
    if (myId == null) return null;
    return _sb.from('user_game_stats').stream(primaryKey: ['id']).map((rows) {
      final filtered = rows
          .where((r) => r['game_id'] == gameId && r['user_id'] == myId)
          .toList();
      return filtered.isNotEmpty ? filtered.first : <String, dynamic>{};
    });
  }
}
