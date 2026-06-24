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
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Forespectra',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
