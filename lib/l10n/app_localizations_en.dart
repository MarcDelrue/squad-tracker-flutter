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
  String get unexpectedRetrieveProfile => 'Unexpected error occurred while retrieving profile';

  @override
  String get unexpectedUpdateProfile => 'Unexpected error occurred while updating profile';

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
  String get tooltipCompleteProfileSquads => 'Complete your profile to access Squads';

  @override
  String get tooltipCompleteProfileMap => 'Complete your profile to access Map';

  @override
  String get tooltipCompleteProfileTracker => 'Complete your profile to access Tracker';
}
