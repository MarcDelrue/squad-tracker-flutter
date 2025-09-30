import 'package:squad_tracker_flutter/l10n/app_localizations.dart';

// Temporary fallback getters until gen-l10n is rerun. When generated keys exist,
// these extension getters will be shadowed by the real ones.
extension FinalReportStrings on AppLocalizations {
  String get finalReportTitle => 'Final report';
  String get leaderboardTab => 'Leaderboard';
  String get historyTab => 'History';
  String get sortByKills => 'Sort by Kills';
  String get sortByKDR => 'Sort by K/D';
  String get sortByStreak => 'Sort by Streak';
  String get kdLabel => 'K/D';
  String get streakLabel => 'Streak';
  String get noEventsYet => 'No events yet';
  String get backToLobby => 'Back to Lobby';
  String get share => 'Share';
  String get viewReport => 'View report';
  String get pastGamesTitle => 'Past games';
  String get durationLabel => 'Duration';
  String get endedJustNow => 'Ended just now';
  String get killsLabel => 'Kills';
  String get deathsLabel => 'Deaths';
  // History labels
  String get killedEnemy => 'killed an enemy';
  String get died => 'died';
  String get respawned => 'respawned';
  String get askForHelp => 'asked for help';
  String get askForMedic => 'asked for medic';
  String get hostTransferred => 'Host transferred';
}
