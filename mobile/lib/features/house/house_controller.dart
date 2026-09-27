import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../household/households_controller.dart';

/// Habitaciones del hogar activo.
final roomsProvider = AsyncNotifierProvider<RoomsController, List<Room>>(
  RoomsController.new,
);

class RoomsController extends AsyncNotifier<List<Room>> {
  @override
  Future<List<Room>> build() async {
    final active = ref.watch(activeMembershipProvider);
    if (active == null) return const [];
    final res = await ref
        .read(dioProvider)
        .get('/api/v1/households/${active.householdId}/rooms');
    return (res.data as List)
        .map((r) => Room.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Room> addRoom(String name, String type, String? floor) async {
    final hid = ref.read(activeMembershipProvider)!.householdId;
    final res = await ref.read(dioProvider).post(
      '/api/v1/households/$hid/rooms',
      data: {'name': name, 'type': type, 'floor': floor},
    );
    ref.invalidateSelf();
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateRoom(
    String roomId, {
    String? name,
    String? floor,
  }) async {
    await ref.read(dioProvider).patch(
      '/api/v1/rooms/$roomId',
      data: {'name': ?name, 'floor': ?floor},
    );
    ref.invalidateSelf();
  }

  Future<void> deleteRoom(String roomId) async {
    await ref.read(dioProvider).delete('/api/v1/rooms/$roomId');
    ref.invalidateSelf();
  }

  Future<void> addObject(String roomId, String name, int quantity) async {
    await ref.read(dioProvider).post(
      '/api/v1/rooms/$roomId/objects',
      data: {'name': name, 'quantity': quantity},
    );
    ref.invalidate(roomDetailProvider(roomId));
    ref.invalidateSelf();
  }

  Future<void> updateObject(
    String roomId,
    String objectId, {
    String? name,
    int? quantity,
    bool? confirmed,
  }) async {
    await ref.read(dioProvider).patch(
      '/api/v1/objects/$objectId',
      data: {
        'name': ?name,
        'quantity': ?quantity,
        'confirmed': ?confirmed,
      },
    );
    ref.invalidate(roomDetailProvider(roomId));
    ref.invalidateSelf();
  }

  Future<void> deleteObject(String roomId, String objectId) async {
    await ref.read(dioProvider).delete('/api/v1/objects/$objectId');
    ref.invalidate(roomDetailProvider(roomId));
    ref.invalidateSelf();
  }
}

/// Detalle de una habitación (incluye sus objetos).
final roomDetailProvider =
    FutureProvider.family<RoomDetail, String>((ref, roomId) async {
  final res = await ref.read(dioProvider).get('/api/v1/rooms/$roomId');
  return RoomDetail.fromJson(res.data as Map<String, dynamic>);
});
