import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'acquire_screen.dart';
import 'analyze_screen.dart';
import 'connect_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    ConnectScreen(),
    AcquireScreen(),
    AnalyzeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.backgroundGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: _screens[_index],
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  indicatorColor: Colors.white.withValues(alpha: 0.12),
                  height: 68,
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.power_settings_new), label: 'Connect'),
                    NavigationDestination(icon: Icon(Icons.auto_graph), label: 'Scan'),
                    NavigationDestination(icon: Icon(Icons.insights), label: 'Results'),
                    NavigationDestination(icon: Icon(Icons.history), label: 'History'),
                    NavigationDestination(icon: Icon(Icons.tune), label: 'Config'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
