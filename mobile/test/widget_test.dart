import 'package:equahome/design_system/theme.dart';
import 'package:equahome/features/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AuthScreen muestra login por defecto', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildEquaTheme(), home: const AuthScreen()),
      ),
    );

    expect(find.text('EquaHome'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('nameField')), findsNothing);
  });

  testWidgets('AuthScreen alterna a registro', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildEquaTheme(), home: const AuthScreen()),
      ),
    );

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nameField')), findsOneWidget);
    expect(find.text('Crear cuenta'), findsWidgets);
  });
}
