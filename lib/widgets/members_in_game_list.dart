import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/member_in_game_model.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';

class MembersInGameList extends StatelessWidget {
  final UserSquadLocationService userSquadLocationService =
      UserSquadLocationService();

  MembersInGameList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemberInGame>>(
      stream: userSquadLocationService.membersDataStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(snapshot.data![0].name);
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
