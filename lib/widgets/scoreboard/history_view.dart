import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryView extends StatefulWidget {
  final int gameId;
  const HistoryView({super.key, required this.gameId});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _gameService = GameService();
  List<Map<String, dynamic>> _events = const [];
  Map<String, String> _usernames = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _gameService.getGameEvents(widget.gameId);
    // Filter out STATUS_CHANGE events to DEAD since DEATH events handle this
    final filteredData = data.where((e) {
      if (e['event_type'] == 'STATUS_CHANGE') {
        final payload = e['payload'] as Map<String, dynamic>?;
        final toStatus = payload?['toStatus'] as String?;
        return toStatus != 'DEAD';
      }
      return true;
    }).toList();

    // gather user ids to resolve usernames
    final ids = <String>{};
    for (final e in filteredData) {
      final uid = e['user_id'] as String?;
      if (uid != null) ids.add(uid);
      // also capture possible targetUserId in payload
      final payload = e['payload'];
      if (payload is Map && payload['targetUserId'] is String) {
        ids.add(payload['targetUserId'] as String);
      }
    }
    final names = await _gameService.getUsernamesByIds(ids.toList());
    setState(() {
      _events = filteredData;
      _usernames = names;
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'KILL':
        return Icons.check_circle_outline;
      case 'DEATH':
        return Icons.close_rounded;
      case 'STATUS_CHANGE':
        return Icons.flag_outlined;
      case 'JOIN':
        return Icons.person_add_alt_1;
      case 'LEAVE':
        return Icons.exit_to_app;
      case 'GAME_STARTED':
        return Icons.play_arrow_rounded;
      case 'GAME_ENDED':
        return Icons.stop_circle_outlined;
      case 'HOST_TRANSFER':
        return Icons.star_outline;
    }
    return Icons.bolt;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_events.isEmpty) {
      return Center(child: Text(l10n.noEventsYet));
    }
    final dayTime = DateFormat.yMMMd().add_jm();
    return ListView.separated(
      itemCount: _events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = _events[index];
        final type = (e['event_type'] as String?) ?? '';
        final tsStr = (e['occurred_at'] ?? e['created_at'])?.toString();
        final ts = tsStr != null ? DateTime.tryParse(tsStr) : null;
        final userId = e['user_id'] as String?;
        final who = userId != null
            ? (_usernames[userId] ??
                (userId == Supabase.instance.client.auth.currentUser?.id
                    ? l10n.you
                    : ''))
            : '';
        final payload = e['payload'] as Map<String, dynamic>?;
        final subtitleTime = ts != null ? dayTime.format(ts.toLocal()) : '';

        String title;
        switch (type) {
          case 'KILL':
            title =
                who.isNotEmpty ? "$who ${l10n.killedEnemy}" : l10n.killedEnemy;
            break;
          case 'DEATH':
            title = who.isNotEmpty ? "$who ${l10n.died}" : l10n.died;
            break;
          case 'STATUS_CHANGE':
            final fromS = payload?['fromStatus'] as String?;
            final toS = payload?['toStatus'] as String?;
            title = _statusChangeText(l10n, who, fromS, toS);
            break;
          case 'JOIN':
            title = who.isNotEmpty
                ? "$who ${l10n.joinedTheSquad}"
                : l10n.joinedTheSquad;
            break;
          case 'LEAVE':
            title = who.isNotEmpty
                ? "$who ${l10n.leftTheSquad}"
                : l10n.leftTheSquad;
            break;
          case 'GAME_STARTED':
            title = l10n.gameStarted;
            break;
          case 'GAME_ENDED':
            title = l10n.gameEnded;
            break;
          case 'HOST_TRANSFER':
            title = l10n.hostTransferred;
            break;
          default:
            title = type;
        }
        return ListTile(
          leading: Icon(_iconFor(type)),
          title: Text(title),
          subtitle: Text(subtitleTime),
        );
      },
    );
  }

  String _statusChangeText(
      AppLocalizations l10n, String who, String? fromS, String? toS) {
    String label;
    switch (toS) {
      case 'ALIVE':
        label = l10n.respawned;
        break;
      case 'HELP':
        label = l10n.askForHelp;
        break;
      case 'MEDIC':
        label = l10n.askForMedic;
        break;
      default:
        label = l10n.statusActions;
    }
    return who.isNotEmpty ? "$who $label" : label;
  }
}
