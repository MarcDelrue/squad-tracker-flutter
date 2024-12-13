import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/member_in_game_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';

class MembersInGameList extends StatelessWidget {
  final UserSquadLocationService userSquadLocationService =
      UserSquadLocationService();
  final squadMembersService = SquadMembersService();

  MembersInGameList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserWithSession>?>(
      stream: squadMembersService.currentSquadMembersStream,
      builder: (BuildContext context,
          AsyncSnapshot<List<UserWithSession>?> snapshot) {
        if (snapshot.hasData) {
          return Text(snapshot.data![0].user.username!);
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
