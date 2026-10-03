import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/admin_home.dart';
import 'screens/auth_screens.dart';
import 'screens/citizen_home.dart';
import 'screens/officer_home.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  runApp(const CityPulseApp());
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: brandTeal, brightness: b);
  final light = b == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? const Color(0xFFF3F6F5) : const Color(0xFF0E1514),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: light ? const Color(0xFFF3F6F5) : const Color(0xFF0E1514),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class CityPulseApp extends StatelessWidget {
  const CityPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'CityPulse',
        debugShowCheckedModeBanner: false,
        themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const RootGate(),
      ),
    );
  }
}

/// Shows the login screen or the correct home screen for the signed-in role.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final u = store.current;
        if (u == null) return const LoginScreen();
        return switch (u.role) {
          UserRole.citizen => CitizenHome(key: ValueKey(u.id)),
          UserRole.officer => OfficerHome(key: ValueKey(u.id)),
          UserRole.admin => AdminHome(key: ValueKey(u.id)),
        };
      },
    );
  }
}
