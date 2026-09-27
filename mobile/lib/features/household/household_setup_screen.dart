import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/theme.dart';
import '../auth/auth_controller.dart';
import 'households_controller.dart';

/// Pantalla posterior al registro: crear un hogar o unirse con código.
/// También permite seguir viviendo sola/o: el hogar funciona con 1 miembro.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
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
      appBar: AppBar(
        title: const Text('Tu hogar'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(EquaSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('¿Cómo empezamos?',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: EquaSpace.sm),
                  Text(
                    'Crea tu hogar o únete a uno existente. '
                    'Puedes empezar sola/o e invitar después.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: EquaSpace.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(EquaSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Crear un hogar',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: EquaSpace.md),
                          TextField(
                            key: const Key('householdNameField'),
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del hogar',
                              hintText: 'Ej: Apartamento 502',
                            ),
                          ),
                          const SizedBox(height: EquaSpace.md),
                          ElevatedButton(
                            key: const Key('createHousehold'),
                            onPressed: _loading
                                ? null
                                : () => _run(() => ref
                                    .read(householdsControllerProvider.notifier)
                                    .createHousehold(
                                        _nameController.text.trim())),
                            child: const Text('Crear hogar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: EquaSpace.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(EquaSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Tengo un código de invitación',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: EquaSpace.md),
                          TextField(
                            key: const Key('inviteCodeField'),
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'Código',
                              hintText: 'Pega el código aquí',
                            ),
                          ),
                          const SizedBox(height: EquaSpace.md),
                          OutlinedButton(
                            key: const Key('joinHousehold'),
                            onPressed: _loading
                                ? null
                                : () => _run(() => ref
                                    .read(householdsControllerProvider.notifier)
                                    .joinHousehold(
                                        _codeController.text.trim())),
                            child: const Text('Unirme'),
                          ),
                        ],
                      ),
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
