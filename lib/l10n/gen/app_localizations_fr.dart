// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Squad Tracker';

  @override
  String get userScreenTitle => 'Utilisateur';

  @override
  String get userNameLabel => 'Nom d\'utilisateur';

  @override
  String get userNameValidation => 'Veuillez saisir un nom d\'utilisateur';

  @override
  String get selectRoleLabel => 'Sélectionnez un rôle';

  @override
  String get selectRoleValidation => 'Veuillez sélectionner un rôle';

  @override
  String get yourColor => 'Votre couleur :';

  @override
  String get update => 'Mettre à jour';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get confirmSignOutTitle => 'Confirmer la déconnexion';

  @override
  String get confirmSignOutBody =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès !';

  @override
  String get unexpectedRetrieveProfile =>
      'Erreur inattendue lors de la récupération du profil';

  @override
  String get unexpectedUpdateProfile =>
      'Erreur inattendue lors de la mise à jour du profil';

  @override
  String get unexpectedSignOut => 'Erreur inattendue lors de la déconnexion';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get tabUser => 'Utilisateur';

  @override
  String get tabSquads => 'Escouades';

  @override
  String get tabMap => 'Carte';

  @override
  String get tabTracker => 'Tracker';

  @override
  String get tooltipCompleteProfileSquads =>
      'Complétez votre profil pour accéder aux Escouades';

  @override
  String get tooltipCompleteProfileMap =>
      'Complétez votre profil pour accéder à la Carte';

  @override
  String get tooltipCompleteProfileTracker =>
      'Complétez votre profil pour accéder au Tracker';
}
