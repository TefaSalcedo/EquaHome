import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

/// Estado de autenticación: `null` = sin sesión; EquaUser = autenticado.
/// `AsyncValue.loading` mientras restaura la sesión guardada.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, EquaUser?>(AuthController.new);

class AuthController extends AsyncNotifier<EquaUser?> {
  @override
  Future<EquaUser?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) return null;

    final dio = ref.read(dioProvider);
    try {
      final res = await dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      await storage.save(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      final me = await dio.get('/api/v1/auth/me');
      return EquaUser.fromJson(me.data as Map<String, dynamic>);
    } on DioException {
      await storage.clear();
      return null;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await ref.read(tokenStorageProvider).save(
          access: data['access_token'] as String,
          refresh: data['refresh_token'] as String,
        );
    final me = await ref.read(dioProvider).get('/api/v1/auth/me');
    state = AsyncData(EquaUser.fromJson(me.data as Map<String, dynamic>));
  }

  Future<void> login({required String email, required String password}) async {
    final res = await ref.read(dioProvider).post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'skipAuth': true}),
    );
    await _saveSession(res.data as Map<String, dynamic>);
  }

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final res = await ref.read(dioProvider).post(
      '/api/v1/auth/register',
      data: {
        'display_name': displayName,
        'email': email,
        'password': password,
      },
      options: Options(extra: {'skipAuth': true}),
    );
    await _saveSession(res.data as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }
}
