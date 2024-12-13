import 'dart:async';

import 'package:squad_tracker_flutter/models/member_in_game_model.dart';

class MembersInGameService {
  // Singleton setup
  static final MembersInGameService _singleton =
      MembersInGameService._internal();
  factory MembersInGameService() => _singleton;
  MembersInGameService._internal();

  final _membersDataController =
      StreamController<List<MemberInGame>>.broadcast();
  Stream<List<MemberInGame>> get membersDataStream =>
      _membersDataController.stream;

  void updateMembersData(List<MemberInGame> newData) {
    _membersDataController.add(newData);
  }

  // void _updateMembersData(currentUserLocation, currentMembersLocation) {
  //   if (currentUserLocation == null || currentMembersLocation == null) return;

  //   List<MemberInGame> updatedData = currentMembersLocation!.map((member) {
  //     double distance = _calculateDistance(currentUserLocation!, member);
  //     double direction = _calculateDirection(currentUserLocation!, member);

  //     return MemberInGame(
  //       id: member.userId,
  //       name: member.username ?? 'Unknown',
  //       status: member.status ?? 'Unknown',
  //       distance: distance,
  //       direction: direction,
  //       lastUpdated: DateTime.now(),
  //     );
  //   }).toList();

  //   updateMembersData(updatedData);
  // }
}
