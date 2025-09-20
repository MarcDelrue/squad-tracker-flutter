import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';
import 'package:squad_tracker_flutter/l10n/localizations_extensions.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';

class HistoryView extends StatefulWidget {
  final int gameId;
  const HistoryView({super.key, required this.gameId});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _gameService = GameService();
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _gameService.getGameEvents(widget.gameId);
    setState(() => _events = data);
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
        return ListTile(
          leading: Icon(_iconFor(type)),
          title: Text(type),
          subtitle: Text(ts != null ? dayTime.format(ts.toLocal()) : ''),
        );
      },
    );
  }
}
