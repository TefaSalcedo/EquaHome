/// Modelos del dominio para la fase 01: usuarios, hogares y membresías.
/// Reflejan los esquemas del backend (`/api/v1`).
class EquaUser {
  const EquaUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory EquaUser.fromJson(Map<String, dynamic> json) => EquaUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
      );

  final String id;
  final String email;
  final String displayName;
}

class Membership {
  const Membership({
    required this.memberId,
    required this.householdId,
    required this.householdName,
    required this.role,
    required this.memberType,
    required this.capacityFactor,
    required this.isPrimary,
    this.weeklyMinutes,
    this.daysAvailable,
    this.roomScope,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        memberId: json['id'] as String,
        householdId: json['household_id'] as String,
        householdName: json['household_name'] as String,
        role: json['role'] as String,
        memberType: json['member_type'] as String,
        capacityFactor: (json['capacity_factor'] as num).toDouble(),
        isPrimary: json['is_primary'] as bool,
        weeklyMinutes: json['weekly_minutes'] as int?,
        daysAvailable: (json['days_available'] as List?)?.cast<int>(),
        roomScope: (json['room_scope'] as List?)?.cast<String>(),
      );

  final String memberId;
  final String householdId;
  final String householdName;
  final String role;
  final String memberType;
  final double capacityFactor;
  final bool isPrimary;
  final int? weeklyMinutes;
  final List<int>? daysAvailable;
  final List<String>? roomScope;
}

class HouseholdMemberInfo {
  const HouseholdMemberInfo({
    required this.id,
    required this.displayName,
    required this.role,
    required this.memberType,
    required this.isPrimary,
  });

  factory HouseholdMemberInfo.fromJson(Map<String, dynamic> json) =>
      HouseholdMemberInfo(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        role: json['role'] as String,
        memberType: json['member_type'] as String,
        isPrimary: json['is_primary'] as bool,
      );

  final String id;
  final String displayName;
  final String role;
  final String memberType;
  final bool isPrimary;
}

class HouseholdDetail {
  const HouseholdDetail({
    required this.id,
    required this.name,
    required this.members,
  });

  factory HouseholdDetail.fromJson(Map<String, dynamic> json) =>
      HouseholdDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        members: (json['members'] as List)
            .map((m) => HouseholdMemberInfo.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final List<HouseholdMemberInfo> members;
}

/// Fase 02: habitaciones y objetos de la casa.
class RoomObject {
  const RoomObject({
    required this.id,
    required this.name,
    required this.quantity,
    required this.source,
    required this.confirmed,
  });

  factory RoomObject.fromJson(Map<String, dynamic> json) => RoomObject(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        source: json['source'] as String,
        confirmed: json['confirmed'] as bool,
      );

  final String id;
  final String name;
  final int quantity;
  final String source;
  final bool confirmed;
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.type,
    required this.objectCount,
    this.floor,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        objectCount: json['object_count'] as int,
        floor: json['floor'] as String?,
      );

  final String id;
  final String name;
  final String type;
  final int objectCount;
  final String? floor;
}

class RoomDetail {
  const RoomDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.objects,
    this.floor,
  });

  factory RoomDetail.fromJson(Map<String, dynamic> json) => RoomDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        objects: (json['objects'] as List)
            .map((o) => RoomObject.fromJson(o as Map<String, dynamic>))
            .toList(),
        floor: json['floor'] as String?,
      );

  final String id;
  final String name;
  final String type;
  final List<RoomObject> objects;
  final String? floor;
}

/// Fase 03: plantillas de tareas con condiciones de tiempo.
class TaskCondition {
  const TaskCondition({
    required this.id,
    required this.label,
    required this.extraMinutes,
    required this.applies,
  });

  factory TaskCondition.fromJson(Map<String, dynamic> json) => TaskCondition(
        id: json['id'] as String,
        label: json['label'] as String,
        extraMinutes: json['extra_minutes'] as int,
        applies: json['applies'] as bool,
      );

  Map<String, dynamic> toJson() =>
      {'label': label, 'extra_minutes': extraMinutes, 'applies': applies};

  final String id;
  final String label;
  final int extraMinutes;
  final bool applies;
}

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.baseMinutes,
    required this.effort,
    required this.effortWeight,
    required this.frequency,
    required this.active,
    required this.conditions,
    required this.estimatedMinutes,
    required this.weightedMinutes,
    this.roomId,
    this.roomName,
    this.preferredWeekday,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        roomId: json['room_id'] as String?,
        roomName: json['room_name'] as String?,
        baseMinutes: json['base_minutes'] as int,
        effort: json['effort'] as String,
        effortWeight: (json['effort_weight'] as num).toDouble(),
        frequency: json['frequency'] as String,
        preferredWeekday: json['preferred_weekday'] as int?,
        active: json['active'] as bool,
        conditions: (json['conditions'] as List)
            .map((c) => TaskCondition.fromJson(c as Map<String, dynamic>))
            .toList(),
        estimatedMinutes: json['estimated_minutes'] as int,
        weightedMinutes: (json['weighted_minutes'] as num).toDouble(),
      );

  final String id;
  final String name;
  final String category;
  final String? roomId;
  final String? roomName;
  final int baseMinutes;
  final String effort;
  final double effortWeight;
  final String frequency;
  final int? preferredWeekday;
  final bool active;
  final List<TaskCondition> conditions;
  final int estimatedMinutes;
  final double weightedMinutes;
}

/// Fase 04: tareas concretas del día, selección voluntaria y carga.
class Assignee {
  const Assignee({
    required this.memberId,
    required this.displayName,
    this.completedAt,
  });

  factory Assignee.fromJson(Map<String, dynamic> json) => Assignee(
        memberId: json['member_id'] as String,
        displayName: json['display_name'] as String,
        completedAt: json['completed_at'] as String?,
      );

  final String memberId;
  final String displayName;
  final String? completedAt;
}

class DayTask {
  const DayTask({
    required this.id,
    required this.title,
    required this.estimatedMinutes,
    required this.weightedMinutes,
    required this.effort,
    required this.category,
    required this.scheduledDate,
    required this.status,
    required this.origin,
    required this.assignees,
    this.roomId,
    this.roomName,
    this.templateId,
  });

  factory DayTask.fromJson(Map<String, dynamic> json) => DayTask(
        id: json['id'] as String,
        title: json['title'] as String,
        estimatedMinutes: json['estimated_minutes'] as int,
        weightedMinutes: (json['weighted_minutes'] as num).toDouble(),
        effort: json['effort'] as String,
        category: json['category'] as String,
        roomId: json['room_id'] as String?,
        roomName: json['room_name'] as String?,
        templateId: json['template_id'] as String?,
        scheduledDate: json['scheduled_date'] as String,
        status: json['status'] as String,
        origin: json['origin'] as String,
        assignees: (json['assignees'] as List)
            .map((a) => Assignee.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String title;
  final int estimatedMinutes;
  final double weightedMinutes;
  final String effort;
  final String category;
  final String? roomId;
  final String? roomName;
  final String? templateId;
  final String scheduledDate;
  final String status;
  final String origin;
  final List<Assignee> assignees;

  bool isAssignedTo(String memberId) =>
      assignees.any((a) => a.memberId == memberId);
}

class TaskPreference {
  const TaskPreference({
    required this.id,
    required this.kind,
    this.templateId,
    this.category,
    this.templateName,
  });

  factory TaskPreference.fromJson(Map<String, dynamic> json) => TaskPreference(
        id: json['id'] as String,
        kind: json['kind'] as String,
        templateId: json['template_id'] as String?,
        category: json['category'] as String?,
        templateName: json['template_name'] as String?,
      );

  final String id;
  final String kind;
  final String? templateId;
  final String? category;
  final String? templateName;
}

class MemberLoad {
  const MemberLoad({
    required this.memberId,
    required this.displayName,
    required this.assignedMinutes,
    required this.capacityFactor,
    this.expectedMinutes,
    this.differenceMinutes,
    this.weeklyMinutes,
  });

  factory MemberLoad.fromJson(Map<String, dynamic> json) => MemberLoad(
        memberId: json['member_id'] as String,
        displayName: json['display_name'] as String,
        assignedMinutes: (json['assigned_minutes'] as num).toDouble(),
        expectedMinutes: (json['expected_minutes'] as num?)?.toDouble(),
        differenceMinutes: (json['difference_minutes'] as num?)?.toDouble(),
        weeklyMinutes: json['weekly_minutes'] as int?,
        capacityFactor: (json['capacity_factor'] as num).toDouble(),
      );

  final String memberId;
  final String displayName;
  final double assignedMinutes;
  final double? expectedMinutes;
  final double? differenceMinutes;
  final int? weeklyMinutes;
  final double capacityFactor;
}

class LoadResult {
  const LoadResult({
    required this.date,
    required this.singleMember,
    required this.totalMinutes,
    required this.members,
    this.suggestion,
    this.notice,
  });

  factory LoadResult.fromJson(Map<String, dynamic> json) => LoadResult(
        date: json['date'] as String,
        singleMember: json['single_member'] as bool,
        totalMinutes: (json['total_minutes'] as num).toDouble(),
        members: (json['members'] as List)
            .map((m) => MemberLoad.fromJson(m as Map<String, dynamic>))
            .toList(),
        suggestion: json['suggestion'] == null
            ? null
            : LoadSuggestion.fromJson(
                json['suggestion'] as Map<String, dynamic>),
        notice: json['notice'] as String?,
      );

  final String date;
  final bool singleMember;
  final double totalMinutes;
  final List<MemberLoad> members;
  final LoadSuggestion? suggestion;
  final String? notice;
}

class LoadSuggestion {
  const LoadSuggestion({
    required this.memberId,
    required this.displayName,
    required this.deficitMinutes,
    required this.candidates,
  });

  factory LoadSuggestion.fromJson(Map<String, dynamic> json) => LoadSuggestion(
        memberId: json['member_id'] as String,
        displayName: json['display_name'] as String,
        deficitMinutes: (json['deficit_minutes'] as num).toDouble(),
        candidates: (json['candidates'] as List)
            .map((t) => DayTask.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  final String memberId;
  final String displayName;
  final double deficitMinutes;
  final List<DayTask> candidates;
}
