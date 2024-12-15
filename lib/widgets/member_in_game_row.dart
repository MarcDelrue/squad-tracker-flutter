import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';

class MemberInGameRow extends StatelessWidget {
  final String? name;
  final UserSquadSessionStatus? status;

  const MemberInGameRow({
    super.key,
    this.name,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name ?? 'No Name'),
        subtitle: Text(status?.value ?? 'No Status'),
        onTap: () {
          print('Member Name: $name');
          print('Status: $status');
        },
      ),
    );
  }
}
