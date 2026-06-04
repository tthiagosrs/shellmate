import 'package:flutter/material.dart';

import '../core/server/server_manager.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_notifier.dart';
import '../features/splash/presentation/splash_screen.dart';

class ShellmateApp extends StatefulWidget {
  const ShellmateApp({super.key});

  @override
  State<ShellmateApp> createState() => _ShellmateAppState();
}

class _ShellmateAppState extends State<ShellmateApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopServer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) stopServer();
  }

  ThemeData _buildTheme(bool isDark) {
    final c = isDark ? AppColors.dark : AppColors.light;
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: c.bgSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        foregroundColor: c.text1,
        iconTheme: IconThemeData(color: c.text2),
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.bgSurface),
      popupMenuTheme: PopupMenuThemeData(
        color: c.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
      ),
      iconTheme: IconThemeData(color: c.text2),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: c.text1, fontSize: 14),
        bodyMedium: TextStyle(color: c.text2, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Shellmate',
          theme: _buildTheme(isDark),
          home: const SplashScreen(),
        );
      },
    );
  }
}
