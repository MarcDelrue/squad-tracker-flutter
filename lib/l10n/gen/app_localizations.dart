import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Squad Tracker'**
  String get appTitle;

  /// No description provided for @userScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userScreenTitle;

  /// No description provided for @userNameLabel.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get userNameLabel;

  /// No description provided for @userNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get userNameValidation;

  /// No description provided for @selectRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Select a Role'**
  String get selectRoleLabel;

  /// No description provided for @selectRoleValidation.
  ///
  /// In en, this message translates to:
  /// **'Please select a role'**
  String get selectRoleValidation;

  /// No description provided for @yourColor.
  ///
  /// In en, this message translates to:
  /// **'Your color:'**
  String get yourColor;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @confirmSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Sign Out'**
  String get confirmSignOutTitle;

  /// No description provided for @confirmSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get confirmSignOutBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Successfully updated profile!'**
  String get profileUpdated;

  /// No description provided for @unexpectedRetrieveProfile.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error occurred while retrieving profile'**
  String get unexpectedRetrieveProfile;

  /// No description provided for @unexpectedUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error occurred while updating profile'**
  String get unexpectedUpdateProfile;

  /// No description provided for @unexpectedSignOut.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error occurred while signing out'**
  String get unexpectedSignOut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @tabUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get tabUser;

  /// No description provided for @tabSquads.
  ///
  /// In en, this message translates to:
  /// **'Squads'**
  String get tabSquads;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabTracker.
  ///
  /// In en, this message translates to:
  /// **'Tracker'**
  String get tabTracker;

  /// No description provided for @tooltipCompleteProfileSquads.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to access Squads'**
  String get tooltipCompleteProfileSquads;

  /// No description provided for @tooltipCompleteProfileMap.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to access Map'**
  String get tooltipCompleteProfileMap;

  /// No description provided for @tooltipCompleteProfileTracker.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to access Tracker'**
  String get tooltipCompleteProfileTracker;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @invalidSquadCode.
  ///
  /// In en, this message translates to:
  /// **'Not a valid squad code'**
  String get invalidSquadCode;

  /// No description provided for @scanSquadQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Squad QR'**
  String get scanSquadQrTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @kickUser.
  ///
  /// In en, this message translates to:
  /// **'Kick User'**
  String get kickUser;

  /// No description provided for @setAsHost.
  ///
  /// In en, this message translates to:
  /// **'Set as Host'**
  String get setAsHost;

  /// No description provided for @confirmKickUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Kick User'**
  String get confirmKickUserTitle;

  /// No description provided for @confirmKickUserBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to kick {username}?'**
  String confirmKickUserBody(String username);

  /// No description provided for @confirmSetHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Set Host'**
  String get confirmSetHostTitle;

  /// No description provided for @confirmSetHostBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to set {username} as the host?'**
  String confirmSetHostBody(String username);

  /// No description provided for @confirmLeaveSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Leave Squad'**
  String get confirmLeaveSquadTitle;

  /// No description provided for @confirmLeaveSquadBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the squad?'**
  String get confirmLeaveSquadBody;

  /// No description provided for @kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kick;

  /// No description provided for @setHost.
  ///
  /// In en, this message translates to:
  /// **'Set Host'**
  String get setHost;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get startGame;

  /// No description provided for @endGame.
  ///
  /// In en, this message translates to:
  /// **'End game'**
  String get endGame;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @trackerBleTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracker (BLE)'**
  String get trackerBleTitle;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop scan'**
  String get stopScanTooltip;

  /// No description provided for @nameFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Name filter (e.g. TTGO)'**
  String get nameFilterHint;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @syncToDevice.
  ///
  /// In en, this message translates to:
  /// **'Sync to Device'**
  String get syncToDevice;

  /// No description provided for @bluetoothPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permissions permanently denied'**
  String get bluetoothPermanentlyDenied;

  /// No description provided for @failedToUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status. Please try again.'**
  String get failedToUpdateStatus;

  /// No description provided for @plusOneKillRecorded.
  ///
  /// In en, this message translates to:
  /// **'+1 Kill recorded'**
  String get plusOneKillRecorded;

  /// No description provided for @failedToAddKill.
  ///
  /// In en, this message translates to:
  /// **'Failed to add kill'**
  String get failedToAddKill;

  /// No description provided for @plusOneKill.
  ///
  /// In en, this message translates to:
  /// **'+1 Kill'**
  String get plusOneKill;

  /// No description provided for @squadCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Squad code copied to clipboard'**
  String get squadCodeCopied;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @selectColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a Color'**
  String get selectColorTitle;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @createSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Create squad'**
  String get createSquadTitle;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @noRecentSquads.
  ///
  /// In en, this message translates to:
  /// **'No recent squads available'**
  String get noRecentSquads;

  /// No description provided for @lastJoinedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Last joined: '**
  String get lastJoinedPrefix;

  /// No description provided for @squadSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Squad Selection'**
  String get squadSelectionTitle;

  /// No description provided for @joinASquad.
  ///
  /// In en, this message translates to:
  /// **'Join a squad'**
  String get joinASquad;

  /// No description provided for @createASquad.
  ///
  /// In en, this message translates to:
  /// **'Create a squad'**
  String get createASquad;

  /// No description provided for @joinSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Join squad'**
  String get joinSquadTitle;

  /// No description provided for @noBattleLogs.
  ///
  /// In en, this message translates to:
  /// **'No battle logs yet'**
  String get noBattleLogs;

  /// No description provided for @youAreNowHost.
  ///
  /// In en, this message translates to:
  /// **'You are now the host'**
  String get youAreNowHost;

  /// No description provided for @youAreNoLongerHost.
  ///
  /// In en, this message translates to:
  /// **'You are no longer the host'**
  String get youAreNoLongerHost;

  /// No description provided for @squadNameHint.
  ///
  /// In en, this message translates to:
  /// **'Squad name'**
  String get squadNameHint;

  /// No description provided for @squadLobby.
  ///
  /// In en, this message translates to:
  /// **'Squad Lobby'**
  String get squadLobby;

  /// No description provided for @noActiveGame.
  ///
  /// In en, this message translates to:
  /// **'No active game'**
  String get noActiveGame;

  /// No description provided for @leaveSquad.
  ///
  /// In en, this message translates to:
  /// **'Leave Squad'**
  String get leaveSquad;

  /// No description provided for @gameStarted.
  ///
  /// In en, this message translates to:
  /// **'Game started'**
  String get gameStarted;

  /// No description provided for @gameEnded.
  ///
  /// In en, this message translates to:
  /// **'Game ended'**
  String get gameEnded;

  /// No description provided for @failedToStartGame.
  ///
  /// In en, this message translates to:
  /// **'Failed to start game: {error}'**
  String failedToStartGame(String error);

  /// No description provided for @failedToEndGame.
  ///
  /// In en, this message translates to:
  /// **'Failed to end game: {error}'**
  String failedToEndGame(String error);

  /// No description provided for @failedToKickUser.
  ///
  /// In en, this message translates to:
  /// **'Failed to kick user: {error}'**
  String failedToKickUser(String error);

  /// No description provided for @failedToSetHost.
  ///
  /// In en, this message translates to:
  /// **'Failed to set user as host: {error}'**
  String failedToSetHost(String error);

  /// No description provided for @hostTransferredTo.
  ///
  /// In en, this message translates to:
  /// **'Host transferred to {username}'**
  String hostTransferredTo(String username);

  /// No description provided for @failedToLeaveSquad.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave squad: {error}'**
  String failedToLeaveSquad(String error);

  /// No description provided for @inviteToSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite to Squad'**
  String get inviteToSquadTitle;

  /// No description provided for @inviteToSquadBody.
  ///
  /// In en, this message translates to:
  /// **'Share this code with users to join the squad:'**
  String get inviteToSquadBody;

  /// No description provided for @addNewMember.
  ///
  /// In en, this message translates to:
  /// **'Add New Member'**
  String get addNewMember;

  /// No description provided for @recentSquadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Squads'**
  String get recentSquadsTitle;

  /// No description provided for @joinedSquadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined squad successfully!'**
  String get joinedSquadSuccess;

  /// No description provided for @failedToJoinSquad.
  ///
  /// In en, this message translates to:
  /// **'Failed to join squad'**
  String get failedToJoinSquad;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get errorPrefix;

  /// No description provided for @turnTorchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn torch on'**
  String get turnTorchOn;

  /// No description provided for @turnTorchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn torch off'**
  String get turnTorchOff;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @squadMembers.
  ///
  /// In en, this message translates to:
  /// **'Squad Members'**
  String get squadMembers;

  /// No description provided for @disableGeolocation.
  ///
  /// In en, this message translates to:
  /// **'Disable Geolocation'**
  String get disableGeolocation;

  /// No description provided for @enableGeolocation.
  ///
  /// In en, this message translates to:
  /// **'Enable Geolocation'**
  String get enableGeolocation;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @joinedTheSquad.
  ///
  /// In en, this message translates to:
  /// **'joined the squad'**
  String get joinedTheSquad;

  /// No description provided for @leftTheSquad.
  ///
  /// In en, this message translates to:
  /// **'left the squad'**
  String get leftTheSquad;

  /// No description provided for @statusDied.
  ///
  /// In en, this message translates to:
  /// **'Died'**
  String get statusDied;

  /// No description provided for @statusDead.
  ///
  /// In en, this message translates to:
  /// **'Dead'**
  String get statusDead;

  /// No description provided for @statusSendHelp.
  ///
  /// In en, this message translates to:
  /// **'Send help'**
  String get statusSendHelp;

  /// No description provided for @statusHelpAsked.
  ///
  /// In en, this message translates to:
  /// **'Help asked'**
  String get statusHelpAsked;

  /// No description provided for @statusSendMedic.
  ///
  /// In en, this message translates to:
  /// **'Send medic'**
  String get statusSendMedic;

  /// No description provided for @statusMedicAsked.
  ///
  /// In en, this message translates to:
  /// **'Medic asked'**
  String get statusMedicAsked;

  /// No description provided for @fixMistakes.
  ///
  /// In en, this message translates to:
  /// **'Fix mistakes'**
  String get fixMistakes;

  /// No description provided for @killMinusOne.
  ///
  /// In en, this message translates to:
  /// **'Kill -1'**
  String get killMinusOne;

  /// No description provided for @deathMinusOne.
  ///
  /// In en, this message translates to:
  /// **'Death -1'**
  String get deathMinusOne;

  /// No description provided for @killDecremented.
  ///
  /// In en, this message translates to:
  /// **'Kill decremented'**
  String get killDecremented;

  /// No description provided for @deathDecremented.
  ///
  /// In en, this message translates to:
  /// **'Death decremented'**
  String get deathDecremented;

  /// No description provided for @failedToDecrementKill.
  ///
  /// In en, this message translates to:
  /// **'Failed to decrement kill'**
  String get failedToDecrementKill;

  /// No description provided for @failedToDecrementDeath.
  ///
  /// In en, this message translates to:
  /// **'Failed to decrement death'**
  String get failedToDecrementDeath;

  /// No description provided for @statusActions.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusActions;

  /// No description provided for @noSquadSelected.
  ///
  /// In en, this message translates to:
  /// **'No squad selected'**
  String get noSquadSelected;

  /// No description provided for @mustBeAliveToKill.
  ///
  /// In en, this message translates to:
  /// **'You must be alive to record kills'**
  String get mustBeAliveToKill;

  /// No description provided for @finalReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Final report'**
  String get finalReportTitle;

  /// No description provided for @leaderboardTab.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @sortByKills.
  ///
  /// In en, this message translates to:
  /// **'Sort by Kills'**
  String get sortByKills;

  /// No description provided for @sortByKDR.
  ///
  /// In en, this message translates to:
  /// **'Sort by K/D'**
  String get sortByKDR;

  /// No description provided for @sortByStreak.
  ///
  /// In en, this message translates to:
  /// **'Sort by Streak'**
  String get sortByStreak;

  /// No description provided for @kdLabel.
  ///
  /// In en, this message translates to:
  /// **'K/D'**
  String get kdLabel;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakLabel;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get noEventsYet;

  /// No description provided for @backToLobby.
  ///
  /// In en, this message translates to:
  /// **'Back to Lobby'**
  String get backToLobby;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @viewReport.
  ///
  /// In en, this message translates to:
  /// **'View report'**
  String get viewReport;

  /// No description provided for @pastGamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Past games'**
  String get pastGamesTitle;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @endedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Ended just now'**
  String get endedJustNow;

  /// No description provided for @killsLabel.
  ///
  /// In en, this message translates to:
  /// **'Kills'**
  String get killsLabel;

  /// No description provided for @deathsLabel.
  ///
  /// In en, this message translates to:
  /// **'Deaths'**
  String get deathsLabel;

  /// No description provided for @killedEnemy.
  ///
  /// In en, this message translates to:
  /// **'killed an enemy'**
  String get killedEnemy;

  /// No description provided for @died.
  ///
  /// In en, this message translates to:
  /// **'died'**
  String get died;

  /// No description provided for @respawned.
  ///
  /// In en, this message translates to:
  /// **'respawned'**
  String get respawned;

  /// No description provided for @askForHelp.
  ///
  /// In en, this message translates to:
  /// **'asked for help'**
  String get askForHelp;

  /// No description provided for @askForMedic.
  ///
  /// In en, this message translates to:
  /// **'asked for medic'**
  String get askForMedic;

  /// No description provided for @hostTransferred.
  ///
  /// In en, this message translates to:
  /// **'Host transferred'**
  String get hostTransferred;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
