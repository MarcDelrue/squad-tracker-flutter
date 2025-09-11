import 'package:flutter/material.dart';
import 'dart:async';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/users_model.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:squad_tracker_flutter/widgets/invite_user_row.dart';
import 'package:squad_tracker_flutter/widgets/snack_bar.dart';
import 'package:squad_tracker_flutter/widgets/user_session_row.dart';

class SquadLobbyScreen extends StatefulWidget {
  const SquadLobbyScreen({super.key});

  @override
  SquadLobbyScreenState createState() => SquadLobbyScreenState();
}

class SquadLobbyScreenState extends State<SquadLobbyScreen> {
  final userService = UserService();
  final squadService = SquadService();
  final userSquadSessionService = UserSquadSessionService();
  final squadMembersService = SquadMembersService();
  final gameService = GameService();

  int? _activeGameId;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentSquadMembers();
    _loadActiveGame();
    _startGameMetaStream();
  }

  Future<void> _fetchCurrentSquadMembers() async {
    final squadId = squadService.currentSquad?.id;
    if (squadId != null) {
      await squadMembersService.getCurrentSquadMembers(
          userService.currentUser!.id, squadId);
    } else {
      return;
    }
  }

  Future<void> _loadActiveGame() async {
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr == null) return;
    final id = await gameService.getActiveGameId(int.parse(squadIdStr));
    if (mounted) setState(() => _activeGameId = id);
  }

  void _startGameMetaStream() {
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr == null) return;
    gameService
        .streamActiveGameMetaBySquad(int.parse(squadIdStr))
        .listen((meta) {
      if (!mounted) return;
      if (meta == null) {
        setState(() {
          _startedAt = null;
          _elapsed = Duration.zero;
          _ticker?.cancel();
          _ticker = null;
        });
        return;
      }
      final s = meta['started_at']?.toString();
      final start = s != null ? DateTime.tryParse(s) : null;
      setState(() {
        _activeGameId = (meta['id'] as num?)?.toInt();
        _startedAt = start;
      });
      _ensureTicker();
    });
  }

  void _ensureTicker() {
    if (_startedAt == null) return;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt!);
      });
    });
  }

  Future<void> _startGame() async {
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr == null) return;
    try {
      final id = await gameService.startGame(int.parse(squadIdStr));
      if (mounted) {
        setState(() => _activeGameId = id);
        context.showSnackBar('Game started');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to start game: $e', isError: true);
      }
    }
  }

  Future<void> _endGame() async {
    final squadIdStr = squadService.currentSquad?.id;
    if (squadIdStr == null) return;
    try {
      await gameService.endGame(int.parse(squadIdStr));
      if (mounted) {
        setState(() => _activeGameId = null);
        context.showSnackBar('Game ended');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to end game: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _kickUser(User user) async {
    final shouldKick = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Kick User'),
        content: Text('Are you sure you want to kick ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kick'),
          ),
        ],
      ),
    );

    if (shouldKick == true) {
      try {
        await squadMembersService.kickFromSquad(
            user.id, squadService.currentSquad!.id);
        // await _fetchCurrentSquadMembers();
      } catch (e) {
        debugPrint("Failed to kick user: $e");
        // Optionally show an error message to the user
        if (mounted) {
          context.showSnackBar('Failed to kick user: $e', isError: true);
        }
      }
    }
  }

  Future<void> _setUserAsHost(User user) async {
    final shouldSetHost = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Set Host'),
        content:
            Text('Are you sure you want to set ${user.username} as the host?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set Host'),
          ),
        ],
      ),
    );

    if (shouldSetHost == true) {
      try {
        await squadMembersService.setUserAsHost(userService.currentUser!.id,
            user.id, squadService.currentSquad!.id);
        // Refresh my session role flag
        await userSquadSessionService
            .getUserSquadSessionId(userService.currentUser!.id);
        if (mounted) {
          context.showSnackBar('Host transferred to ${user.username}');
        }
      } catch (e) {
        debugPrint("Failed to set user as host: $e");
        if (mounted) {
          context.showSnackBar('Failed to set user as host: $e', isError: true);
        }
      }
    }
  }

  Future<void> _confirmLeaveSquad() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Leave Squad'),
        content: const Text('Are you sure you want to leave the squad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      try {
        await userSquadSessionService.leaveSquad(
            userService.currentUser!.id, squadService.currentSquad!.id);
        // Optionally navigate to another screen or show a success message
      } catch (e) {
        // Handle any errors during the leave process
        if (mounted) {
          context.showSnackBar('Failed to leave squad: $e', isError: true);
        }
      }
    }
  }

  void _showEditNameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: squadService.currentSquad?.name,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Squad Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter new squad name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                squadService.updateSquadName(
                    squadService.currentSquad!.id, controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHost = userSquadSessionService.currentSquadSession?.is_host == true;

    return Scaffold(
      appBar: AppBar(
          title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ListenableBuilder(
            listenable: squadService,
            builder: (context, child) {
              return Text(squadService.currentSquad?.name ?? 'Squad Lobby');
            },
          ),
          if (isHost)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditNameDialog(context),
            ),
        ],
      )),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _activeGameId == null
                            ? 'No active game'
                            : 'Game active (#$_activeGameId)  –  ' +
                                _formatElapsed(_elapsed),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isHost)
                      if (_activeGameId == null)
                        ElevatedButton.icon(
                          onPressed: _startGame,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start game'),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _endGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.stop),
                          label: const Text('End game'),
                        ),
                  ],
                ),
              ),
            ),
            const Text(
              "Squad Members",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<UserWithSession>?>(
                stream: squadMembersService.currentSquadMembersStream,
                builder: (BuildContext context,
                    AsyncSnapshot<List<UserWithSession>?> snapshot) {
                  final currentMembers =
                      squadMembersService.currentSquadMembers;

                  if (currentMembers == null ||
                      userSquadSessionService.currentSquadSession == null ||
                      userService.currentUser == null) {
                    return const Center(child: Text('Loading...'));
                  }

                  final List<UserWithSession> squadMembers = [
                    ...currentMembers,
                  ];

                  return RefreshIndicator(
                      onRefresh: _fetchCurrentSquadMembers,
                      child: ListView.builder(
                          itemCount: squadMembers.length +
                              1, // +1 for the UserAddButton
                          itemBuilder: (context, index) {
                            if (index == squadMembers.length) {
                              // If it's the last item, show the UserAddButton
                              return UserAddButton(
                                  squad: squadService.currentSquad!);
                            }

                            final userWithSession = squadMembers[index];
                            final options = UserSquadSessionOptions(
                              is_host: userWithSession.session.is_host == true,
                              is_you: userService.currentUser!.id ==
                                  userWithSession.user.id,
                              can_interact: userSquadSessionService
                                          .currentSquadSession!.is_host ==
                                      true &&
                                  userService.currentUser!.id !=
                                      userWithSession.user.id,
                            );

                            return UserSessionRow(
                              user: userWithSession.user,
                              options: options,
                              onKickUser: _kickUser,
                              onSetHost: _setUserAsHost,
                            );
                          }));
                },
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: _confirmLeaveSquad,
                child: const Text("Leave Squad"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
