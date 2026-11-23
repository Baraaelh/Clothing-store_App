import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:sqflite/sqflite.dart';

import '../config/api_config.dart';
import '../database/app_database.dart';
import '../database/schema.dart';
import '../error/exceptions.dart';
import '../network/api_client.dart';
import '../session/session_manager.dart';
import 'change_applier.dart';
import 'outbox.dart';

/// أثر قبول أو رفض عملية على البيانات المحلية (مثل تحديث حالة فاتورة الجهاز).
abstract interface class OperationHandler {
  String get type;

  Future<void> onAccepted(Transaction txn, OutboxOperation op, Map<String, Object?> result);

  Future<void> onRejected(Transaction txn, OutboxOperation op);
}

/// نتيجة دورة مزامنة واحدة.
class SyncReport extends Equatable {
  const SyncReport({
    this.accepted = 0,
    this.rejected = 0,
    this.pulledChanges = 0,
    this.offline = false,
    this.notConfigured = false,
    this.unauthorized = false,
    this.error,
  });

  final int accepted;
  final int rejected;
  final int pulledChanges;
  final bool offline;
  final bool notConfigured;

  /// 401: الجلسة انتهت. العمليات تبقى في الـ Outbox كما هي.
  final bool unauthorized;

  /// خطأ غير متوقع (للعرض فقط).
  final String? error;

  bool get stopped => offline || notConfigured || unauthorized;

  SyncReport merge(SyncReport other) => SyncReport(
    accepted: accepted + other.accepted,
    rejected: rejected + other.rejected,
    pulledChanges: pulledChanges + other.pulledChanges,
    offline: offline || other.offline,
    notConfigured: notConfigured || other.notConfigured,
    unauthorized: unauthorized || other.unauthorized,
    error: error ?? other.error,
  );

  @override
  List<Object?> get props => [accepted, rejected, pulledChanges, offline, notConfigured, unauthorized, error];
}

/// مفاتيح جدول sync_state.
abstract final class SyncKeys {
  static const cursor = 'cursor';
  static const syncUuid = 'sync_uuid';
  static const initialCompleted = 'initial_completed';
  static const lastPullAt = 'last_pull_at';
  static const operationState = 'operation_state';
}

/// محرك المزامنة حسب عقد API v1:
/// 1. push: يرسل عمليات الـ Outbox على دفعات (20) ويطبق نتيجة كل عملية بالـ operation_uuid.
/// 2. pull: Bootstrap أول مرة ثم Pull بالـ cursor، وكل صفحة تُطبق مع حفظ الـ cursor في transaction واحدة.
class SyncEngine {
  SyncEngine({
    required ApiClient api,
    required AppDatabase database,
    required Outbox outbox,
    required SessionManager session,
    List<OperationHandler> handlers = const [],
    ChangeApplier applier = const ChangeApplier(),
    Random? random,
    DateTime Function()? clock,
    this.pageSize = 100,
  }) : _api = api,
       _db = database,
       _outbox = outbox,
       _session = session,
       _handlers = {for (final h in handlers) h.type: h},
       _applier = applier,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final AppDatabase _db;
  final Outbox _outbox;
  final SessionManager _session;
  final Map<String, OperationHandler> _handlers;
  final ChangeApplier _applier;
  final Random _random;
  final DateTime Function() _clock;
  final int pageSize;

  bool _running = false;

  bool get isRunning => _running;

  /// دورة كاملة. ترجع `null` إن كانت هناك دورة جارية.
  Future<SyncReport?> run() async {
    if (_running) return null;
    _running = true;
    try {
      final push = await this.push();
      if (push.stopped) return push;
      final pull = await this.pull();
      if (pull.stopped) return push.merge(pull);
      // العمليات التي كانت تنتظر أصلًا قُبل في هذه الدورة.
      final again = await this.push();
      final state = await _refreshOperationState();
      return push.merge(pull).merge(again).merge(state);
    } finally {
      _running = false;
    }
  }

  // ---------------------------------------------------------------- push

  Future<SyncReport> push() async {
    final session = _session.current;
    if (session == null) return const SyncReport();
    var report = const SyncReport();
    final sentThisRun = <String>{};
    while (true) {
      final batch = (await _outbox.due(
        userId: session.userId,
        branchId: session.branchId,
        now: _clock(),
      )).where((op) => !sentThisRun.contains(op.uuid)).toList();
      if (batch.isEmpty) return report;
      sentThisRun.addAll(batch.map((op) => op.uuid));

      final Map<String, Object?> response;
      try {
        response = await _api.post(
          ApiEndpoints.push,
          body: {
            'schema_version': ApiConfig.schemaVersion,
            'operations': [for (final op in batch) op.toWire()],
          },
        );
      } on NetworkException {
        return report.merge(const SyncReport(offline: true));
      } on UnauthorizedException {
        return report.merge(const SyncReport(unauthorized: true));
      } on ApiNotConfiguredException {
        return report.merge(const SyncReport(notConfigured: true));
      } on ServerException catch (e) {
        if (e.isPermanent) {
          // رفض الدفعة كلها قبل تنفيذها (422 غلاف/نسخة، 403 فرع غير مسموح): تحتاج مراجعة.
          final db = await _db.database;
          await db.transaction((txn) async {
            for (final op in batch) {
              await _reject(txn, op, code: 'http_${e.statusCode}', message: e.displayMessage);
            }
          });
          report = report.merge(SyncReport(rejected: batch.length));
          continue;
        }
        for (final op in batch) {
          await _scheduleRetry(op, code: 'http_${e.statusCode ?? 0}', message: e.message, retryAfter: e.retryAfter);
        }
        return report.merge(SyncReport(error: e.message));
      }

      final results = response['results'];
      final byUuid = <String, Map<String, Object?>>{
        if (results is List)
          for (final r in results.whereType<Map<Object?, Object?>>())
            '${r['operation_uuid']}': r.cast<String, Object?>(),
      };
      final db = await _db.database;
      var accepted = 0;
      var rejected = 0;
      final retries = <(OutboxOperation, String, String, Duration?)>[];
      await db.transaction((txn) async {
        for (final op in batch) {
          final r = byUuid[op.uuid];
          if (r == null) {
            retries.add((op, 'missing_result', 'لم يرد السيرفر بنتيجة هذه العملية', null));
            continue;
          }
          final status = r['status'];
          final result = r['result'] is Map ? (r['result']! as Map).cast<String, Object?>() : <String, Object?>{};
          switch (status) {
            case 'accepted' || 'already_applied':
              await _accept(txn, op, result);
              accepted++;
            case 'retryable' || 'dependency_blocked':
              final seconds = result['retry_after_seconds'] ?? r['retry_after_seconds'];
              retries.add((
                op,
                '$status',
                _message(result) ?? 'سيُعاد الإرسال لاحقًا',
                seconds is int ? Duration(seconds: seconds) : null,
              ));
            default: // conflict_requires_review / validation_failed / غير معروف
              await _reject(
                txn,
                op,
                code: '${result['code'] ?? status}',
                message: _message(result) ?? 'رفض السيرفر العملية',
                result: result,
              );
              rejected++;
          }
        }
      });
      for (final (op, code, message, after) in retries) {
        await _scheduleRetry(op, code: code, message: message, retryAfter: after);
      }
      report = report.merge(SyncReport(accepted: accepted, rejected: rejected));
    }
  }

  Future<void> _accept(Transaction txn, OutboxOperation op, Map<String, Object?> result) async {
    await _outbox.markAccepted(txn, op.uuid, result);
    // مراجعات المخزون الجديدة: البيع التالي على هذا الصنف يستخدمها حتى قبل الـ Pull.
    final revisions = result['stock_revisions'];
    if (revisions is Map) {
      for (final entry in revisions.entries) {
        final variantId = int.tryParse('${entry.key}');
        if (variantId != null && entry.value is String) {
          await txn.update(Tables.stocks, {'revision': entry.value}, where: 'variant_id = ?', whereArgs: [variantId]);
        }
      }
    }
    await _handlers[op.type]?.onAccepted(txn, op, result);
  }

  Future<void> _reject(
    Transaction txn,
    OutboxOperation op, {
    required String code,
    required String message,
    Map<String, Object?>? result,
  }) async {
    await _outbox.markReview(txn, op.uuid, code: code, message: message, result: result);
    await _handlers[op.type]?.onRejected(txn, op);
  }

  Future<void> _scheduleRetry(
    OutboxOperation op, {
    required String code,
    required String message,
    Duration? retryAfter,
  }) {
    // max(Retry-After, jitter + min(300, 2^attempts)) كما في العقد.
    final backoff = min(300, pow(2, op.attempts).toInt()) + _random.nextInt(5);
    final wait = max(retryAfter?.inSeconds ?? 0, backoff);
    return _outbox.markRetry(
      op.uuid,
      code: code,
      message: message,
      nextAttemptAt: _clock().add(Duration(seconds: wait)),
    );
  }

  static String? _message(Map<String, Object?> result) {
    final errors = result['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        if (entry.key == 'minimum_quote') continue;
        final value = entry.value;
        if (value is List && value.isNotEmpty && value.first is String) return value.first as String;
      }
    }
    return result['message'] as String?;
  }

  // ---------------------------------------------------------------- pull

  Future<SyncReport> pull() async {
    final session = _session.current;
    if (session == null) return const SyncReport();
    try {
      return await _pullPages(session.branchId);
    } on ServerException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 422) {
        // الجلسة انتهت أو تغيرت الصلاحيات أو الـ cursor تالف: Bootstrap جديد ومسح القراءة (لا الـ Outbox).
        developer.log('Pull reset (${e.statusCode}): ${e.message}', name: 'sync');
        await resetCache();
        try {
          return await _pullPages(session.branchId);
        } on ServerException catch (e2) {
          return SyncReport(error: e2.message);
        }
      }
      return SyncReport(error: e.message);
    } on NetworkException {
      return const SyncReport(offline: true);
    } on UnauthorizedException {
      return const SyncReport(unauthorized: true);
    } on ApiNotConfiguredException {
      return const SyncReport(notConfigured: true);
    }
  }

  Future<SyncReport> _pullPages(int branchId) async {
    final db = await _db.database;
    var total = 0;
    var cursor = await _state(SyncKeys.cursor);
    final bootstrapping = cursor == null;
    while (true) {
      final Map<String, Object?> page;
      if (cursor == null) {
        var syncUuid = await _state(SyncKeys.syncUuid);
        if (syncUuid == null) {
          // يُحفظ قبل الطلب: إن ضاع الرد نعيد نفس الـ UUID.
          syncUuid = _outbox.newUuid();
          await _setState(db, SyncKeys.syncUuid, syncUuid);
        }
        page = await _api.post(
          ApiEndpoints.bootstrap,
          body: {
            'schema_version': ApiConfig.schemaVersion,
            'sync_uuid': syncUuid,
            'branch_id': branchId,
            'limit': pageSize,
          },
        );
      } else {
        page = await _api.post(ApiEndpoints.pull, body: {'cursor': cursor, 'limit': pageSize});
      }
      final next = page['cursor'];
      final hasMore = page['has_more'] == true;
      final changes = page['changes'] is List ? page['changes']! as List : const [];
      await db.transaction((txn) async {
        total += await _applier.apply(txn, changes);
        if (next is String) await _setState(txn, SyncKeys.cursor, next);
        if (!hasMore) {
          if (bootstrapping) await _setState(txn, SyncKeys.initialCompleted, '1');
          await _setState(txn, SyncKeys.lastPullAt, _clock().toUtc().toIso8601String());
        }
      });
      if (!hasMore || next is! String) break;
      cursor = next;
    }
    return SyncReport(pulledChanges: total);
  }

  /// يمسح الـ Cache وحالة المزامنة. الـ Outbox والفواتير المحلية لا تُمس.
  Future<void> resetCache() async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final table in Tables.cacheTables) {
        await txn.delete(table);
      }
      await txn.delete(Tables.syncState);
    });
  }

  Future<bool> get initialSyncCompleted async => await _state(SyncKeys.initialCompleted) == '1';

  /// آخر حالة تشغيل معروفة للفرع (`mode`, `sales_allowed`, `warning`)، أو null قبل أول اتصال.
  Future<Map<String, Object?>?> operationState() async {
    final raw = await _state(SyncKeys.operationState);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, Object?>();
  }

  // ------------------------------------------------------- operation state

  /// وضع الفرع (setup / progressive / full) وهل البيع مسموح.
  Future<SyncReport> _refreshOperationState() async {
    final session = _session.current;
    if (session == null || !session.canSell) return const SyncReport();
    try {
      final response = await _api.get(ApiEndpoints.operationState, query: {'branch_id': session.branchId});
      if (response['data'] is Map) {
        await _setState(await _db.database, SyncKeys.operationState, jsonEncode(response['data']));
      }
      return const SyncReport();
    } on NetworkException {
      return const SyncReport(offline: true);
    } on UnauthorizedException {
      return const SyncReport(unauthorized: true);
    } on Exception catch (e) {
      developer.log('operation-state failed', error: e, name: 'sync');
      return const SyncReport();
    }
  }

  Future<String?> _state(String key) async {
    final db = await _db.database;
    final rows = await db.query(Tables.syncState, where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> _setState(DatabaseExecutor db, String key, String value) =>
      db.insert(Tables.syncState, {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
