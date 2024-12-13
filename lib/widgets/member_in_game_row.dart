import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/member_in_game_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class MemberInGameRow extends StatelessWidget {
  const MemberInGameRow({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // children: [
          //   Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text(
          //         memberData.user.username!,
          //         style: const TextStyle(
          //           fontWeight: FontWeight.bold,
          //           fontSize: 16.0,
          //         ),
          //       ),
          //       Text(
          //         memberData.session.user_status?.value ??
          //             UserSquadSessionStatus.alive.value,
          //         style: TextStyle(
          //           color: Colors.grey[600],
          //           fontSize: 14.0,
          //         ),
          //       ),
          //     ],
          //   ),
          //   Column(
          //     crossAxisAlignment: CrossAxisAlignment.end,
          //     children: [
          //       Text(
          //         'Direction: ${memberData.coordinates.direction}',
          //         style: TextStyle(
          //           color: Colors.grey[800],
          //           fontSize: 14.0,
          //         ),
          //       ),
          //       Text(
          //         'Distance: ${memberData.coordinates.distance} km',
          //         style: TextStyle(
          //           color: Colors.grey[800],
          //           fontSize: 14.0,
          //         ),
          //       ),
          //     ],
          //   ),
          // ],
        ),
      ),
    );
  }
}
