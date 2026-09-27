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
