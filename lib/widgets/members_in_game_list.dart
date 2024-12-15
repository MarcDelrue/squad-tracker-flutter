import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/widgets/member_in_game_row.dart';

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
          return Expanded(
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final member = snapshot.data![index];
                return MemberInGameRow(
                  name: member.user.username,
                  status: member.session.user_status,
                );
              },
            ),
          );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
