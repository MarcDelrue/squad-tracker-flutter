import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';
import 'package:squad_tracker_flutter/l10n/localizations_extensions.dart';
import 'package:squad_tracker_flutter/widgets/scoreboard/leaderboard_view.dart';
import 'package:squad_tracker_flutter/widgets/scoreboard/history_view.dart';

class FinalReportOverlay extends StatefulWidget {
  final int gameId;
  const FinalReportOverlay({super.key, required this.gameId});

  @override
  State<FinalReportOverlay> createState() => _FinalReportOverlayState();
}

class _FinalReportOverlayState extends State<FinalReportOverlay>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.finalReportTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.leaderboardTab),
            Tab(text: l10n.historyTab),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            LeaderboardView(gameId: widget.gameId),
            HistoryView(gameId: widget.gameId),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.backToLobby),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Optional: implement share later
                },
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.share),
              ),
            )
          ],
        ),
      ),
    );
  }
}
