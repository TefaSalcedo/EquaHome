import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import '../auth/auth_controller.dart';
import '../household/households_controller.dart';
import '../house/photos_controller.dart';
import '../profile/profile_screen.dart';
import 'assistant_controller.dart';
import 'home_controller.dart';
import 'nav_provider.dart';

/// Inicio: qué hay que hacer hoy, quién lo hace y cómo va el reparto.
/// Pensado para entenderse sin explicaciones: un saludo, las tareas de hoy
/// con un botón claro, y la carga de cada persona.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memberships = ref.watch(householdsControllerProvider);
    final detail = ref.watch(householdDetailProvider);
    final user = ref.watch(authControllerProvider).value;
    final tasks = ref.watch(todayTasksProvider);
    final load = ref.watch(loadProvider);
    final me = ref.watch(activeMembershipProvider);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: _HouseholdSwitcher(memberships: memberships),
        actions: [
          IconButton(
            key: const Key('profileButton'),
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileScreen(),
              ),
            ),
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
          onRefresh: () async {
            ref.invalidate(householdDetailProvider);
            ref.invalidate(todayTasksProvider);
            ref.invalidate(loadProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(EquaSpace.lg),
            children: [
              Text(
                'Hola, ${user?.displayName ?? ''}',
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                '${weekdayLabels[today.weekday]}, ${today.day} de ${_monthName(today.month)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: EquaSpace.lg),
              _TodaySection(tasks: tasks, myMemberId: me?.memberId),
              const SizedBox(height: EquaSpace.lg),
              const _AssistantCard(),
              const SizedBox(height: EquaSpace.lg),
              load.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (result) => _LoadCard(
                  load: result,
                  myMemberId: me?.memberId,
                ),
              ),
              const SizedBox(height: EquaSpace.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(EquaSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Quién vive aquí', style: theme.textTheme.titleMedium),
                      const SizedBox(height: EquaSpace.sm),
                      for (final m in household.members)
                        _MemberTile(member: m),
                      const SizedBox(height: EquaSpace.sm),
                      OutlinedButton.icon(
                        key: const Key('inviteButton'),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Invitar a alguien'),
                        onPressed: () => _invite(context, ref, household.id),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _monthName(int m) => _months[m - 1];

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
              const Text(
                  'Válido por 7 días. Compártelo con quien conviva contigo.'),
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

/// Cuéntale a la app en texto libre: interpreta, propone y la persona
/// confirma. Nunca impone.
class _AssistantCard extends ConsumerStatefulWidget {
  const _AssistantCard();

  @override
  ConsumerState<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends ConsumerState<_AssistantCard> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final result =
          await ref.read(assistantControllerProvider).interpret(text);
      if (!mounted) return;
      await _showProposal(context, ref, result);
      _text.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showProposal(
    BuildContext context,
    WidgetRef ref,
    InstructionResult result,
  ) async {
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('La app propone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.summary),
            if (result.actions.isNotEmpty) ...[
              const SizedBox(height: EquaSpace.md),
              for (final a in result.actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: EquaSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 16),
                      const SizedBox(width: EquaSpace.xs),
                      Expanded(child: Text(a.label)),
                    ],
                  ),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: EquaSpace.md),
                child: Text('(Sin cambios concretos por ahora)'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Mejor no'),
          ),
          if (result.actions.isNotEmpty)
            FilledButton(
              key: const Key('applyProposal'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aplicar'),
            ),
        ],
      ),
    );
    if (apply != true || !context.mounted) return;
    try {
      final applied =
          await ref.read(assistantControllerProvider).apply(result.actions);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(applied.join(' · '))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
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
            Text('Cuéntale a la app', style: theme.textTheme.titleMedium),
            const SizedBox(height: EquaSpace.xs),
            Text(
              'Ej. «mañana no estoy» o «paso la aspiradora a mañana». '
              'La app propone; tú decides.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: EquaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('assistantInput'),
                    controller: _text,
                    decoration: const InputDecoration(
                      hintText: 'Escribe aquí…',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: EquaSpace.sm),
                FilledButton(
                  key: const Key('assistantSend'),
                  onPressed: _sending ? null : _send,
                  child: const Text('Proponer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tareas de hoy: la parte central de la pantalla.
class _TodaySection extends ConsumerWidget {
  const _TodaySection({required this.tasks, required this.myMemberId});

  final AsyncValue<List<DayTask>> tasks;
  final String? myMemberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EquaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text('Tareas de hoy', style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  key: const Key('quickTaskButton'),
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Puntual'),
                  onPressed: () => _quickTask(context, ref),
                ),
                IconButton(
                  key: const Key('dailyPhotoButton'),
                  tooltip: 'Foto del cierre del día',
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  onPressed: () => _dailyPhoto(context, ref),
                ),
              ],
            ),
            const SizedBox(height: EquaSpace.sm),
            tasks.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(EquaSpace.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(apiErrorMessage(e)),
              data: (list) {
                final open =
                    list.where((t) => t.status != 'done').toList();
                final done =
                    list.where((t) => t.status == 'done').toList();
                if (list.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: EquaSpace.md),
                    child: Column(
                      children: [
                        const Icon(Icons.spa_outlined,
                            size: 40, color: EquaColors.primary),
                        const SizedBox(height: EquaSpace.sm),
                        Text(
                          'El día está despejado',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: EquaSpace.xs),
                        Text(
                          'Elige tareas de la pestaña Tareas o agrega una puntual.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: EquaSpace.sm),
                        TextButton(
                          key: const Key('goTasksButton'),
                          onPressed: () => ref
                              .read(navIndexProvider.notifier)
                              .select(2),
                          child: const Text('Ir a Tareas'),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${done.length} de ${list.length} hechas',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: EquaSpace.sm),
                    for (final t in open) ...[
                      _DayTaskCard(task: t, myMemberId: myMemberId),
                      const SizedBox(height: EquaSpace.sm),
                    ],
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: EquaSpace.xs),
                      const Divider(),
                      for (final t in done)
                        _DoneRow(task: t),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickTask(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _QuickTaskDialog(),
    );
    if (added == true) {
      ref.invalidate(todayTasksProvider);
    }
  }

  /// Foto del cierre del día: evaluación orientativa, nunca para culpar.
  Future<void> _dailyPhoto(BuildContext context, WidgetRef ref) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (file == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Analizando la foto…')),
      );
      final photos = ref.read(photosControllerProvider);
      var photo = await photos.upload(
        bytes: await file.readAsBytes(),
        filename: file.name,
        purpose: 'daily_check',
      );
      photo = await photos.analyze(photo.id);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Así se ve la casa'),
          content: Text(
            photo.analysis?.summary ?? 'Sin evaluación disponible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }
}

class _QuickTaskDialog extends ConsumerStatefulWidget {
  const _QuickTaskDialog();

  @override
  ConsumerState<_QuickTaskDialog> createState() => _QuickTaskDialogState();
}

class _QuickTaskDialogState extends ConsumerState<_QuickTaskDialog> {
  final _title = TextEditingController();
  final _minutes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tarea puntual'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('quickTaskTitle'),
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Qué hay que hacer',
              hintText: 'Ej. Sacar la basura',
            ),
          ),
          const SizedBox(height: EquaSpace.md),
          TextField(
            key: const Key('quickTaskMinutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutos que toma',
              hintText: '15',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('quickTaskSave'),
          onPressed: _saving ? null : _save,
          child: const Text('Agregar a hoy'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final minutes = int.tryParse(_minutes.text.trim());
    if (title.isEmpty || minutes == null || minutes < 1) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(todayTasksProvider.notifier)
          .addQuickTask(title, minutes);
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
}

class _DayTaskCard extends ConsumerWidget {
  const _DayTaskCard({required this.task, required this.myMemberId});

  final DayTask task;
  final String? myMemberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine =
        myMemberId != null && task.isAssignedTo(myMemberId!);
    final taken = task.assignees.isNotEmpty;
    final notifier = ref.read(todayTasksProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(EquaSpace.md),
      decoration: BoxDecoration(
        color: task.status == 'skipped'
            ? EquaColors.background
            : EquaColors.surface,
        borderRadius: BorderRadius.circular(EquaRadius.control),
        border: Border.all(
          color: mine ? EquaColors.primary : EquaColors.divider,
          width: mine ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(task.title, style: theme.textTheme.bodyMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: EquaSpace.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: EquaColors.info.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '~${task.estimatedMinutes} min',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: EquaSpace.xs),
          Text(
            [
              if (task.roomName != null) task.roomName!,
              taskCategoryLabels[task.category] ?? task.category,
              'Esfuerzo ${effortLabels[task.effort] ?? task.effort}',
              if (task.status == 'skipped') 'Pasada para mañana',
              if (task.status == 'carried_over') 'Viene de ayer',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (taken && !mine)
            Padding(
              padding: const EdgeInsets.only(top: EquaSpace.xs),
              child: Text(
                'La hace ${task.assignees.map((a) => a.displayName).join(', ')}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: EquaColors.primaryDark),
              ),
            ),
          const SizedBox(height: EquaSpace.sm),
          if (task.status == 'skipped')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Recuperar'),
                onPressed: () => _run(context, () => notifier.restore(task.id)),
              ),
            )
          else if (!taken)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: Key('select-${task.id}'),
                    icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
                    label: const Text('La hago yo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: EquaColors.primary,
                      foregroundColor: EquaColors.ink,
                    ),
                    onPressed: () =>
                        _run(context, () => notifier.select(task.id)),
                  ),
                ),
                IconButton(
                  tooltip: 'Para mañana',
                  icon: const Icon(Icons.redo),
                  onPressed: () =>
                      _run(context, () => notifier.skip(task.id)),
                ),
              ],
            )
          else if (mine)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: Key('complete-${task.id}'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('¡Listo!'),
                    style: FilledButton.styleFrom(
                      backgroundColor: EquaColors.success,
                      foregroundColor: EquaColors.ink,
                    ),
                    onPressed: () =>
                        _run(context, () => notifier.complete(task.id)),
                  ),
                ),
                IconButton(
                  tooltip: 'Soltar la tarea',
                  icon: const Icon(Icons.undo),
                  onPressed: () =>
                      _run(context, () => notifier.unselect(task.id)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.task});

  final DayTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle,
          color: EquaColors.success, size: 20),
      title: Text(
        task.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          decoration: TextDecoration.lineThrough,
          color: EquaColors.inkSoft,
        ),
      ),
      subtitle: task.assignees.isEmpty
          ? null
          : Text(
              'La hizo ${task.assignees.map((a) => a.displayName).join(', ')}'),
    );
  }
}

/// Carga del día por persona: minutos asignados vs. su parte esperada.
class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.load, required this.myMemberId});

  final LoadResult load;
  final String? myMemberId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EquaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reparto de hoy', style: theme.textTheme.titleMedium),
            const SizedBox(height: EquaSpace.sm),
            Text(
              load.singleMember
                  ? 'Hoy hay ~${load.totalMinutes.toStringAsFixed(0)} min de tareas en total.'
                  : 'Hoy hay ~${load.totalMinutes.toStringAsFixed(0)} min repartidos entre ${load.members.length} personas.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: EquaSpace.md),
            for (final m in load.members) ...[
              _MemberLoadBar(
                load: m,
                isMe: m.memberId == myMemberId,
                total: load.totalMinutes,
              ),
              const SizedBox(height: EquaSpace.sm),
            ],
            if (load.suggestion != null) ...[
              const SizedBox(height: EquaSpace.sm),
              Container(
                padding: const EdgeInsets.all(EquaSpace.md),
                decoration: BoxDecoration(
                  color: EquaColors.warningSoft.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(EquaRadius.control),
                ),
                child: Text(
                  '💡 A ${load.suggestion!.displayName} le tocaría '
                  '~${load.suggestion!.deficitMinutes.toStringAsFixed(0)} min '
                  'más para que quede parejo. '
                  '${load.suggestion!.candidates.isEmpty ? '' : 'Podría tomar: ${load.suggestion!.candidates.map((c) => c.title).join(', ')}.'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (load.notice != null) ...[
              const SizedBox(height: EquaSpace.sm),
              Text(load.notice!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberLoadBar extends StatelessWidget {
  const _MemberLoadBar({
    required this.load,
    required this.isMe,
    required this.total,
  });

  final MemberLoad load;
  final bool isMe;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expected = load.expectedMinutes;
    final denominator = (expected != null && expected > 0)
        ? expected
        : (total > 0 ? total : 1);
    final value = (load.assignedMinutes / denominator).clamp(0.0, 1.0);
    final diff = load.differenceMinutes;
    final label = expected != null
        ? '${load.assignedMinutes.toStringAsFixed(0)} de ~${expected.toStringAsFixed(0)} min'
        : '${load.assignedMinutes.toStringAsFixed(0)} min';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isMe ? '${load.displayName} (tú)' : load.displayName,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: EquaSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.toDouble(),
            minHeight: 8,
            backgroundColor: EquaColors.divider,
            color: diff != null && diff > 10
                ? EquaColors.secondary
                : EquaColors.primary,
          ),
        ),
        if (diff != null && diff > 10)
          Padding(
            padding: const EdgeInsets.only(top: EquaSpace.xs),
            child: Text(
              '${load.displayName} lleva ~${diff.toStringAsFixed(0)} min de más',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: EquaColors.primaryDark),
            ),
          ),
      ],
    );
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
      dense: true,
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
