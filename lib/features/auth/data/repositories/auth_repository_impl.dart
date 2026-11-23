import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../../../../core/config/app_settings.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/session/session_storage.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SessionManager session,
    required AppSettings settings,
    required SyncEngine sync,
    Uuid uuid = const Uuid(),
  }) : _remote = remote,
       _session = session,
       _settings = settings,
       _sync = sync,
       _uuid = uuid;

  final AuthRemoteDataSource _remote;
  final SessionManager _session;
  final AppSettings _settings;
  final SyncEngine _sync;
  final Uuid _uuid;

  @override
  Future<Result<Session>> login({required String username, required String password}) async {
    final storage = _session.storage;
    // UUID تسجيل الجهاز ثابت لكل حساب على هذا الهاتف (لا يُشارك بين حسابين).
    final deviceId = await storage.deviceIdFor(username) ?? _uuid.v4();
    Session session;
    try {
      session = await _remote.login(
        username: username,
        password: password,
        deviceId: deviceId,
        deviceName: _settings.deviceName,
      );
    } on ApiNotConfiguredException {
      return const Err(ValidationFailure('اكتب عنوان السيرفر أولًا'));
    } on NetworkException {
      return const Err(NetworkFailure('تعذر الوصول للسيرفر. تأكد من العنوان ومن الاتصال بالشبكة'));
    } on UnauthorizedException {
      return const Err(ValidationFailure('اسم المستخدم أو كلمة المرور غير صحيحة'));
    } on ServerException catch (e) {
      // 422 = بيانات خاطئة، 403 = حساب موقوف/جهاز مبطل، 429 = محاولات كثيرة.
      if (e.statusCode == 429) return const Err(ValidationFailure('محاولات كثيرة، انتظر قليلًا ثم حاول من جديد'));
      return Err(
        e.isPermanent ? ValidationFailure(e.displayMessage) : ServerFailure(e.message, statusCode: e.statusCode),
      );
    } on FormatException catch (e) {
      return Err(ServerFailure(e.message));
    }
    await storage.saveDeviceId(username, session.deviceId);

    // البيانات المحلية تخص مستخدمًا وفرعًا: إن تغيّر أحدهما نبدأ تنزيلًا جديدًا.
    final previous = await storage.lastScope();
    if (previous != scopeOf(session)) await _sync.resetCache();
    await _session.start(session);
    return Ok(session);
  }

  @override
  Future<Session?> restoreSession() async {
    final session = await _session.restore();
    if (session?.expiresAt != null && session!.expiresAt!.isBefore(DateTime.now())) {
      await _session.end();
      return null;
    }
    return session;
  }

  @override
  Future<Session> switchBranch(int branchId) async {
    final next = _session.requireSession.copyWith(branchId: branchId);
    await _sync.resetCache();
    await _session.start(next);
    return next;
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } on Exception catch (e) {
      // بدون إنترنت أو توكن منتهي: نكمل الخروج محليًا.
      developer.log('Remote logout failed', error: e, name: 'auth');
    }
    await _sync.resetCache();
    await _session.end();
  }

  @override
  Future<void> expire() => _session.end();
}
