import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import '../house/house_controller.dart';
import 'tasks_controller.dart';

/// Pestaña Tareas: plantillas con estimado real (base + condiciones que aplican)
/// y ponderación por esfuerzo.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templates = ref.watch(taskTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tareas')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addTask'),
        onPressed: () => _showTaskForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tarea'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (list) {
          final active = list.where((t) => t.active).toList();
          final inactive = list.where((t) => !t.active).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(taskTemplatesProvider),
            child: ListView(
              padding: const EdgeInsets.all(EquaSpace.lg),
              children: [
                if (list.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: EquaSpace.xl),
                    child: Column(
                      children: [
                        const Icon(Icons.checklist, size: 48,
                            color: EquaColors.primary),
                        const SizedBox(height: EquaSpace.md),
                        Text(
                          'Crea las tareas de tu casa',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: EquaSpace.sm),
                        Text(
                          'Define cuánto toma cada una y las condiciones que '
                          'le suman tiempo. EquaHome usará estos estimados '
                          'para repartir la carga.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  for (final t in active) ...[
                    _TaskCard(template: t),
                    const SizedBox(height: EquaSpace.md),
                  ],
                  if (inactive.isNotEmpty) ...[
                    const SizedBox(height: EquaSpace.md),
                    Text('Inactivas', style: theme.textTheme.bodySmall),
                    const SizedBox(height: EquaSpace.sm),
                    for (final t in inactive) ...[
                      Opacity(
                        opacity: 0.6,
                        child: _TaskCard(template: t),
                      ),
                      const SizedBox(height: EquaSpace.md),
                    ],
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTaskForm(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TaskFormSheet(),
    );
    if (saved == true) {
      ref.invalidate(taskTemplatesProvider);
    }
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.template});

  final TaskTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extra = template.estimatedMinutes - template.baseMinutes;
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: EquaSpace.md),
        childrenPadding: const EdgeInsets.only(
          left: EquaSpace.md,
          right: EquaSpace.md,
          bottom: EquaSpace.md,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(template.name, style: theme.textTheme.titleMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: EquaSpace.sm,
                vertical: EquaSpace.xs,
              ),
              decoration: BoxDecoration(
                color: EquaColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(EquaRadius.control),
              ),
              child: Text(
                '~${template.estimatedMinutes} min',
                key: Key('estimate-${template.id}'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            taskCategoryLabels[template.category] ?? template.category,
            frequencyLabels[template.frequency] ?? template.frequency,
            'Esfuerzo ${effortLabels[template.effort] ?? template.effort}',
            if (template.roomName != null) template.roomName!,
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              extra > 0
                  ? 'Base ${template.baseMinutes} min + $extra min por '
                      'condiciones (ponderado: '
                      '${template.weightedMinutes.toStringAsFixed(0)} min)'
                  : 'Base ${template.baseMinutes} min (ponderado: '
                      '${template.weightedMinutes.toStringAsFixed(0)} min)',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (template.conditions.isNotEmpty) ...[
            const SizedBox(height: EquaSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Condiciones — marca las que aplican:',
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final c in template.conditions)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: c.applies,
                title: Text(c.label, style: theme.textTheme.bodyMedium),
                subtitle: Text('+${c.extraMinutes} min'),
                onChanged: (v) => _toggleCondition(ref, c, v ?? false),
              ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(
                  template.active ? Icons.pause : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(template.active ? 'Pausar' : 'Activar'),
                onPressed: () => ref
                    .read(taskTemplatesProvider.notifier)
                    .updateTemplate(template.id, {'active': !template.active}),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar'),
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCondition(
      WidgetRef ref, TaskCondition c, bool applies) async {
    try {
      final updated = [
        for (final cond in template.conditions)
          if (cond.id == c.id)
            TaskCondition(
              id: cond.id,
              label: cond.label,
              extraMinutes: cond.extraMinutes,
              applies: applies,
            )
          else
            cond,
      ];
      await ref
          .read(taskTemplatesProvider.notifier)
          .setConditions(template.id, updated);
    } catch (_) {/* se recarga en el próximo intento */}
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(taskTemplatesProvider.notifier).deleteTemplate(template.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

/// Formulario de nueva plantilla: nombre, minutos base, categoría, esfuerzo,
/// frecuencia, habitación y condiciones que suman minutos.
class _TaskFormSheet extends ConsumerStatefulWidget {
  const _TaskFormSheet();

  @override
  ConsumerState<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _ConditionDraft {
  _ConditionDraft();

  final label = TextEditingController();
  final minutes = TextEditingController();
}

class _TaskFormSheetState extends ConsumerState<_TaskFormSheet> {
  final _name = TextEditingController();
  final _minutes = TextEditingController();
  final List<_ConditionDraft> _conditions = [];
  String _category = 'general';
  String _effort = 'medium';
  String _frequency = 'weekly';
  String? _roomId;
  int? _weekday;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _minutes.dispose();
    for (final c in _conditions) {
      c.label.dispose();
      c.minutes.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final base = int.tryParse(_minutes.text.trim());
    if (name.isEmpty || base == null || base < 1) return;
    setState(() => _saving = true);
    try {
      await ref.read(taskTemplatesProvider.notifier).createTemplate({
        'name': name,
        'category': _category,
        'room_id': _roomId,
        'base_minutes': base,
        'effort': _effort,
        'frequency': _frequency,
        'preferred_weekday': _weekday,
        'conditions': [
          for (final c in _conditions)
            if (c.label.text.trim().isNotEmpty)
              {
                'label': c.label.text.trim(),
                'extra_minutes':
                    int.tryParse(c.minutes.text.trim()) ?? 0,
                'applies': true,
              },
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
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
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    return Padding(
      padding: EdgeInsets.only(
        left: EquaSpace.lg,
        right: EquaSpace.lg,
        top: EquaSpace.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + EquaSpace.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva tarea', style: theme.textTheme.titleMedium),
            const SizedBox(height: EquaSpace.md),
            TextField(
              key: const Key('taskNameField'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Lavar ropa',
              ),
            ),
            const SizedBox(height: EquaSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('taskMinutesField'),
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutos base',
                      hintText: '25',
                    ),
                  ),
                ),
                const SizedBox(width: EquaSpace.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _frequency,
                    decoration:
                        const InputDecoration(labelText: 'Frecuencia'),
                    items: [
                      for (final e in frequencyLabels.entries)
                        DropdownMenuItem(
                            value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) =>
                        setState(() => _frequency = v ?? 'weekly'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EquaSpace.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration:
                        const InputDecoration(labelText: 'Categoría'),
                    items: [
                      for (final e in taskCategoryLabels.entries)
                        DropdownMenuItem(
                            value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'general'),
                  ),
                ),
                const SizedBox(width: EquaSpace.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _effort,
                    decoration: const InputDecoration(labelText: 'Esfuerzo'),
                    items: [
                      for (final e in effortLabels.entries)
                        DropdownMenuItem(
                            value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) =>
                        setState(() => _effort = v ?? 'medium'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EquaSpace.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _roomId,
                    decoration: const InputDecoration(
                      labelText: 'Habitación (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin habitación'),
                      ),
                      for (final r in rooms)
                        DropdownMenuItem<String?>(
                          value: r.id,
                          child: Text(r.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _roomId = v),
                  ),
                ),
                const SizedBox(width: EquaSpace.md),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _weekday,
                    decoration: const InputDecoration(
                      labelText: 'Día ideal (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Cualquiera'),
                      ),
                      for (final e in weekdayLabels.entries)
                        DropdownMenuItem<int?>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                    ],
                    onChanged: (v) => setState(() => _weekday = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EquaSpace.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Condiciones que suman tiempo',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  key: const Key('addCondition'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  onPressed: () =>
                      setState(() => _conditions.add(_ConditionDraft())),
                ),
              ],
            ),
            for (final c in _conditions)
              Padding(
                padding: const EdgeInsets.only(bottom: EquaSpace.sm),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: c.label,
                        decoration: const InputDecoration(
                          labelText: 'Condición',
                          hintText: 'Ej. Colgar al aire',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: EquaSpace.sm),
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: c.minutes,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '+min',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _conditions.remove(c)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: EquaSpace.md),
            ElevatedButton(
              key: const Key('saveTask'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
