import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../household/households_controller.dart';

/// Subida y análisis de fotos. La IA propone; la persona confirma.
final photosControllerProvider =
    Provider<PhotosController>(PhotosController.new);

class PhotosController {
  PhotosController(this._ref);

  final Ref _ref;

  Future<HousePhoto> upload({
    required Uint8List bytes,
    required String filename,
    String? roomId,
    String purpose = 'room_scan',
  }) async {
    final hid = _ref.read(activeMembershipProvider)!.householdId;
    final res = await _ref.read(dioProvider).post(
      '/api/v1/households/$hid/photos',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'purpose': purpose,
        'room_id': ?roomId,
      }),
    );
    return HousePhoto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HousePhoto> analyze(String photoId) async {
    final res = await _ref
        .read(dioProvider)
        .post('/api/v1/photos/$photoId/analyze');
    return HousePhoto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> confirm(
    String analysisId,
    List<DetectedObject> objects,
  ) async {
    await _ref.read(dioProvider).patch(
      '/api/v1/analyses/$analysisId/confirm',
      data: {'objects': objects.map((o) => o.toJson()).toList()},
    );
  }
}
