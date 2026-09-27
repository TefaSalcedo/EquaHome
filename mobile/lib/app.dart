import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_system/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';
import 'features/household/household_setup_screen.dart';
import 'features/household/households_controller.dart';

class EquaHomeApp extends StatelessWidget {
  const EquaHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EquaHome',
      debugShowCheckedModeBanner: false,
      theme: buildEquaTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Decide qué pantalla mostrar según sesión y hogares del usuario.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isLoading && !auth.hasValue) {
      return const _Splash();
    }
    if (auth.value == null) {
      return const AuthScreen();
    }
    final households = ref.watch(householdsControllerProvider);
    if (households.isLoading && !households.hasValue) {
      return const _Splash();
    }
    final list = households.value ?? const [];
    if (list.isEmpty) {
      return const HouseholdSetupScreen();
    }
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EquaHome',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
