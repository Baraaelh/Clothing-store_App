import '../../../../core/config/app_settings.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/result.dart';
import '../../../online_orders/data/datasources/online_orders_local_data_source.dart';
import '../../../pos/data/datasources/pos_local_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SessionManager session,
    required AppSettings settings,
    required PosLocalDataSource pos,
    required OnlineOrdersLocalDataSource orders,
    this.allowDevLogin = false,
  }) : _remote = remote,
       _session = session,
       _settings = settings,
       _pos = pos,
       _orders = orders;

  final AuthRemoteDataSource _remote;
  final SessionManager _session;
  final AppSettings _settings;
  final PosLocalDataSource _pos;
  final OnlineOrdersLocalDataSource _orders;

  /// وضع التطوير بدون API: أي اسم وكلمة مرور تدخل كمالك على الفرع 1.
  final bool allowDevLogin;

  @override
  Future<Result<Session>> login({required String username, required String password}) async {
    Session session;
    try {
      session = await _remote.login(username: username, password: password, deviceName: _settings.deviceName);
    } on ApiNotConfiguredException {
      if (!allowDevLogin) return const Err(ServerFailure('الاتصال بالسيرفر غير مضبوط'));
      session = Session(token: 'dev', userId: 0, userName: username, role: UserRole.owner, branchId: 1);
    } on NetworkException {
      return const Err(NetworkFailure('تسجيل الدخول يحتاج اتصالًا بالإنترنت'));
    } on UnauthorizedException {
      return const Err(ValidationFailure('اسم المستخدم أو كلمة المرور غير صحيحة'));
    } on ServerException catch (e) {
      // 422 = بيانات خاطئة، 403 = حساب موقوف أو بدون فرع: رسالة السيرفر تشرح السبب.
      return Err(e.isPermanent ? ValidationFailure(e.message) : ServerFailure(e.message, statusCode: e.statusCode));
    } on FormatException catch (e) {
      return Err(ServerFailure(e.message));
    }

    final previousBranch = await _session.lastBranchId();
    if (previousBranch != null && previousBranch != session.branchId) {
      await _pos.clearCatalog();
      await _orders.clearSynced();
    }
    await _session.start(session);
    return Ok(session);
  }

  @override
  Future<Session?> restoreSession() => _session.restore();

  @override
  Future<void> logout() => _session.end();
}
