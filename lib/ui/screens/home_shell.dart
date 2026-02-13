import 'dart:ui';

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
        final brightness = Theme.of(context).brightness;
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
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE9E5E4),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFD1C8C4),
                      ),
                    ),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      indicatorColor: brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0x26D73F09),
                      height: 68,
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
              ),
            ),
          ),
        );
      },
    );
  }
}
