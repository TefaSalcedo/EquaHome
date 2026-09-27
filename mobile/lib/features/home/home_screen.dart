import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import '../auth/auth_controller.dart';
import '../household/households_controller.dart';

/// Home de la fase 01: hogar activo, sus miembros y código de invitación.
/// Las tareas de hoy, la carga y la foto llegan en fases siguientes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memberships = ref.watch(householdsControllerProvider);
    final detail = ref.watch(householdDetailProvider);
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: _HouseholdSwitcher(memberships: memberships),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(EquaSpace.lg),
            child: Text(apiErrorMessage(e)),
          ),
        ),
        data: (household) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(householdDetailProvider),
          child: ListView(
            padding: const EdgeInsets.all(EquaSpace.lg),
            children: [
              Text(
                'Hola, ${user?.displayName ?? ''} 👋',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: EquaSpace.sm),
              Text(
                household.members.length == 1
                    ? 'Tu hogar está listo — puedes invitar a más personas cuando quieras.'
                    : '${household.members.length} personas comparten este hogar.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: EquaSpace.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(EquaSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Miembros', style: theme.textTheme.titleMedium),
                      const SizedBox(height: EquaSpace.sm),
                      for (final m in household.members)
                        _MemberTile(member: m),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: EquaSpace.lg),
              OutlinedButton.icon(
                key: const Key('inviteButton'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invitar a alguien'),
                onPressed: () => _invite(context, ref, household.id),
              ),
              const SizedBox(height: EquaSpace.lg),
              Container(
                padding: const EdgeInsets.all(EquaSpace.md),
                decoration: BoxDecoration(
                  color: EquaColors.info.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(EquaRadius.card),
                ),
                child: Text(
                  'Pronto verás aquí tus tareas de hoy y la carga de cada persona.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _invite(
      BuildContext context, WidgetRef ref, String householdId) async {
    try {
      final code = await ref
          .read(householdsControllerProvider.notifier)
          .createInvite(householdId);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de invitación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: EquaSpace.sm),
              const Text('Válido por 7 días. Compártelo con quien conviva contigo.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.of(context).pop();
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

class _HouseholdSwitcher extends ConsumerWidget {
  const _HouseholdSwitcher({required this.memberships});

  final AsyncValue<List<Membership>> memberships;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = memberships.value ?? const <Membership>[];
    if (list.length <= 1) {
      return Text(list.isEmpty ? 'EquaHome' : list.first.householdName);
    }
    final selected = ref.watch(selectedHouseholdProvider);
    final active = list.firstWhere(
      (m) => m.householdId == selected,
      orElse: () => list.firstWhere(
        (m) => m.isPrimary,
        orElse: () => list.first,
      ),
    );
    return DropdownButton<String>(
      value: active.householdId,
      underline: const SizedBox.shrink(),
      items: [
        for (final m in list)
          DropdownMenuItem(
            value: m.householdId,
            child: Row(
              children: [
                Text(m.householdName),
                if (m.isPrimary) ...[
                  const SizedBox(width: EquaSpace.xs),
                  const Icon(Icons.home, size: 16, color: EquaColors.primaryDark),
                ],
              ],
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) {
          ref.read(selectedHouseholdProvider.notifier).select(id);
        }
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final HouseholdMemberInfo member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: EquaColors.primary.withValues(alpha: 0.35),
        child: Text(
          member.displayName.isEmpty ? '?' : member.displayName[0].toUpperCase(),
          style: const TextStyle(color: EquaColors.ink),
        ),
      ),
      title: Text(member.displayName, style: theme.textTheme.bodyMedium),
      subtitle: member.memberType == 'child'
          ? const Text('Miembro con capacidad reducida')
          : null,
      trailing: Wrap(
        spacing: EquaSpace.xs,
        children: [
          if (member.isPrimary)
            const Tooltip(
              message: 'Residencia principal',
              child: Icon(Icons.home, size: 18, color: EquaColors.primaryDark),
            ),
          if (member.role == 'owner')
            const Icon(Icons.star_rounded, size: 18, color: EquaColors.primaryDark),
        ],
      ),
    );
  }
}
