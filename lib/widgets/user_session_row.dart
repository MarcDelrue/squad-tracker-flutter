import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';

class UserSessionRow extends StatelessWidget {
  final User user;
  final UserSquadSessionOptions options;
  final Function(User) onKickUser;
  final Function(User) onSetHost;

  const UserSessionRow({
    super.key,
    required this.user,
    required this.options,
    required this.onKickUser,
    required this.onSetHost,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hexToColor(user.main_color ?? ''),
          ),
        ),
        title: Text(
          options.is_you
              ? '${user.username ?? ''} (you)'
              : (user.username ?? ''),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(user.main_role!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (options.is_host)
              const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
              ),
            if (options.is_you)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {},
              ),
            if (options.can_interact)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'kick') {
                    onKickUser(user);
                  } else if (value == 'setHost') {
                    onSetHost(user);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'kick',
                    child: Text('Kick User'),
                  ),
                  const PopupMenuItem(
                    value: 'setHost',
                    child: Text('Set as Host'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
