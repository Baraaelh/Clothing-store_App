import 'package:anaqa_mobile/core/config/app_settings.dart';
import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/error/failures.dart';
import 'package:anaqa_mobile/core/session/session.dart';
import 'package:anaqa_mobile/core/session/session_manager.dart';
import 'package:anaqa_mobile/core/sync/sync_queue.dart';
import 'package:anaqa_mobile/core/utils/result.dart';
import 'package:anaqa_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:anaqa_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:anaqa_mobile/features/auth/domain/usecases/login.dart';
import 'package:anaqa_mobile/features/online_orders/data/datasources/online_orders_local_data_source.dart';
import 'package:anaqa_mobile/features/pos/data/datasources/pos_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

Session session({int branchId = 1}) =>
    Session(token: 'tok', userId: 5, userName: 'علي', role: UserRole.cashier, branchId: branchId);

void main() {
  late AppDatabase db;
  late MockRemote remote;
  late InMemorySessionStorage storage;
  late SessionManager manager;
  late PosLocalDataSource pos;

  AuthRepositoryImpl repository({bool dev = false}) => AuthRepositoryImpl(
    remote: remote,
    session: manager,
    settings: const AppSettings(deviceName: 'tablet-1'),
    pos: pos,
    orders: OnlineOrdersLocalDataSource(db, SyncQueue(db)),
    allowDevLogin: dev,
  );

  void remoteReturns(Session s) => when(
    () => remote.login(
      username: any(named: 'username'),
      password: any(named: 'password'),
      deviceName: 'tablet-1',
    ),
  ).thenAnswer((_) async => s);

  void remoteThrows(Exception e) => when(
    () => remote.login(
      username: any(named: 'username'),
      password: any(named: 'password'),
      deviceName: any(named: 'deviceName'),
    ),
  ).thenThrow(e);

  setUp(() async {
    db = await createTestDatabase();
    remote = MockRemote();
    storage = InMemorySessionStorage();
    manager = SessionManager(storage);
    pos = PosLocalDataSource(db, SyncQueue(db));
    await pos.replaceCatalog([catalogRow(variantId: 1)]);
  });

  tearDown(() => db.close());

  test('successful login saves the session and sends the device name', () async {
    remoteReturns(session());

    final result = await repository().login(username: 'ali', password: 'x');

    expect((result as Ok<Session>).value, session());
    expect(manager.current, session());
    expect(storage.session, session());
  });

  test('wrong credentials (422) shows the server message', () async {
    remoteThrows(const ServerException('بيانات الدخول غير صحيحة', statusCode: 422));

    final result = await repository().login(username: 'ali', password: 'x');

    expect((result as Err<Session>).failure, const ValidationFailure('بيانات الدخول غير صحيحة'));
    expect(manager.current, isNull);
  });

  test('no internet → clear message, nothing saved', () async {
    remoteThrows(const NetworkException());

    final result = await repository().login(username: 'ali', password: 'x');

    expect((result as Err<Session>).failure, isA<NetworkFailure>());
    expect(storage.session, isNull);
  });

  test('logging in to a different branch clears the previous branch catalog', () async {
    remoteReturns(session(branchId: 1));
    await repository().login(username: 'a', password: 'x');
    await repository().logout();

    remoteReturns(session(branchId: 2));
    await repository().login(username: 'a', password: 'x');

    expect(await pos.isCatalogEmpty(), isTrue);
  });

  test('same branch again keeps the local catalog', () async {
    remoteReturns(session());
    await repository().login(username: 'a', password: 'x');
    await repository().logout();
    await repository().login(username: 'a', password: 'x');

    expect(await pos.isCatalogEmpty(), isFalse);
  });

  test('demo login only when allowed and the API is not configured', () async {
    remoteThrows(const ApiNotConfiguredException('/login'));

    expect((await repository().login(username: 'a', password: 'x')) is Err<Session>, isTrue);
    final dev = await repository(dev: true).login(username: 'تجربة', password: 'x');
    expect((dev as Ok<Session>).value.role, UserRole.owner);
  });

  test('Login use case validates empty fields before calling the server', () async {
    final login = Login(repository());

    expect(
      ((await login(const LoginParams(username: ' ', password: 'x'))) as Err).failure.message,
      'أدخل اسم المستخدم',
    );
    expect(((await login(const LoginParams(username: 'a', password: ''))) as Err).failure.message, 'أدخل كلمة المرور');
    verifyNever(
      () => remote.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    );
  });

  test('restore reads the saved session (works offline)', () async {
    storage.session = session();

    expect(await repository().restoreSession(), session());
    expect(manager.current, session());
  });
}
