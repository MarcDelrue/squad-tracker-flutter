import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/screens/squads/create/squads_create.dart';
import 'package:squad_tracker_flutter/screens/squads/join/squads_join.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';

class SquadHomeScreen extends StatelessWidget {
  const SquadHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.squadSelectionTitle),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SquadJoinScreen(),
                ));
              },
              child: Text(AppLocalizations.of(context)!.joinASquad),
            ),
            const SizedBox(height: 20), // Add spacing between buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SquadCreateScreen()),
                );
              },
              child: Text(AppLocalizations.of(context)!.createASquad),
            ),
          ],
        ),
      ),
    );
  }
}
