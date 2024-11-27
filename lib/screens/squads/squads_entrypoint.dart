import 'package:flutter/widgets.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/screens/squads/lobby/lobby_screen.dart';
import 'package:squad_tracker_flutter/screens/squads/squads_home.dart';

class SquadsEntrypoint extends StatefulWidget {
  const SquadsEntrypoint({super.key});

  @override
  State<SquadsEntrypoint> createState() => _SquadsEntrypointState();
}

class _SquadsEntrypointState extends State<SquadsEntrypoint> {
  final squadService = SquadService();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: squadService,
      builder: (context, child) {
        return squadService.currentSquad != null
            ? const SquadLobbyScreen()
            : const SquadHomeScreen();
      },
    );
  }
}
