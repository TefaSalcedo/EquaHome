import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import '../household/households_controller.dart';

/// Lunes de la semana visible en el calendario.
final weekStartProvider =
    NotifierProvider<WeekStart, DateTime>(WeekStart.new);

class WeekStart extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  void shiftWeeks(int delta) {
    state = DateTime(state.year, state.month, state.day + 7 * delta);
  }
}

/// Día seleccionado dentro de la semana (0=lunes … 6=domingo).
final selectedDayProvider =
    NotifierProvider<SelectedDay, int>(SelectedDay.new);

class SelectedDay extends Notifier<int> {
  @override
  int build() => DateTime.now().weekday - 1;

  void select(int index) => state = index;
}

final weekProvider = FutureProvider<WeekResult>((ref) async {
  final active = ref.watch(activeMembershipProvider);
  if (active == null) {
    return const WeekResult(start: '', days: []);
  }
  final start = ref.watch(weekStartProvider);
  final res = await ref.read(dioProvider).get(
    '/api/v1/households/${active.householdId}/week',
    queryParameters: {'start': _iso(start)},
  );
  return WeekResult.fromJson(res.data as Map<String, dynamic>);
});

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _dayNames = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

/// Vista semanal del plan: la app propone cada día y aquí se revisa.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = ref.watch(weekStartProvider);
    final selected = ref.watch(selectedDayProvider);
    final week = ref.watch(weekProvider);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('${_months[start.month - 1]} ${start.year}'),
        actions: [
          IconButton(
            key: const Key('prevWeek'),
            tooltip: 'Semana anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                ref.read(weekStartProvider.notifier).shiftWeeks(-1),
          ),
          IconButton(
            key: const Key('nextWeek'),
            tooltip: 'Semana siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                ref.read(weekStartProvider.notifier).shiftWeeks(1),
          ),
          const SizedBox(width: EquaSpace.sm),
        ],
      ),
      body: week.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (result) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EquaSpace.sm,
                vertical: EquaSpace.sm,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < result.days.length && i < 7; i++)
                    Expanded(
                      child: _DayCell(
                        index: i,
                        day: result.days.length > i ? result.days[i] : null,
                        date: start.add(Duration(days: i)),
                        isToday: _sameDay(
                          start.add(Duration(days: i)),
                          today,
                        ),
                        selected: selected == i,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: EquaColors.divider),
            Expanded(
              child: result.days.isEmpty
                  ? const SizedBox.shrink()
                  : _DayList(
                      day: result.days[selected],
                      label:
                          '${_dayNames[selected]} ${start.add(Duration(days: selected)).day}',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.index,
    required this.day,
    required this.date,
    required this.isToday,
    required this.selected,
  });

  final int index;
  final WeekDay? day;
  final DateTime date;
  final bool isToday;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(EquaRadius.control),
      onTap: () => ref.read(selectedDayProvider.notifier).select(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: EquaSpace.sm),
        decoration: BoxDecoration(
          color: selected ? EquaColors.primary.withValues(alpha: 0.25) : null,
          borderRadius: BorderRadius.circular(EquaRadius.control),
          border: isToday
              ? Border.all(color: EquaColors.primaryDark)
              : null,
        ),
        child: Column(
          children: [
            Text(_dayLetters[index], style: theme.textTheme.bodySmall),
            Text(
              '${date.day}',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              day == null || day!.totalMinutes <= 0
                  ? '—'
                  : '${day!.totalMinutes.round()}′',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: EquaColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.day, required this.label});

  final WeekDay day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(EquaSpace.lg),
      children: [
        Text(
          'Plan del $label · ~${day.totalMinutes.round()} min'
          '${day.tasks.isNotEmpty ? ' · ${day.doneCount}/${day.tasks.length} hechas' : ''}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: EquaSpace.md),
        if (day.tasks.isEmpty)
          Text(
            'La app no propone tareas para este día.',
            style: theme.textTheme.bodySmall,
          )
        else
          for (final task in day.tasks) ...[
            _WeekTaskTile(task: task),
            const SizedBox(height: EquaSpace.sm),
          ],
      ],
    );
  }
}

class _WeekTaskTile extends StatelessWidget {
  const _WeekTaskTile({required this.task});

  final DayTask task;

  String get _status {
    switch (task.status) {
      case 'done':
        return 'Hecha';
      case 'skipped':
        return 'Pasada';
      case 'carried_over':
        return 'Viene de antes';
      default:
        if (task.assignees.isNotEmpty) {
          return 'La hace '
              '${task.assignees.map((a) => a.displayName).join(', ')}';
        }
        return 'Disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.status == 'done';
    return Container(
      padding: const EdgeInsets.all(EquaSpace.md),
      decoration: BoxDecoration(
        color: done ? EquaColors.background : EquaColors.surface,
        borderRadius: BorderRadius.circular(EquaRadius.control),
        border: Border.all(color: EquaColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 20,
            color: done ? EquaColors.success : EquaColors.inkSoft,
          ),
          const SizedBox(width: EquaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration:
                        done ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '$_status · ~${task.estimatedMinutes} min'
                  '${task.roomName != null ? ' · ${task.roomName}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
