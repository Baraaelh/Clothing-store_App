import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/sync/sync_handler.dart';
import 'package:anaqa_mobile/core/sync/sync_operation.dart';
import 'package:anaqa_mobile/core/sync/sync_queue.dart';
import 'package:anaqa_mobile/core/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

/// Handler وهمي: يرمي الاستثناءات المحددة لكل عملية بالترتيب.
class FakeHandler implements SyncHandler {
  FakeHandler([this.errors = const {}]);

  final Map<String, List<Exception>> errors;
  final pushed = <String>[];
  final permanentlyFailed = <String>[];

  @override
  String get operation => 'test.op';

  @override
  Future<void> push(SyncOperation op) async {
    final queue = errors[op.entityId];
    if (queue != null && queue.isNotEmpty) throw queue.removeAt(0);
    pushed.add(op.entityId);
  }

  @override
  Future<void> onPermanentFailure(SyncOperation op, String error) async => permanentlyFailed.add(op.entityId);
}

class FakePuller implements PullHandler {
  FakePuller([this.error]);

  final Exception? error;
  int calls = 0;

  @override
  String get name => 'fake';

  @override
  Future<void> pull() async {
    calls++;
    if (error != null) throw error!;
  }
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;

  setUp(() async {
    db = await createTestDatabase();
    queue = SyncQueue(db);
  });

  tearDown(() => db.close());

  Future<void> enqueue(String id) async {
    final database = await db.database;
    await queue.enqueue(database, operation: 'test.op', entityId: id, payload: {'id': id});
  }

  test('pushes queued operations in order, removes them, then pulls', () async {
    await enqueue('a');
    await enqueue('b');
    final handler = FakeHandler();
    final puller = FakePuller();

    final report = await SyncService(queue: queue, handlers: [handler], pullers: [puller]).run();

    expect(handler.pushed, ['a', 'b']);
    expect(report, const SyncReport(pushed: 2, pulled: ['fake']));
    expect(await queue.counts(), (pending: 0, failed: 0));
    expect(puller.calls, 1);
  });

  test('stops on network error and keeps the remaining operations', () async {
    await enqueue('a');
    await enqueue('b');
    final handler = FakeHandler({
      'b': [const NetworkException()],
    });
    final puller = FakePuller();

    final report = await SyncService(queue: queue, handlers: [handler], pullers: [puller]).run();

    expect(report!.offline, isTrue);
    expect(handler.pushed, ['a']);
    expect((await queue.pending()).map((o) => o.entityId), ['b']);
    expect(puller.calls, 0, reason: 'no pull while offline');
  });

  test('permanent server error (422) marks the operation failed and continues', () async {
    await enqueue('a');
    await enqueue('b');
    final handler = FakeHandler({
      'a': [const ServerException('invalid', statusCode: 422)],
    });

    final report = await SyncService(queue: queue, handlers: [handler], pullers: []).run();

    expect(report, const SyncReport(pushed: 1, failed: 1));
    expect(handler.permanentlyFailed, ['a']);
    expect(handler.pushed, ['b']);
    expect(await queue.counts(), (pending: 0, failed: 1));
  });

  test('temporary server error (500) is retried on the next run', () async {
    await enqueue('a');
    final handler = FakeHandler({
      'a': [const ServerException('down', statusCode: 500)],
    });
    final service = SyncService(queue: queue, handlers: [handler], pullers: []);

    await service.run();
    expect((await queue.pending()).single.attempts, 1);

    await service.run();
    expect(handler.pushed, ['a']);
    expect(await queue.counts(), (pending: 0, failed: 0));
  });

  test('gives up after maxAttempts temporary failures', () async {
    await enqueue('a');
    final handler = FakeHandler({'a': List.generate(5, (_) => const ServerException('down', statusCode: 503))});
    final service = SyncService(queue: queue, handlers: [handler], pullers: [], maxAttempts: 3);

    for (var i = 0; i < 3; i++) {
      await service.run();
    }

    expect(await queue.counts(), (pending: 0, failed: 1));
    expect(handler.permanentlyFailed, ['a']);
  });

  test('API not configured: nothing is lost', () async {
    await enqueue('a');
    final handler = FakeHandler({
      'a': [const ApiNotConfiguredException('/sales')],
    });

    final report = await SyncService(queue: queue, handlers: [handler], pullers: []).run();

    expect(report!.notConfigured, isTrue);
    expect(await queue.counts(), (pending: 1, failed: 0));
  });

  test('retryFailed puts failed operations back in the queue', () async {
    await enqueue('a');
    await SyncService(
      queue: queue,
      handlers: [
        FakeHandler({
          'a': [const ServerException('bad', statusCode: 400)],
        }),
      ],
      pullers: [],
    ).run();

    expect(await queue.retryFailed(), 1);
    expect(await queue.counts(), (pending: 1, failed: 0));
  });

  test('concurrent run returns null instead of running twice', () async {
    await enqueue('a');
    final service = SyncService(queue: queue, handlers: [FakeHandler()], pullers: []);

    final results = await Future.wait([service.run(), service.run()]);

    expect(results.whereType<SyncReport>(), hasLength(1));
  });

  test('401 stops the sync and leaves every operation untouched', () async {
    await enqueue('a');
    await enqueue('b');
    final handler = FakeHandler({
      'a': [const UnauthorizedException()],
    });
    final puller = FakePuller();

    final report = await SyncService(queue: queue, handlers: [handler], pullers: [puller]).run();

    expect(report!.unauthorized, isTrue);
    expect(handler.pushed, isEmpty);
    expect(handler.permanentlyFailed, isEmpty);
    expect((await queue.pending()).map((o) => (o.entityId, o.attempts)), [('a', 0), ('b', 0)]);
    expect(puller.calls, 0);
  });
}
