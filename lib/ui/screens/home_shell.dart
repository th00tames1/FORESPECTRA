import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/i18n.dart';
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
                  // Scan tab while disconnected: count taps toward the hidden
                  // developer test-mode unlock instead of navigating.
                  if (value == 1 && !state.isConnected && !state.testMode) {
                    state.registerScanTabTap();
                    return;
                  }
                  state.setTab(value);
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.power_settings_new),
                    label: t('nav.connect'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.auto_graph),
                    label: t('nav.scan'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.history),
                    label: t('nav.history'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.tune),
                    label: t('nav.config'),
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
