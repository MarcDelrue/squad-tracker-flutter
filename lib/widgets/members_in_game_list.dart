import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/member_in_game_model.dart';
import 'package:squad_tracker_flutter/widgets/member_in_game_row.dart';

class MembersInGameList extends StatelessWidget {
  final List<MemberInGame> membersData;

  const MembersInGameList({super.key, required this.membersData});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: membersData.length,
      itemBuilder: (context, index) {
        final member = membersData[index];
        return MemberInGameRow(memberData: member);
      },
    );
  }
}
