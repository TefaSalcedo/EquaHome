import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../household/households_controller.dart';

/// Plantillas de tareas del hogar activo.
final taskTemplatesProvider =
    AsyncNotifierProvider<TaskTemplatesController, List<TaskTemplate>>(
  TaskTemplatesController.new,
);

class TaskTemplatesController extends AsyncNotifier<List<TaskTemplate>> {
  @override
  Future<List<TaskTemplate>> build() async {
    final active = ref.watch(activeMembershipProvider);
    if (active == null) return const [];
    final res = await ref
        .read(dioProvider)
        .get('/api/v1/households/${active.householdId}/task-templates');
    return (res.data as List)
        .map((t) => TaskTemplate.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTemplate(Map<String, dynamic> data) async {
    final hid = ref.read(activeMembershipProvider)!.householdId;
    await ref
        .read(dioProvider)
        .post('/api/v1/households/$hid/task-templates', data: data);
    ref.invalidateSelf();
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> data) async {
    await ref.read(dioProvider).patch('/api/v1/task-templates/$id', data: data);
    ref.invalidateSelf();
  }

  Future<void> deleteTemplate(String id) async {
    await ref.read(dioProvider).delete('/api/v1/task-templates/$id');
    ref.invalidateSelf();
  }

  /// Reemplaza las condiciones (el backend recalcula el estimado).
  Future<void> setConditions(
      String templateId, List<TaskCondition> conditions) async {
    await ref.read(dioProvider).put(
      '/api/v1/task-templates/$templateId/conditions',
      data: [for (final c in conditions) c.toJson()],
    );
    ref.invalidateSelf();
  }
}
