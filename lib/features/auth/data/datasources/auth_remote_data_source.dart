import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);

  final ApiClient _api;

  /// POST /auth/login. يسجل الجهاز (أو يدوّر توكنه) ويرجع الجلسة على أول فرع فعّال.
  Future<Session> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
  }) async {
    final json = await _api.post(
      ApiEndpoints.login,
      body: {'username': username, 'password': password, 'device_id': deviceId, 'device_name': deviceName},
    );
    final user = json['user'] is Map ? (json['user']! as Map).cast<String, Object?>() : const <String, Object?>{};
    final token = json['token'];
    if (token is! String || user['id'] is! int) {
      throw const FormatException('رد تسجيل الدخول غير مكتمل');
    }
    final branches = [
      for (final b in (user['branches'] as List?) ?? const [])
        if (b is Map) Branch.fromJson(b.cast<String, Object?>()),
    ].where((b) => b.isActive).toList();
    if (branches.isEmpty) throw const FormatException('لا يوجد فرع فعّال مسموح لهذا الحساب');
    return Session(
      token: token,
      deviceId: (json['device_id'] as String?) ?? deviceId,
      userId: user['id']! as int,
      userName: (user['name'] as String?) ?? username,
      username: (user['username'] as String?) ?? username,
      role: (user['role'] as String?) ?? '',
      permissions: {...((user['permissions'] as List?) ?? const []).whereType<String>()},
      branches: branches,
      branchId: branches.first.id,
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? ''),
    );
  }

  /// POST /auth/logout: يبطل التوكن الحالي على السيرفر.
  Future<void> logout() => _api.post(ApiEndpoints.logout);
}
