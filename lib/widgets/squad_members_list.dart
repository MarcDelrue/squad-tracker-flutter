import 'dart:async';

import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
// colors_option not used here anymore after extracting MemberTile
import 'package:squad_tracker_flutter/utils/member_sort.dart';
import 'package:squad_tracker_flutter/widgets/members/member_tile.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';
// supabase import not used here anymore; removed

class SquadMembersList extends StatefulWidget {
  final VoidCallback?
      onFlyToMember; // Callback to hide bottom sheet when flying to member

  const SquadMembersList({super.key, this.onFlyToMember});

  @override
  State<SquadMembersList> createState() => _SquadMembersListState();
}

class _SquadMembersListState extends State<SquadMembersList> {
  final userService = UserService();
  final squadMembersService = SquadMembersService();
  final userSquadLocationService = UserSquadLocationService();
  final mapUserLocationService = MapUserLocationService();
  final squadService = SquadService();
  final gameService = GameService();

  StreamSubscription<List<Map<String, dynamic>>>? _scoreboardSub;
  StreamSubscription<Map<String, dynamic>?>? _gameMetaSub;
  int? _activeGameId;
  // user_id -> {kills, deaths}
  Map<String, Map<String, int>> _statsByUserId = {};
  // user_id -> status (from user_game_stats)
  Map<String, UserSquadSessionStatus?> _statusByUserId = {};
  // sort modes: 'distance', 'kills', 'kd' (alias: 'score' -> 'kd')
  String _sortMode = 'distance';

  @override
  void initState() {
    super.initState();
    // Ensure squad members are loaded when widget initializes
    _loadSquadMembers();
    _subscribeScoreboard();
    _subscribeGameChanges();
  }

  @override
  void dispose() {
    _scoreboardSub?.cancel();
    _gameMetaSub?.cancel();
    super.dispose();
  }

  Future<void> _subscribeScoreboard() async {
    final currentSquad = squadService.currentSquad;
    if (currentSquad == null) return;
    final gameId =
        await gameService.getActiveGameId(int.parse(currentSquad.id));
    if (!mounted) return;
    setState(() => _activeGameId = gameId);
    _scoreboardSub?.cancel();
    if (gameId != null) {
      _scoreboardSub =
          gameService.streamScoreboardByGame(gameId).listen((rows) {
        final map = <String, Map<String, int>>{};
        final statusMap = <String, UserSquadSessionStatus?>{};
        for (final r in rows) {
          final userId = r['user_id'] as String?;
          if (userId == null) continue;
          final kills = (r['kills'] as num? ?? 0).toInt();
          final deaths = (r['deaths'] as num? ?? 0).toInt();
          map[userId] = {'kills': kills, 'deaths': deaths};
          final s = r['user_status'];
          if (s is String) {
            try {
              statusMap[userId] = UserSquadSessionStatusExtension.fromValue(s);
            } catch (_) {
              statusMap[userId] = null;
            }
          }
        }
        if (mounted) {
          setState(() {
            _statsByUserId = map;
            _statusByUserId = statusMap;
          });
        }
      });
    }
  }

  void _subscribeGameChanges() {
    final currentSquad = squadService.currentSquad;
    if (currentSquad == null) return;
    _gameMetaSub?.cancel();
    _gameMetaSub = gameService
        .streamActiveGameMetaBySquad(int.parse(currentSquad.id))
        .listen((meta) async {
      final newId = (meta == null) ? null : (meta['id'] as num?)?.toInt();
      if (newId == _activeGameId) return;
      // Only reset when a new game starts. If game ended (newId == null), keep last scoreboard visible.
      if (newId == null) {
        _activeGameId = null;
        return;
      }
      // Clear local stats and resubscribe to scoreboard for the new game
      if (mounted) {
        setState(() {
          _statsByUserId = {};
          _statusByUserId = {};
          _activeGameId = newId;
        });
      }
      await _scoreboardSub?.cancel();
      _scoreboardSub = null;
      {
        _scoreboardSub =
            gameService.streamScoreboardByGame(newId).listen((rows) {
          final map = <String, Map<String, int>>{};
          final statusMap = <String, UserSquadSessionStatus?>{};
          for (final r in rows) {
            final userId = r['user_id'] as String?;
            if (userId == null) continue;
            final kills = (r['kills'] as num? ?? 0).toInt();
            final deaths = (r['deaths'] as num? ?? 0).toInt();
            map[userId] = {'kills': kills, 'deaths': deaths};
            final s = r['user_status'];
            if (s is String) {
              try {
                statusMap[userId] =
                    UserSquadSessionStatusExtension.fromValue(s);
              } catch (_) {
                statusMap[userId] = null;
              }
            }
          }
          if (mounted) {
            setState(() {
              _statsByUserId = map;
              _statusByUserId = statusMap;
            });
          }
        });
      }
    });
  }

  Future<void> _loadSquadMembers() async {
    final currentUser = userService.currentUser;
    final currentSquad = squadService.currentSquad;

    if (currentUser != null && currentSquad != null) {
      try {
        await squadMembersService.getCurrentSquadMembers(
            currentUser.id, currentSquad.id);
      } catch (e) {
        // Handle error silently or log to proper logging service
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserWithSession>?>(
      stream: squadMembersService.currentSquadMembersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.loading,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadSquadMembers,
                  child: Text(AppLocalizations.of(context)!.retry),
                ),
              ],
            ),
          );
        }

        // Check if we have an error or no data after waiting
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading squad members: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.noRecentSquads,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final members = snapshot.data!;
        // Include everyone, but show '(you)' on the current user
        final otherMembers = [...members];

        // Sort
        if (_sortMode == 'distance') {
          sortByDistance(otherMembers,
              userSquadLocationService.currentMembersDistanceFromUser);
        } else if (_sortMode == 'kills') {
          sortByKills(otherMembers, _statsByUserId);
        } else {
          sortByKd(otherMembers, _statsByUserId);
        }

        if (otherMembers.isEmpty) {
          return const Center(
            child: Text(
              'You are the only member in the squad',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Squad Members (${otherMembers.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_activeGameId != null || _statsByUserId.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_sortMode == 'distance') {
                            _sortMode = 'kills';
                          } else if (_sortMode == 'kills') {
                            _sortMode = 'kd';
                          } else {
                            _sortMode = 'distance';
                          }
                        });
                      },
                      icon: Icon(
                        _sortMode == 'distance'
                            ? Icons.social_distance
                            : (_sortMode == 'kills'
                                ? Icons.sports_martial_arts
                                : Icons.leaderboard),
                        color: Colors.white,
                      ),
                      label: Text(
                        _sortMode == 'distance'
                            ? 'Distance'
                            : (_sortMode == 'kills' ? 'Kills' : 'K/D'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            // Member tiles
            ...otherMembers.map((member) => _buildMemberTile(member)),
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(UserWithSession member) {
    final memberLocation = userSquadLocationService.currentMembersLocation
        ?.where((location) => location.user_id == member.user.id)
        .firstOrNull;
    final isSelf = member.user.id == userService.currentUser?.id;
    final distances = userSquadLocationService.currentMembersDistanceFromUser;
    final directions = userSquadLocationService.currentMembersDirectionToMember;
    final distance = distances != null ? distances[member.user.id] : null;
    final direction = directions != null ? directions[member.user.id] : null;
    final effectiveStatus =
        _statusByUserId[member.user.id] ?? member.session.user_status;
    final stats = _statsByUserId[member.user.id];
    final kills = (stats?['kills'] ?? 0);
    final deaths = (stats?['deaths'] ?? 0);

    final props = MemberTileProps(
      kills: kills,
      deaths: deaths,
      distanceMeters: distance,
      directionDegrees: direction,
      effectiveStatus: effectiveStatus,
    );

    return MemberTile(
      member: member,
      props: props,
      memberLocation: memberLocation,
      isSelf: isSelf,
      mapUserLocationService: mapUserLocationService,
      userService: userService,
      onFlyToMember: widget.onFlyToMember,
    );
  }

  // Avatar moved inside MemberTile and all UI helpers extracted.
}

// Connectivity dot has been extracted to widgets/common/connectivity_dot.dart
