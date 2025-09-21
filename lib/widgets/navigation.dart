import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/roles_service.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/screens/map_with_location.dart';
import 'package:squad_tracker_flutter/screens/tracker/tracker_screen.dart';
import 'package:squad_tracker_flutter/screens/squads/squads_entrypoint.dart';
import 'package:squad_tracker_flutter/screens/user/user_screen.dart';
import 'package:squad_tracker_flutter/providers/ble_service.dart';
import 'package:squad_tracker_flutter/providers/help_notification_service.dart';
import 'package:squad_tracker_flutter/widgets/help_banner.dart';
import 'package:provider/provider.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class NavigationWidget extends StatefulWidget {
  const NavigationWidget({super.key});

  // Global access to switch tabs from anywhere in the widget tree
  static final GlobalKey<_NavigationWidgetState> globalKey =
      GlobalKey<_NavigationWidgetState>();

  static void goToTab(int index) {
    globalKey.currentState?.onDestinationSelected(index);
  }

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

    // Start BLE auto-reconnect in background without blocking UI
    _startBleAutoReconnect();

    // Attach help notifications after squad is resolved; listener follows active game
    try {
      await HelpNotificationService().startListening(context);
    } catch (e) {
      debugPrint('Help notifications attach failed: $e');
    }
  }

  void _startBleAutoReconnect() {
    final uid = userService.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      // Run BLE auto-reconnect in background without awaiting
      Provider.of<BleService>(context, listen: false)
          .tryAutoReconnect(uid)
          .catchError((error) {
        // Silently handle errors in background
        debugPrint('BLE auto-reconnect failed: $error');
      });
    }
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
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Stack(
                    children: [
                      IndexedStack(
                        index: currentPageIndex,
                        children: const <Widget>[
                          UserScreen(),
                          SquadsEntrypoint(),
                          MapWithLocation(),
                          TrackerScreen(),
                        ],
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: HelpBanner(),
                      ),
                    ],
                  ),
                  bottomNavigationBar: NavigationBar(
                    onDestinationSelected: onDestinationSelected,
                    indicatorColor: Colors.green,
                    selectedIndex: currentPageIndex,
                    destinations: <Widget>[
                      NavigationDestination(
                        icon: const Icon(Icons.person),
                        label: l10n.tabUser,
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
                        label: l10n.tabSquads,
                        tooltip: hasBasicInfo
                            ? null
                            : l10n.tooltipCompleteProfileSquads,
                        enabled: hasBasicInfo,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.map),
                        label: l10n.tabMap,
                        tooltip: hasBasicInfo
                            ? null
                            : l10n.tooltipCompleteProfileMap,
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
                        label: l10n.tabTracker,
                        tooltip: hasBasicInfo
                            ? null
                            : l10n.tooltipCompleteProfileTracker,
                        enabled: hasBasicInfo,
                      )
                    ],
                  ),
                );
              });
        }
      },
    );
  }
}
