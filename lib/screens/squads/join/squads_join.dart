import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/screens/squads/join/squads_join_form.dart';
import 'package:squad_tracker_flutter/screens/squads/join/squads_recent.dart';

class SquadJoinScreen extends StatelessWidget {
  const SquadJoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join squad'),
      ),
      body: const Column(
        children: [
          SquadJoinForm(),
          Expanded(child: SquadsRecentList()),
        ],
      ),
    );
  }
}
