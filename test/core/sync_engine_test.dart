import 'package:anaqa_mobile/core/config/api_config.dart';
import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/database/schema.dart';
import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/sync/outbox.dart';
import 'package:anaqa_mobile/core/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Outbox outbox;
  late FakeApi api;
  late SyncEngine engine;
  final now = DateTime.utc(2026, 11, 20, 12);

  setUp(() async {
    db = await createTestDatabase();
    outbox = Outbox(db);
    api = FakeApi();
    engine = SyncEngine(
      api: api,
      database: db,
      outbox: outbox,
      session: await sessionManagerWith(testSession),
      clock: () => now,
    );
  });

  Future<void> enqueue(String uuid, {List<String> deps = const []}) async {
    final d = await db.database;
    await d.transaction(
      (txn) => outbox.enqueue(
        txn,
        uuid: uuid,
        type: 'sale.create',
        branchId: 3,
        userId: 7,
        payload: {'rows': []},
        summary: 'بيع',
        dependencies: deps,
      ),
    );
  }

  test('bootstrap pages are applied with the cursor and initial completion is recorded', () async {
    var page = 0;
    api
      ..on(ApiEndpoints.bootstrap, (body, _) async {
        expect((body! as Map)['branch_id'], 3);
        expect((body as Map)['schema_version'], 1);
        return {'changes': seedChanges().sublist(0, 5), 'has_more': true, 'cursor': 'c1'};
      })
      ..on(ApiEndpoints.pull, (body, _) async {
        page++;
        expect((body! as Map)['cursor'], 'c1');
        return {'changes': seedChanges().sublist(5), 'has_more': false, 'cursor': 'c2'};
      });

    final report = await engine.pull();

    expect(report.pulledChanges, seedChanges().length);
    expect(page, 1);
    expect(await engine.initialSyncCompleted, isTrue);
    final d = await db.database;
    expect((await d.query(Tables.variants)).length, 2);
    final stock = (await d.query(Tables.stocks)).single;
    expect(stock['variant_id'], 12);
    expect(stock['average_cost'], 2000);
    expect((await d.query(Tables.syncState, where: "key = 'cursor'")).single['value'], 'c2');
  });

  test('a 409 on pull clears the read cache and bootstraps again without touching the outbox', () async {
    await enqueue('op-1');
    final d = await db.database;
    await d.insert(Tables.syncState, {'key': 'cursor', 'value': 'stale'});
    await d.insert(Tables.categories, {'id': 99, 'name': 'قديم'});
    api
      ..on(ApiEndpoints.pull, (_, _) async => throw const ServerException('expired', statusCode: 409))
      ..on(ApiEndpoints.bootstrap, (_, _) async => {'changes': seedChanges(), 'has_more': false, 'cursor': 'fresh'});

    await engine.pull();

    expect(await d.query(Tables.categories, where: 'id = 99'), isEmpty);
    expect((await d.query(Tables.categories)).single['id'], 1);
    expect((await outbox.find('op-1'))!.status, OutboxStatus.pending);
  });

  test('push maps results by uuid: accepted, review, and retry with backoff', () async {
    await enqueue('a');
    await enqueue('b');
    await enqueue('c');
    final d = await db.database;
    await d.insert(Tables.stocks, {'variant_id': 12, 'id': 100, 'revision': 'old'});
    api.on(ApiEndpoints.push, (body, _) async {
      final ops = (body! as Map)['operations'] as List;
      expect(ops.map((o) => (o as Map)['operation_uuid']), ['a', 'b', 'c']);
      return {
        'results': [
          {
            'operation_uuid': 'c',
            'status': 'retryable',
            'result': {'retry_after_seconds': 30},
          },
          {
            'operation_uuid': 'a',
            'status': 'accepted',
            'result': {
              'id': 1,
              'number': 'SL-1',
              'stock_revisions': {'12': 'new'},
            },
          },
          {
            'operation_uuid': 'b',
            'status': 'validation_failed',
            'result': {
              'code': 'validation_failed',
              'message': 'راجع البيانات',
              'errors': {
                'rows': ['الكمية غير متوفرة'],
              },
            },
          },
        ],
      };
    });

    final report = await engine.push();

    expect(report.accepted, 1);
    expect(report.rejected, 1);
    expect((await outbox.find('a'))!.status, OutboxStatus.accepted);
    final b = (await outbox.find('b'))!;
    expect(b.status, OutboxStatus.review);
    expect(b.errorMessage, 'الكمية غير متوفرة');
    final c = (await outbox.find('c'))!;
    expect(c.status, OutboxStatus.pending);
    expect(c.attempts, 1);
    expect(c.nextAttemptAt!.isAfter(now.add(const Duration(seconds: 29))), isTrue);
    // مراجعة المخزون الجديدة من نتيجة البيع.
    expect((await d.query(Tables.stocks)).single['revision'], 'new');
    // المؤجلة لا تُرسل قبل موعدها.
    expect(await outbox.due(userId: 7, branchId: 3, now: now), isEmpty);
  });

  test('a child waits until its parent is accepted, and is blocked if the parent is rejected', () async {
    await enqueue('parent');
    await enqueue('child', deps: ['parent']);
    expect((await outbox.due(userId: 7, branchId: 3)).map((o) => o.uuid), ['parent', 'child']);
    expect((await outbox.due(userId: 7, branchId: 3, limit: 1)).map((o) => o.uuid), ['parent']);

    final d = await db.database;
    await d.transaction((txn) => outbox.markReview(txn, 'parent', code: 'x', message: 'x'));
    expect(await outbox.due(userId: 7, branchId: 3), isEmpty);
  });

  test('network loss keeps operations pending with the same uuid', () async {
    await enqueue('a');
    api.on(ApiEndpoints.push, (_, _) async => throw const NetworkException());
    final report = await engine.push();
    expect(report.offline, isTrue);
    final op = (await outbox.find('a'))!;
    expect(op.status, OutboxStatus.pending);
    expect(op.attempts, 0);
  });

  test('an envelope rejection (422) moves the whole batch to review', () async {
    await enqueue('a');
    api.on(
      ApiEndpoints.push,
      (_, _) async => throw const ServerException(
        'bad',
        statusCode: 422,
        body: {
          'errors': {
            'schema_version': ['invalid'],
          },
        },
      ),
    );
    final report = await engine.push();
    expect(report.rejected, 1);
    expect((await outbox.find('a'))!.errorMessage, 'invalid');
  });
}
