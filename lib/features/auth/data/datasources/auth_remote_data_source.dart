import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);

  final ApiClient _api;

  /// TODO(api): طابق شكل الرد مع الـ API (المواصفات: `{ token, user: { id, name, role, branch_id } }`).
  Future<Session> login({required String username, required String password, required String deviceName}) async {
    final response = await _api.post(
      ApiEndpoints.login,
      body: {'username': username, 'password': password, 'device_name': deviceName},
    );
    final json = response is Map<String, Object?> ? response : const <String, Object?>{};
    final user = (json['user'] as Map<String, Object?>?) ?? const {};
    final branchId = user['branch_id'];
    if (json['token'] is! String || user['id'] is! int || branchId is! int) {
      throw const FormatException('رد تسجيل الدخول غير مكتمل (token / user.id / user.branch_id)');
    }
    return Session(
      token: json['token']! as String,
      userId: user['id']! as int,
      userName: (user['name'] as String?) ?? username,
      role: UserRole.fromApi(user['role'] as String?),
      branchId: branchId,
    );
  }
}
