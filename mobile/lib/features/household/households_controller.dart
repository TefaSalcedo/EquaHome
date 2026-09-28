import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// Membresías del usuario actual: una persona puede tener varios hogares.
final householdsControllerProvider =
    AsyncNotifierProvider<HouseholdsController, List<Membership>>(
  HouseholdsController.new,
);

class HouseholdsController extends AsyncNotifier<List<Membership>> {
  @override
  Future<List<Membership>> build() async {
    final user = await ref.watch(authControllerProvider.future);
    if (user == null) return const [];
    final res =
        await ref.read(dioProvider).get('/api/v1/members/me/households');
    return (res.data as List)
        .map((m) => Membership.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> createHousehold(String name) async {
    await ref.read(dioProvider).post('/api/v1/households', data: {'name': name});
    ref.invalidateSelf();
  }

  Future<void> joinHousehold(String code) async {
    await ref
        .read(dioProvider)
        .post('/api/v1/households/join', data: {'code': code});
    ref.invalidateSelf();
  }

  Future<String> createInvite(String householdId) async {
    final res = await ref
        .read(dioProvider)
        .post('/api/v1/households/$householdId/invitations');
    return res.data['code'] as String;
  }

  Future<void> setPrimary(String householdId) async {
    await ref
        .read(dioProvider)
        .patch('/api/v1/members/me/households/$householdId/primary');
    ref.invalidateSelf();
  }
}

/// Hogar activo: por defecto la residencia principal (o la primera).
final selectedHouseholdProvider = NotifierProvider<SelectedHousehold, String?>(
  SelectedHousehold.new,
);

class SelectedHousehold extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String householdId) => state = householdId;
}

/// Membresía del hogar activo: el seleccionado, o la residencia principal,
/// o el primero de la lista.
final activeMembershipProvider = Provider<Membership?>((ref) {
  final memberships =
      ref.watch(householdsControllerProvider).value ?? const <Membership>[];
  if (memberships.isEmpty) return null;
  final selected = ref.watch(selectedHouseholdProvider);
  return memberships.firstWhere(
    (m) => m.householdId == selected,
    orElse: () => memberships.firstWhere(
      (m) => m.isPrimary,
      orElse: () => memberships.first,
    ),
  );
});

/// Detalle del hogar activo (miembros incluidos).
final householdDetailProvider = FutureProvider<HouseholdDetail>((ref) async {
  final active = ref.watch(activeMembershipProvider);
  if (active == null) {
    throw StateError('Sin hogar');
  }
  final res =
      await ref.read(dioProvider).get('/api/v1/households/${active.householdId}');
  return HouseholdDetail.fromJson(res.data as Map<String, dynamic>);
});
