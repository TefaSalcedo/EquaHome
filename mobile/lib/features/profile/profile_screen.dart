import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import '../auth/auth_controller.dart';
import '../home/home_controller.dart';
import '../household/households_controller.dart';
import '../tasks/tasks_controller.dart';

/// Perfil del miembro en el hogar activo: disponibilidad semanal, tipo de
/// miembro y preferencias de tareas. La app las usa para proponer, no imponer.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    final membership = ref.watch(activeMembershipProvider);

    if (user == null || membership == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(EquaSpace.lg),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: EquaColors.primary.withValues(alpha: 0.35),
                child: Text(
                  user.displayName.isEmpty
                      ? '?'
                      : user.displayName[0].toUpperCase(),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: EquaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: theme.textTheme.titleMedium),
                    Text(user.email, style: theme.textTheme.bodySmall),
                    Text(
                      'En ${membership.householdName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EquaSpace.lg),
          _AvailabilityCard(membership: membership),
          const SizedBox(height: EquaSpace.lg),
          const _PreferencesCard(),
          const SizedBox(height: EquaSpace.lg),
          OutlinedButton.icon(
            key: const Key('signOutButton'),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: EquaColors.inkSoft,
            ),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

/// Disponibilidad: tipo de miembro, minutos semanales, días y capacidad.
class _AvailabilityCard extends ConsumerStatefulWidget {
  const _AvailabilityCard({required this.membership});

  final Membership membership;

  @override
  ConsumerState<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends ConsumerState<_AvailabilityCard> {
  late final TextEditingController _weekly;
  late Set<int> _days;
  late String _memberType;
  late double _capacity;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final m = widget.membership;
    _weekly = TextEditingController(
      text: m.weeklyMinutes?.toString() ?? '',
    );
    _days = {...?m.daysAvailable};
    _memberType = m.memberType;
    _capacity = m.capacityFactor;
  }

  @override
  void dispose() {
    _weekly.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(householdsControllerProvider.notifier)
          .updateMemberProfile({
        'member_type': _memberType,
        'capacity_factor': _capacity,
        'weekly_minutes': int.tryParse(_weekly.text.trim()),
        'days_available': _days.toList()..sort(),
      });
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Guardado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EquaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mi disponibilidad', style: theme.textTheme.titleMedium),
            const SizedBox(height: EquaSpace.sm),
            Text(
              'EquaHome la usa para repartir de forma justa — nunca para exigir.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: EquaSpace.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'adult', label: Text('Adulto')),
                ButtonSegment(value: 'child', label: Text('Hijo/a')),
              ],
              selected: {_memberType},
              onSelectionChanged: (s) {
                setState(() {
                  _memberType = s.first;
                  _dirty = true;
                });
              },
            ),
            if (_memberType == 'child') ...[
              const SizedBox(height: EquaSpace.md),
              Text(
                'Capacidad relativa: ${( _capacity * 100).round()}%',
                style: theme.textTheme.bodyMedium,
              ),
              Slider(
                value: _capacity,
                min: 0.1,
                divisions: 9,
                label: '${(_capacity * 100).round()}%',
                onChanged: (v) {
                  setState(() {
                    _capacity = v;
                    _dirty = true;
                  });
                },
              ),
            ],
            const SizedBox(height: EquaSpace.md),
            TextField(
              key: const Key('weeklyMinutesField'),
              controller: _weekly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos disponibles por semana',
                hintText: 'Ej. 300',
                suffixText: 'min',
              ),
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: EquaSpace.md),
            Text('Días que puedo', style: theme.textTheme.bodySmall),
            const SizedBox(height: EquaSpace.xs),
            Wrap(
              spacing: EquaSpace.sm,
              children: [
                for (final e in weekdayLabels.entries)
                  FilterChip(
                    label: Text(e.value.substring(0, 3)),
                    selected: _days.contains(e.key),
                    onSelected: (sel) {
                      setState(() {
                        sel ? _days.add(e.key) : _days.remove(e.key);
                        _dirty = true;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: EquaSpace.lg),
            ElevatedButton(
              key: const Key('saveProfile'),
              onPressed: (_saving || !_dirty) ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar disponibilidad'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preferencias: por cada plantilla, me gusta / no me gusta / no puedo.
class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(preferencesProvider).value ?? const [];
    final templates = ref.watch(taskTemplatesProvider).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EquaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mis preferencias', style: theme.textTheme.titleMedium),
            const SizedBox(height: EquaSpace.sm),
            Text(
              'La app propone el reparto teniendo en cuenta lo que te gusta '
              'y lo que no puedes hacer.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: EquaSpace.md),
            if (templates.isEmpty)
              Text(
                'Aún no hay plantillas en este hogar.',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final t in templates.where((t) => t.active)) ...[
                _PreferenceRow(template: t, prefs: prefs),
                const Divider(height: EquaSpace.lg),
              ],
          ],
        ),
      ),
    );
  }
}

class _PreferenceRow extends ConsumerWidget {
  const _PreferenceRow({required this.template, required this.prefs});

  final TaskTemplate template;
  final List<TaskPreference> prefs;

  String? _current() {
    for (final p in prefs) {
      if (p.templateId == template.id) return p.kind;
    }
    return null;
  }

  Future<void> _set(WidgetRef ref, String kind) async {
    final current = _current();
    final next = [
      for (final p in prefs) if (p.templateId != template.id) p,
      if (current != kind)
        TaskPreference(id: '', kind: kind, templateId: template.id),
    ];
    try {
      await ref.read(preferencesProvider.notifier).setPreferences(next);
    } catch (_) {/* el provider recarga */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = _current();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.name, style: theme.textTheme.bodyMedium),
              Text(
                '~${template.estimatedMinutes} min',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _PrefButton(
          icon: Icons.favorite_border,
          activeIcon: Icons.favorite,
          tooltip: 'Me gusta',
          active: current == 'like',
          color: EquaColors.success,
          onTap: () => _set(ref, 'like'),
        ),
        _PrefButton(
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down,
          tooltip: 'No me gusta',
          active: current == 'dislike',
          color: EquaColors.secondary,
          onTap: () => _set(ref, 'dislike'),
        ),
        _PrefButton(
          icon: Icons.block_outlined,
          activeIcon: Icons.block,
          tooltip: 'No puedo hacerla',
          active: current == 'cannot_do',
          color: EquaColors.inkSoft,
          onTap: () => _set(ref, 'cannot_do'),
        ),
      ],
    );
  }
}

class _PrefButton extends StatelessWidget {
  const _PrefButton({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        active ? activeIcon : icon,
        size: 20,
        color: active ? color : EquaColors.divider,
      ),
    );
  }
}
