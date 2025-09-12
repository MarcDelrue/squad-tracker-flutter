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
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

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
  bool? _prevIsHost;
  // Inline squad name editing state
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  Timer? _nameSaveDebounce;
  bool _isEditingName = false;
  bool _isSavingName = false;

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
    // Track host status changes to update UI and show snackbars
    _prevIsHost = userSquadSessionService.currentSquadSession?.is_host == true;
    userSquadSessionService.addListener(_onSessionChanged);
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
        context.showSnackBar(AppLocalizations.of(context)!.gameStarted);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
            AppLocalizations.of(context)!.failedToStartGame(e.toString()),
            isError: true);
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
        context.showSnackBar(AppLocalizations.of(context)!.gameEnded);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
            AppLocalizations.of(context)!.failedToEndGame(e.toString()),
            isError: true);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    userSquadSessionService.removeListener(_onSessionChanged);
    _nameSaveDebounce?.cancel();
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final bool isHostNow =
        userSquadSessionService.currentSquadSession?.is_host == true;
    if (_prevIsHost == null) {
      _prevIsHost = isHostNow;
      return;
    }
    if (_prevIsHost != isHostNow) {
      if (mounted) {
        setState(() {});
        context.showSnackBar(
          isHostNow
              ? AppLocalizations.of(context)!.youAreNowHost
              : AppLocalizations.of(context)!.youAreNoLongerHost,
          isError: !isHostNow,
        );
        // If we lost host while editing, exit edit mode
        if (!isHostNow && _isEditingName) {
          _isEditingName = false;
        }
      }
      _prevIsHost = isHostNow;
    }
  }

  Future<void> _kickUser(User user) async {
    final shouldKick = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmKickUserTitle),
        content: Text(AppLocalizations.of(context)!
            .confirmKickUserBody(user.username ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.kick),
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
          context.showSnackBar(
              AppLocalizations.of(context)!.failedToKickUser(e.toString()),
              isError: true);
        }
      }
    }
  }

  Future<void> _setUserAsHost(User user) async {
    final shouldSetHost = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmSetHostTitle),
        content: Text(AppLocalizations.of(context)!
            .confirmSetHostBody(user.username ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.setHost),
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
          context.showSnackBar(AppLocalizations.of(context)!
              .hostTransferredTo(user.username ?? ''));
        }
      } catch (e) {
        debugPrint("Failed to set user as host: $e");
        if (mounted) {
          context.showSnackBar(
              AppLocalizations.of(context)!.failedToSetHost(e.toString()),
              isError: true);
        }
      }
    }
  }

  Future<void> _confirmLeaveSquad() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmLeaveSquadTitle),
        content: Text(AppLocalizations.of(context)!.confirmLeaveSquadBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.leave),
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
          context.showSnackBar(
              AppLocalizations.of(context)!.failedToLeaveSquad(e.toString()),
              isError: true);
        }
      }
    }
  }

  // --- Inline squad name editing helpers ---
  void _startEditingName() {
    final currentName = squadService.currentSquad?.name ?? '';
    setState(() {
      _isEditingName = true;
      _nameController.text = currentName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_nameFocus.hasFocus) {
        _nameFocus.requestFocus();
        _nameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _nameController.text.length,
        );
      }
    });
  }

  void _cancelEditingName() {
    setState(() {
      _isEditingName = false;
    });
  }

  void _scheduleDelayedSave() {
    _nameSaveDebounce?.cancel();
    _nameSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveName();
    });
  }

  Future<void> _saveName({bool showFeedback = false}) async {
    if (_isSavingName) return;
    final newName = _nameController.text.trim();
    final currentName = (squadService.currentSquad?.name ?? '').trim();
    if (newName.isEmpty || newName == currentName) return;
    setState(() {
      _isSavingName = true;
    });
    try {
      await squadService.updateSquadName(
          squadService.currentSquad!.id, newName);
      if (mounted && showFeedback) {
        context.showSnackBar('Squad renamed');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to rename squad: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = userSquadSessionService.currentSquadSession?.is_host == true;

    return Scaffold(
      appBar: AppBar(
          title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: squadService,
              builder: (context, child) {
                if (_isEditingName && isHost) {
                  return TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    onChanged: (_) => _scheduleDelayedSave(),
                    onSubmitted: (_) async {
                      await _saveName(showFeedback: true);
                      if (mounted) {
                        setState(() => _isEditingName = false);
                      }
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context)!.squadNameHint,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  );
                }
                return Text(squadService.currentSquad?.name ??
                    AppLocalizations.of(context)!.squadLobby);
              },
            ),
          ),
          if (isHost)
            if (_isEditingName)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSavingName)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      await _saveName(showFeedback: true);
                      if (mounted) {
                        setState(() => _isEditingName = false);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelEditingName,
                  ),
                ],
              )
            else
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _startEditingName,
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
                            ? AppLocalizations.of(context)!.noActiveGame
                            : 'Game active (#$_activeGameId)  –  ${_formatElapsed(_elapsed)}',
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
                          label: Text(AppLocalizations.of(context)!.startGame),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _endGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.stop),
                          label: Text(AppLocalizations.of(context)!.endGame),
                        ),
                  ],
                ),
              ),
            ),
            Text(
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
                    return Center(
                        child: Text(AppLocalizations.of(context)!.loading));
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
                child: Text(AppLocalizations.of(context)!.leaveSquad),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
