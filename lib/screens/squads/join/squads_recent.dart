import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/squad_model.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:squad_tracker_flutter/widgets/snack_bar.dart';
import 'package:intl/intl.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';

class SquadsRecentList extends StatefulWidget {
  const SquadsRecentList({super.key});

  @override
  State<SquadsRecentList> createState() => _SquadsRecentListState();
}

class _SquadsRecentListState extends State<SquadsRecentList> {
  final SquadService squadService = SquadService();
  final UserSquadSessionService userSquadSessionService =
      UserSquadSessionService();
  final UserService userService = UserService();
  List<SquadWithUpdatedAt>? recentSquads = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentSquads();
  }

  Future<void> _fetchRecentSquads() async {
    try {
      final squads =
          await squadService.getRecentSquads(userService.currentUser!.id);
      setState(() {
        recentSquads = squads;
      });
    } catch (e) {
      // Handle any errors during the fetch process
      if (mounted) {
        context.showSnackBar('Failed to fetch recent squads: $e',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.recentSquadsTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: recentSquads == null || recentSquads!.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context)!.noRecentSquads))
              : ListView.builder(
                  itemCount: recentSquads!.length,
                  itemBuilder: (context, index) {
                    final squad = recentSquads![index];
                    final DateFormat formatter =
                        DateFormat('yyyy-MM-dd – kk:mm');
                    final String formattedDate =
                        formatter.format(squad.updatedAt);

                    return ListTile(
                      title: Text(squad.name),
                      subtitle: Text(
                          '${AppLocalizations.of(context)!.lastJoinedPrefix}$formattedDate'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // Add your join logic here
                          _joinSquad(squad);
                        },
                        child: Text(AppLocalizations.of(context)!.join),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _joinSquad(Squad squad) async {
    try {
      final success = await userSquadSessionService.joinSquad(
          userService.currentUser!.id, squad.id);
      if (success) {
        if (mounted) {
          context.showSnackBar('Joined squad successfully!');
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          context.showSnackBar('Failed to join squad', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    }
  }
}
