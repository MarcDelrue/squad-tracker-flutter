import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/roles_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/screens/map_with_location.dart';
import 'package:squad_tracker_flutter/screens/tracker/tracker_screen.dart';
import 'package:squad_tracker_flutter/screens/squads/squads_entrypoint.dart';
import 'package:squad_tracker_flutter/screens/user/user_screen.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:provider/provider.dart';

class NavigationWidget extends StatefulWidget {
  const NavigationWidget({super.key});

  @override
  State<NavigationWidget> createState() => _NavigationWidgetState();
}

class _NavigationWidgetState extends State<NavigationWidget> {
  int currentPageIndex = 0;
  final userService = UserService();
  final squadService = SquadService();
  final rolesService = RolesService();
  Future<void>? _future;

  void onDestinationSelected(int index) {
    setState(() {
      currentPageIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<void> _loadData() async {
    await userService.setUserInfo();
    await squadService.setCurrentSquad(userId: userService.currentUser!.id);
    await rolesService.getAndStoreRoles();
    squadService.listenToUserSquadSession(userService.currentUser!.id);
  }

  @override

  /// Builds the main navigation widget.
  ///
  /// This widget uses a [FutureBuilder] to wait for the user's information to be
  /// loaded. Once the information is loaded, it displays a [Scaffold] with a
  /// [NavigationBar] at the bottom. The navigation bar has three destinations:
  /// 'User', 'Squads', and 'Map'. The 'User' destination always shows the
  /// [UserScreen]. The 'Squads' destination shows the [SquadsEntrypoint] if the
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return ListenableBuilder(
              listenable: userService,
              builder: (BuildContext context, Widget? child) {
                bool hasBasicInfo = userService.hasBasicInfo();
                return Scaffold(
                  bottomNavigationBar: NavigationBar(
                    onDestinationSelected: onDestinationSelected,
                    indicatorColor: Colors.green,
                    selectedIndex: currentPageIndex,
                    destinations: <Widget>[
                      const NavigationDestination(
                        icon: Icon(Icons.person),
                        label: 'User',
                      ),
                      NavigationDestination(
                        icon: ListenableBuilder(
                          listenable: squadService,
                          builder: (context, child) {
                            return squadService.currentSquad != null
                                ? const Badge(
                                    backgroundColor: Colors.green,
                                    child: Icon(Icons.group))
                                : const Icon(Icons.group);
                          },
                        ),
                        label: 'Squads',
                        tooltip: hasBasicInfo
                            ? null
                            : 'Complete your profile to access Squads',
                        enabled: hasBasicInfo,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.map),
                        label: 'Map',
                        tooltip: hasBasicInfo
                            ? null
                            : 'Complete your profile to access Map',
                        enabled: hasBasicInfo,
                      ),
                      NavigationDestination(
                        icon: Consumer<BleService>(
                            builder: (context, bleService, _) {
                          final bool isBleConnected =
                              bleService.connectedDevice != null;
                          return isBleConnected
                              ? const Badge(
                                  backgroundColor: Colors.green,
                                  child: Icon(Icons.track_changes_rounded),
                                )
                              : const Icon(Icons.track_changes_rounded);
                        }),
                        label: 'Tracker',
                        tooltip: hasBasicInfo
                            ? null
                            : 'Complete your profile to access Tracker',
                        enabled: hasBasicInfo,
                      )
                    ],
                  ),
                  body: IndexedStack(
                    index: currentPageIndex,
                    children: const <Widget>[
                      UserScreen(),
                      SquadsEntrypoint(),
                      MapWithLocation(),
                      TrackerScreen(),
                    ],
                  ),
                );
              });
        }
      },
    );
  }
}
