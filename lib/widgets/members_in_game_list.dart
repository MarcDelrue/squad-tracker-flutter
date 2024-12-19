import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_with_location_session_model.dart';
import 'package:squad_tracker_flutter/providers/combined_stream_service.dart';
import 'package:squad_tracker_flutter/widgets/member_in_game_row.dart';

class MembersInGameList extends StatelessWidget {
  final CombinedStreamService combinedStreamService;

  const MembersInGameList({
    super.key,
    required this.combinedStreamService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserWithLocationSession>>(
      stream:
          combinedStreamService.combinedStream?.map((event) => event ?? []) ??
              const Stream.empty(),
      builder: (BuildContext context,
          AsyncSnapshot<List<UserWithLocationSession>> snapshot) {
        if (snapshot.hasData) {
          return Expanded(
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final member = snapshot.data![index];
                return MemberInGameRow(
                  name: member.userWithSession.user.username,
                  status: member.userWithSession.session.user_status,
                  latitude: member.location?.latitude?.toDouble(),
                  longitude: member.location?.longitude?.toDouble(),
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
