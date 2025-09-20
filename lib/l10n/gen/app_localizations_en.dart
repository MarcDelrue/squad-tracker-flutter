// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Squad Tracker';

  @override
  String get userScreenTitle => 'User';

  @override
  String get userNameLabel => 'User Name';

  @override
  String get userNameValidation => 'Please enter a username';

  @override
  String get selectRoleLabel => 'Select a Role';

  @override
  String get selectRoleValidation => 'Please select a role';

  @override
  String get yourColor => 'Your color:';

  @override
  String get update => 'Update';

  @override
  String get saving => 'Saving...';

  @override
  String get signOut => 'Sign Out';

  @override
  String get confirmSignOutTitle => 'Confirm Sign Out';

  @override
  String get confirmSignOutBody => 'Are you sure you want to sign out?';

  @override
  String get cancel => 'Cancel';

  @override
  String get profileUpdated => 'Successfully updated profile!';

  @override
  String get unexpectedRetrieveProfile =>
      'Unexpected error occurred while retrieving profile';

  @override
  String get unexpectedUpdateProfile =>
      'Unexpected error occurred while updating profile';

  @override
  String get unexpectedSignOut => 'Unexpected error occurred while signing out';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get tabUser => 'User';

  @override
  String get tabSquads => 'Squads';

  @override
  String get tabMap => 'Map';

  @override
  String get tabTracker => 'Tracker';

  @override
  String get tooltipCompleteProfileSquads =>
      'Complete your profile to access Squads';

  @override
  String get tooltipCompleteProfileMap => 'Complete your profile to access Map';

  @override
  String get tooltipCompleteProfileTracker =>
      'Complete your profile to access Tracker';

  @override
  String get loginTitle => 'Login';

  @override
  String get emailLabel => 'Email';

  @override
  String get invalidSquadCode => 'Not a valid squad code';

  @override
  String get scanSquadQrTitle => 'Scan Squad QR';

  @override
  String get retry => 'Retry';

  @override
  String get join => 'Join';

  @override
  String get kickUser => 'Kick User';

  @override
  String get setAsHost => 'Set as Host';

  @override
  String get confirmKickUserTitle => 'Confirm Kick User';

  @override
  String confirmKickUserBody(String username) {
    return 'Are you sure you want to kick $username?';
  }

  @override
  String get confirmSetHostTitle => 'Confirm Set Host';

  @override
  String confirmSetHostBody(String username) {
    return 'Are you sure you want to set $username as the host?';
  }

  @override
  String get confirmLeaveSquadTitle => 'Confirm Leave Squad';

  @override
  String get confirmLeaveSquadBody =>
      'Are you sure you want to leave the squad?';

  @override
  String get kick => 'Kick';

  @override
  String get setHost => 'Set Host';

  @override
  String get leave => 'Leave';

  @override
  String get startGame => 'Start game';

  @override
  String get endGame => 'End game';

  @override
  String get loading => 'Loading...';

  @override
  String get trackerBleTitle => 'Tracker (BLE)';

  @override
  String get scan => 'Scan';

  @override
  String get stop => 'Stop';

  @override
  String get stopScanTooltip => 'Stop scan';

  @override
  String get nameFilterHint => 'Name filter (e.g. TTGO)';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connect => 'Connect';

  @override
  String get syncToDevice => 'Sync to Device';

  @override
  String get bluetoothPermanentlyDenied =>
      'Bluetooth permissions permanently denied';

  @override
  String get failedToUpdateStatus =>
      'Failed to update status. Please try again.';

  @override
  String get plusOneKillRecorded => '+1 Kill recorded';

  @override
  String get failedToAddKill => 'Failed to add kill';

  @override
  String get plusOneKill => '+1 Kill';

  @override
  String get squadCodeCopied => 'Squad code copied to clipboard';

  @override
  String get close => 'Close';

  @override
  String get selectColorTitle => 'Select a Color';

  @override
  String get select => 'Select';

  @override
  String get createSquadTitle => 'Create squad';

  @override
  String get submit => 'Submit';

  @override
  String get noRecentSquads => 'No recent squads available';

  @override
  String get lastJoinedPrefix => 'Last joined: ';

  @override
  String get squadSelectionTitle => 'Squad Selection';

  @override
  String get joinASquad => 'Join a squad';

  @override
  String get createASquad => 'Create a squad';

  @override
  String get joinSquadTitle => 'Join squad';

  @override
  String get noBattleLogs => 'No battle logs yet';

  @override
  String get youAreNowHost => 'You are now the host';

  @override
  String get youAreNoLongerHost => 'You are no longer the host';

  @override
  String get squadNameHint => 'Squad name';

  @override
  String get squadLobby => 'Squad Lobby';

  @override
  String get noActiveGame => 'No active game';

  @override
  String get leaveSquad => 'Leave Squad';

  @override
  String get gameStarted => 'Game started';

  @override
  String get gameEnded => 'Game ended';

  @override
  String failedToStartGame(String error) {
    return 'Failed to start game: $error';
  }

  @override
  String failedToEndGame(String error) {
    return 'Failed to end game: $error';
  }

  @override
  String failedToKickUser(String error) {
    return 'Failed to kick user: $error';
  }

  @override
  String failedToSetHost(String error) {
    return 'Failed to set user as host: $error';
  }

  @override
  String hostTransferredTo(String username) {
    return 'Host transferred to $username';
  }

  @override
  String failedToLeaveSquad(String error) {
    return 'Failed to leave squad: $error';
  }

  @override
  String get inviteToSquadTitle => 'Invite to Squad';

  @override
  String get inviteToSquadBody =>
      'Share this code with users to join the squad:';

  @override
  String get addNewMember => 'Add New Member';

  @override
  String get recentSquadsTitle => 'Recent Squads';

  @override
  String get joinedSquadSuccess => 'Joined squad successfully!';

  @override
  String get failedToJoinSquad => 'Failed to join squad';

  @override
  String get errorPrefix => 'Error: ';

  @override
  String get turnTorchOn => 'Turn torch on';

  @override
  String get turnTorchOff => 'Turn torch off';

  @override
  String get undo => 'Undo';

  @override
  String get squadMembers => 'Squad Members';

  @override
  String get disableGeolocation => 'Disable Geolocation';

  @override
  String get enableGeolocation => 'Enable Geolocation';

  @override
  String get you => 'You';

  @override
  String get joinedTheSquad => 'joined the squad';

  @override
  String get leftTheSquad => 'left the squad';

  @override
  String get statusDied => 'Died';

  @override
  String get statusDead => 'Dead';

  @override
  String get statusSendHelp => 'Send help';

  @override
  String get statusHelpAsked => 'Help asked';

  @override
  String get statusSendMedic => 'Send medic';

  @override
  String get statusMedicAsked => 'Medic asked';

  @override
  String get fixMistakes => 'Fix mistakes';

  @override
  String get killMinusOne => 'Kill -1';

  @override
  String get deathMinusOne => 'Death -1';

  @override
  String get killDecremented => 'Kill decremented';

  @override
  String get deathDecremented => 'Death decremented';

  @override
  String get failedToDecrementKill => 'Failed to decrement kill';

  @override
  String get failedToDecrementDeath => 'Failed to decrement death';

  @override
  String get statusActions => 'Status';

  @override
  String get noSquadSelected => 'No squad selected';

  @override
  String get mustBeAliveToKill => 'You must be alive to record kills';

  @override
  String get finalReportTitle => 'Final report';

  @override
  String get leaderboardTab => 'Leaderboard';

  @override
  String get historyTab => 'History';

  @override
  String get sortByKills => 'Sort by Kills';

  @override
  String get sortByKDR => 'Sort by K/D';

  @override
  String get sortByStreak => 'Sort by Streak';

  @override
  String get kdLabel => 'K/D';

  @override
  String get streakLabel => 'Streak';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get backToLobby => 'Back to Lobby';

  @override
  String get share => 'Share';

  @override
  String get viewReport => 'View report';

  @override
  String get pastGamesTitle => 'Past games';

  @override
  String get durationLabel => 'Duration';

  @override
  String get endedJustNow => 'Ended just now';

  @override
  String get killsLabel => 'Kills';

  @override
  String get deathsLabel => 'Deaths';
}
