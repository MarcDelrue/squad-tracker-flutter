import 'dart:async';

import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/models/user_squad_location_model.dart';
import 'package:squad_tracker_flutter/models/user_with_session_model.dart';
import 'package:squad_tracker_flutter/models/squad_session_model.dart';
import 'package:squad_tracker_flutter/providers/map_user_location_service.dart';
import 'package:squad_tracker_flutter/providers/squad_members_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_location_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/game_service.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';

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
  int? _activeGameId;
  // user_id -> {kills, deaths}
  Map<String, Map<String, int>> _statsByUserId = {};
  // user_id -> status (from user_game_stats)
  Map<String, UserSquadSessionStatus?> _statusByUserId = {};
  // distance or score
  String _sortMode = 'distance';

  @override
  void initState() {
    super.initState();
    // Ensure squad members are loaded when widget initializes
    _loadSquadMembers();
    _subscribeScoreboard();
  }

  @override
  void dispose() {
    _scoreboardSub?.cancel();
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

  Future<void> _loadSquadMembers() async {
    final currentUser = userService.currentUser;
    final currentSquad = squadService.currentSquad;

    if (currentUser != null && currentSquad != null) {
      debugPrint(
          'Loading squad members for user: ${currentUser.id}, squad: ${currentSquad.id}');
      try {
        await squadMembersService.getCurrentSquadMembers(
            currentUser.id, currentSquad.id);
        debugPrint('Squad members loaded successfully');
      } catch (e) {
        debugPrint('Error loading squad members: $e');
      }
    } else {
      debugPrint(
          'Cannot load squad members - user: ${currentUser?.id}, squad: ${currentSquad?.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserWithSession>?>(
      stream: squadMembersService.currentSquadMembersStream,
      builder: (context, snapshot) {
        // Debug information
        debugPrint(
            'SquadMembersList - Stream state: ${snapshot.connectionState}');
        debugPrint('SquadMembersList - Has data: ${snapshot.hasData}');
        debugPrint('SquadMembersList - Data: ${snapshot.data}');
        debugPrint(
            'SquadMembersList - Current squad members: ${squadMembersService.currentSquadMembers}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Loading squad members...',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadSquadMembers,
                  child: const Text('Retry'),
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
          return const Center(
            child: Text(
              'No squad members found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final members = snapshot.data!;
        // Include everyone, but show '(you)' on the current user
        final otherMembers = [...members];

        // Sort
        if (_sortMode == 'distance') {
          otherMembers.sort((a, b) {
            final distances =
                userSquadLocationService.currentMembersDistanceFromUser;
            final distanceA = distances != null
                ? (distances[a.user.id] ?? double.infinity)
                : double.infinity;
            final distanceB = distances != null
                ? (distances[b.user.id] ?? double.infinity)
                : double.infinity;
            return distanceA.compareTo(distanceB);
          });
        } else if (_sortMode == 'score') {
          otherMembers.sort((a, b) {
            final sa = _statsByUserId[a.user.id];
            final sb = _statsByUserId[b.user.id];
            final ka = (sa?['kills'] ?? 0);
            final kb = (sb?['kills'] ?? 0);
            final da = (sa?['deaths'] ?? 0);
            final db = (sb?['deaths'] ?? 0);
            final kda = da == 0 ? ka.toDouble() : ka / da;
            final kdb = db == 0 ? kb.toDouble() : kb / db;
            if (kdb != kda) return kdb.compareTo(kda);
            if (kb != ka) return kb.compareTo(ka);
            return da.compareTo(db);
          });
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
                  if (_activeGameId != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _sortMode =
                              _sortMode == 'distance' ? 'score' : 'distance';
                        });
                      },
                      icon: Icon(
                        _sortMode == 'distance'
                            ? Icons.social_distance
                            : Icons.leaderboard,
                        color: Colors.white,
                      ),
                      label: Text(
                        _sortMode == 'distance' ? 'Distance' : 'Score',
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

    final memberColor = hexToColor(member.user.main_color ?? '#000000');
    final effectiveStatus =
        _statusByUserId[member.user.id] ?? member.session.user_status;
    final statusColor = _getStatusColor(effectiveStatus);

    final stats = _statsByUserId[member.user.id];
    final kills = (stats?['kills'] ?? 0);
    final deaths = (stats?['deaths'] ?? 0);
    final kd = deaths == 0 ? kills.toDouble() : kills / deaths;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: memberColor, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildMemberAvatar(member, memberColor),
        title: Row(
          children: [
            Expanded(
              child: Text(
                (member.user.id == userService.currentUser?.id)
                    ? '${member.user.username ?? 'Unknown'} (you)'
                    : (member.user.username ?? 'Unknown'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusText(effectiveStatus),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSelf && distance != null)
              Text(
                'Distance: ${distance.toStringAsFixed(0)}m',
                style: const TextStyle(color: Colors.grey),
              ),
            if (!isSelf && direction != null)
              Text(
                'Direction: ${_getDirectionText(direction)}',
                style: const TextStyle(color: Colors.grey),
              ),
            if (_activeGameId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.sports_martial_arts,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text('$kills',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    const Icon(Icons.heart_broken,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text('$deaths',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    Text('K/D ${kd.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.location_on,
            color: memberColor,
          ),
          onPressed: () => _flyToMember(memberLocation),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(UserWithSession member, Color memberColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: memberColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          (member.user.username ?? '?')[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return Colors.green;
      case UserSquadSessionStatus.dead:
        return Colors.red;
      case UserSquadSessionStatus.help:
        return Colors.orange;
      case UserSquadSessionStatus.medic:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(UserSquadSessionStatus? status) {
    switch (status) {
      case UserSquadSessionStatus.alive:
        return 'ALIVE';
      case UserSquadSessionStatus.dead:
        return 'DEAD';
      case UserSquadSessionStatus.help:
        return 'HELP';
      case UserSquadSessionStatus.medic:
        return 'MEDIC';
      default:
        return 'UNKNOWN';
    }
  }

  void _flyToMember(UserSquadLocation? memberLocation) {
    if (memberLocation != null &&
        memberLocation.latitude != null &&
        memberLocation.longitude != null) {
      mapUserLocationService.flyToLocation(
        memberLocation.longitude!,
        memberLocation.latitude!,
      );
      // Hide bottom sheet when flying to member
      widget.onFlyToMember?.call();
    }
  }

  String _getDirectionText(double direction) {
    if (direction >= 337.5 || direction < 22.5) return 'N';
    if (direction >= 22.5 && direction < 67.5) return 'NE';
    if (direction >= 67.5 && direction < 112.5) return 'E';
    if (direction >= 112.5 && direction < 157.5) return 'SE';
    if (direction >= 157.5 && direction < 202.5) return 'S';
    if (direction >= 202.5 && direction < 247.5) return 'SW';
    if (direction >= 247.5 && direction < 292.5) return 'W';
    if (direction >= 292.5 && direction < 337.5) return 'NW';
    return 'N';
  }
}
