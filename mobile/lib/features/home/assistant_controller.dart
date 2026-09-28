import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../calendar/calendar_screen.dart';
import '../household/households_controller.dart';
import 'home_controller.dart';

/// Propuesta del asistente: la app propone, la persona confirma.
class AssistantAction {
  const AssistantAction({required this.type, this.title, this.minutes});

  factory AssistantAction.fromJson(Map<String, dynamic> json) =>
      AssistantAction(
        type: json['type'] as String,
        title: json['title'] as String?,
        minutes: json['estimated_minutes'] as int?,
      );

  final String type;
  final String? title;
  final int? minutes;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': ?title,
        'estimated_minutes': ?minutes,
      };

  String get label => switch (type) {
        'release_my_tasks' =>
          'Liberar las tareas que elegí hoy para que otra persona las tome',
        'postpone_my_tasks' => 'Mover mis tareas de hoy a mañana',
        'create_task' =>
          'Crear la tarea puntual «${title ?? ''}» (~${minutes ?? 15} min)',
        _ => type,
      };
}

class InstructionResult {
  const InstructionResult({required this.summary, required this.actions});

  factory InstructionResult.fromJson(Map<String, dynamic> json) =>
      InstructionResult(
        summary: json['summary'] as String,
        actions: (json['actions'] as List)
            .map((a) => AssistantAction.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  final String summary;
  final List<AssistantAction> actions;
}

final assistantControllerProvider =
    Provider<AssistantController>(AssistantController.new);

class AssistantController {
  AssistantController(this._ref);

  final Ref _ref;

  String get _hid =>
      _ref.read(activeMembershipProvider)!.householdId;

  Future<InstructionResult> interpret(String text) async {
    final res = await _ref.read(dioProvider).post(
      '/api/v1/households/$_hid/assistant/interpret',
      data: {'text': text},
    );
    return InstructionResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<String>> apply(List<AssistantAction> actions) async {
    final res = await _ref.read(dioProvider).post(
      '/api/v1/households/$_hid/assistant/apply',
      data: {'actions': actions.map((a) => a.toJson()).toList()},
    );
    _ref.invalidate(todayTasksProvider);
    _ref.invalidate(loadProvider);
    _ref.invalidate(weekProvider);
    return (res.data['applied'] as List).cast<String>();
  }
}
