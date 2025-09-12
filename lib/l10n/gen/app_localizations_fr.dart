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

  @override
  String get loginTitle => 'Connexion';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get invalidSquadCode => 'Code d\'escouade invalide';

  @override
  String get scanSquadQrTitle => 'Scanner le QR de l\'escouade';

  @override
  String get retry => 'Réessayer';

  @override
  String get join => 'Rejoindre';

  @override
  String get kickUser => 'Exclure l\'utilisateur';

  @override
  String get setAsHost => 'Définir comme hôte';

  @override
  String get confirmKickUserTitle => 'Confirmer l\'exclusion';

  @override
  String confirmKickUserBody(String username) {
    return 'Êtes-vous sûr de vouloir exclure $username ?';
  }

  @override
  String get confirmSetHostTitle => 'Confirmer l\'attribution d\'hôte';

  @override
  String confirmSetHostBody(String username) {
    return 'Êtes-vous sûr de vouloir définir $username comme hôte ?';
  }

  @override
  String get confirmLeaveSquadTitle => 'Confirmer le départ de l\'escouade';

  @override
  String get confirmLeaveSquadBody =>
      'Êtes-vous sûr de vouloir quitter l\'escouade ?';

  @override
  String get kick => 'Exclure';

  @override
  String get setHost => 'Définir l\'hôte';

  @override
  String get leave => 'Quitter';

  @override
  String get startGame => 'Démarrer la partie';

  @override
  String get endGame => 'Terminer la partie';

  @override
  String get loading => 'Chargement...';

  @override
  String get trackerBleTitle => 'Tracker (BLE)';

  @override
  String get scan => 'Scanner';

  @override
  String get stop => 'Arrêter';

  @override
  String get stopScanTooltip => 'Arrêter le scan';

  @override
  String get nameFilterHint => 'Filtre de nom (ex : TTGO)';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get connect => 'Se connecter';

  @override
  String get syncToDevice => 'Synchroniser avec l\'appareil';

  @override
  String get bluetoothPermanentlyDenied =>
      'Autorisations Bluetooth refusées définitivement';

  @override
  String get failedToUpdateStatus =>
      'Échec de la mise à jour du statut. Veuillez réessayer.';

  @override
  String get plusOneKillRecorded => '+1 élimination enregistrée';

  @override
  String get failedToAddKill => 'Échec de l\'ajout de l\'élimination';

  @override
  String get plusOneKill => '+1 élimination';

  @override
  String get squadCodeCopied => 'Code d\'escouade copié dans le presse-papiers';

  @override
  String get close => 'Fermer';

  @override
  String get selectColorTitle => 'Sélectionner une couleur';

  @override
  String get select => 'Sélectionner';

  @override
  String get createSquadTitle => 'Créer une escouade';

  @override
  String get submit => 'Envoyer';

  @override
  String get noRecentSquads => 'Aucune escouade récente disponible';

  @override
  String get lastJoinedPrefix => 'Dernière connexion : ';

  @override
  String get squadSelectionTitle => 'Sélection de l\'escouade';

  @override
  String get joinASquad => 'Rejoindre une escouade';

  @override
  String get createASquad => 'Créer une escouade';

  @override
  String get joinSquadTitle => 'Rejoindre une escouade';

  @override
  String get noBattleLogs => 'Aucun journal de bataille pour l\'instant';
}
