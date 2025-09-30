import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/battle_log_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/providers/battle_logs_service.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';

class BattleLogsWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const BattleLogsWidget({super.key, this.onClose});

  @override
  BattleLogsWidgetState createState() => BattleLogsWidgetState();
}

class BattleLogsWidgetState extends State<BattleLogsWidget> {
  final battleLogsService = BattleLogsService();
  final userService = UserService();

  @override
  void initState() {
    super.initState();
    // Start listening to battle logs when widget is created
    battleLogsService.startListening();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: battleLogsService,
      builder: (context, child) {
        final battleLogs = battleLogsService.battleLogs;

        if (battleLogs.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.noBattleLogs,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: battleLogs.length,
          itemBuilder: (context, index) {
            final battleLog = battleLogs[index];
            return battleLogToWidget(battleLog);
          },
        );
      },
    );
  }

  Widget battleLogToWidget(BattleLogModel battleLog) {
    final localeCode =
        Localizations.localeOf(context).languageCode.toLowerCase();
    final timeagoLocale = (localeCode == 'fr') ? 'fr_short' : 'en_short';
    return Container(
      color: Colors.black, // Fully opaque background
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          _translateBattleLogText(battleLog.text),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          timeago.format(battleLog.date, locale: timeagoLocale),
          style: const TextStyle(color: Colors.grey),
        ),
        onTap: () {
          // Don't do anything if it's the current user's log
          if (battleLog.user.id == userService.currentUser?.id) {
            return;
          }
          // Fly to the member and close battle logs
          _flyToMember(battleLog.user);
          widget.onClose?.call();
        },
      ),
    );
  }

  String _translateBattleLogText(String text) {
    final l10n = AppLocalizations.of(context)!;

    // Replace "You" with localized "You"
    text = text.replaceAll("You", l10n.you);

    // Replace "joined the squad" with localized text
    text = text.replaceAll("joined the squad", l10n.joinedTheSquad);

    // Replace "left the squad" with localized text
    text = text.replaceAll("left the squad", l10n.leftTheSquad);

    return text;
  }

  void _flyToMember(User user) {
    // Import the map user location service to fly to the member
    final mapUserLocationService = MapUserLocationService();
    final userSquadLocationService = UserSquadLocationService();

    // Find the member's location
    final memberLocation = userSquadLocationService.currentMembersLocation
        ?.where((location) => location.user_id == user.id)
        .firstOrNull;

    if (memberLocation != null &&
        memberLocation.latitude != null &&
        memberLocation.longitude != null) {
      // Fly to the member's location
      mapUserLocationService.flyToLocation(
        memberLocation.longitude!,
        memberLocation.latitude!,
      );
    }
  }
}
