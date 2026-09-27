import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import 'auth_controller.dart';

/// Pantalla de acceso: alterna entre "Entrar" y "Crear cuenta".
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_isLogin) {
        await auth.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await auth.register(
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(EquaSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('EquaHome',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 32,
                        color: EquaColors.primaryDark,
                      )),
                  const SizedBox(height: EquaSpace.sm),
                  Text(
                    'Tu casa, en equilibrio.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: EquaSpace.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(EquaSpace.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLogin ? 'Bienvenida de nuevo' : 'Crea tu cuenta',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: EquaSpace.md),
                            if (!_isLogin) ...[
                              TextFormField(
                                key: const Key('nameField'),
                                controller: _nameController,
                                decoration:
                                    const InputDecoration(labelText: 'Nombre'),
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Cuéntanos tu nombre'
                                        : null,
                              ),
                              const SizedBox(height: EquaSpace.md),
                            ],
                            TextFormField(
                              key: const Key('emailField'),
                              controller: _emailController,
                              decoration:
                                  const InputDecoration(labelText: 'Correo'),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  (v == null || !v.contains('@'))
                                      ? 'Correo inválido'
                                      : null,
                            ),
                            const SizedBox(height: EquaSpace.md),
                            TextFormField(
                              key: const Key('passwordField'),
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                  labelText: 'Contraseña'),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.length < 8)
                                  ? 'Mínimo 8 caracteres'
                                  : null,
                            ),
                            const SizedBox(height: EquaSpace.lg),
                            ElevatedButton(
                              key: const Key('submitAuth'),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(_isLogin ? 'Entrar' : 'Crear cuenta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: EquaSpace.md),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? '¿No tienes cuenta? Regístrate'
                          : '¿Ya tienes cuenta? Entra',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
