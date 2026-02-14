import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../theme/app_theme.dart';
import 'acquire_screen.dart';
import 'connect_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _screens = const [
    ConnectScreen(),
    AcquireScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final gradient = AppTheme.backgroundGradient(Theme.of(context).brightness);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: false,
            body: _screens[state.currentTab],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).navigationBarTheme.backgroundColor,
                border: const Border(
                  top: BorderSide(color: Color(0x14000000)),
                ),
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                indicatorColor: Theme.of(context).navigationBarTheme.indicatorColor,
                height: 64,
                selectedIndex: state.currentTab,
                onDestinationSelected: (value) {
                  if (!state.isConnected && value == 1) return;
                  state.setTab(value);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.power_settings_new),
                    label: 'Connect',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.auto_graph),
                    label: 'Scan',
                    enabled: state.isConnected,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.history),
                    label: 'History',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.tune),
                    label: 'Config',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
