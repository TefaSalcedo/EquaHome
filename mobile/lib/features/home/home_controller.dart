import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../household/households_controller.dart';

/// Tareas del hogar activo para el día de hoy.
final todayTasksProvider =
    AsyncNotifierProvider<TodayTasksController, List<DayTask>>(
  TodayTasksController.new,
);

class TodayTasksController extends AsyncNotifier<List<DayTask>> {
  @override
  Future<List<DayTask>> build() async {
    final active = ref.watch(activeMembershipProvider);
    if (active == null) return const [];
    final res = await ref
        .read(dioProvider)
        .get('/api/v1/households/${active.householdId}/tasks');
    return (res.data as List)
        .map((t) => DayTask.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  void _refresh() {
    ref.invalidateSelf();
    ref.invalidate(loadProvider);
  }

  /// Crea una tarea de hoy desde una plantilla (la app propone).
  Future<void> addFromTemplate(String templateId) async {
    final hid = ref.read(activeMembershipProvider)!.householdId;
    await ref.read(dioProvider).post(
      '/api/v1/households/$hid/tasks',
      data: {'template_id': templateId},
    );
    _refresh();
  }

  /// Tarea puntual (extraordinaria) para hoy.
  Future<void> addQuickTask(String title, int minutes) async {
    final hid = ref.read(activeMembershipProvider)!.householdId;
    await ref.read(dioProvider).post(
      '/api/v1/households/$hid/tasks',
      data: {'title': title, 'estimated_minutes': minutes},
    );
    _refresh();
  }

  Future<void> select(String taskId) async {
    await ref.read(dioProvider).post('/api/v1/tasks/$taskId/select');
    _refresh();
  }

  Future<void> unselect(String taskId) async {
    await ref.read(dioProvider).post('/api/v1/tasks/$taskId/unselect');
    _refresh();
  }

  Future<void> complete(String taskId) async {
    await ref.read(dioProvider).post('/api/v1/tasks/$taskId/complete');
    _refresh();
  }

  Future<void> skip(String taskId) async {
    await ref.read(dioProvider).post('/api/v1/tasks/$taskId/skip');
    _refresh();
  }
}

/// Carga del día: minutos ponderados por persona, esperado según capacidad
/// y sugerencia de equilibrio (o solo el total si vive una sola persona).
final loadProvider = FutureProvider<LoadResult>((ref) async {
  final active = ref.watch(activeMembershipProvider);
  if (active == null) throw StateError('Sin hogar');
  final res = await ref
      .read(dioProvider)
      .get('/api/v1/households/${active.householdId}/load');
  return LoadResult.fromJson(res.data as Map<String, dynamic>);
});

/// Preferencias de tareas del miembro actual en el hogar activo.
final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, List<TaskPreference>>(
  PreferencesController.new,
);

class PreferencesController extends AsyncNotifier<List<TaskPreference>> {
  @override
  Future<List<TaskPreference>> build() async {
    final active = ref.watch(activeMembershipProvider);
    if (active == null) return const [];
    final res = await ref.read(dioProvider).get(
        '/api/v1/households/${active.householdId}/members/me/preferences');
    return (res.data as List)
        .map((p) => TaskPreference.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> setPreferences(List<TaskPreference> prefs) async {
    final hid = ref.read(activeMembershipProvider)!.householdId;
    await ref.read(dioProvider).put(
      '/api/v1/households/$hid/members/me/preferences',
      data: [
        for (final p in prefs)
          {'kind': p.kind, 'template_id': p.templateId, 'category': p.category},
      ],
    );
    ref.invalidateSelf();
  }
}
