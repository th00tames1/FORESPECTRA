import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/app_state.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

class SpectralApp extends StatelessWidget {
  const SpectralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..initialize()),
      ],
      child: MaterialApp(
        title: 'OSU Spectral',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
