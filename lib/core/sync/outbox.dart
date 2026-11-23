import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/schema.dart';

/// عملية في الـ Outbox. الـ UUID والمحتوى والتبعيات ثابتة منذ الإنشاء (شرط العقد):
/// إعادة الإرسال تكون بنفس القيم، والتصحيح يكون بعملية جديدة.
class OutboxOperation extends Equatable {
  const OutboxOperation({
    required this.seq,
    required this.uuid,
    required this.type,
    required this.clientCreatedAt,
    required this.branchId,
    required this.userId,
    required this.payload,
    required this.dependencies,
    required this.summary,
    required this.status,
    required this.attempts,
    this.result,
    this.errorCode,
    this.errorMessage,
    this.nextAttemptAt,
  });

  factory OutboxOperation.fromDb(Map<String, Object?> row) => OutboxOperation(
    seq: row['seq']! as int,
    uuid: row['operation_uuid']! as String,
    type: row['operation_type']! as String,
    clientCreatedAt: row['client_created_at']! as String,
    branchId: row['branch_id']! as int,
    userId: row['user_id']! as int,
    payload: (jsonDecode(row['payload']! as String) as Map).cast<String, Object?>(),
    dependencies: (jsonDecode(row['dependencies']! as String) as List).cast<String>(),
    summary: row['summary']! as String,
    status: row['status']! as String,
    attempts: row['attempts']! as int,
    result: row['result'] == null ? null : (jsonDecode(row['result']! as String) as Map).cast<String, Object?>(),
    errorCode: row['error_code'] as String?,
    errorMessage: row['error_message'] as String?,
    nextAttemptAt: DateTime.tryParse((row['next_attempt_at'] as String?) ?? ''),
  );

  final int seq;
  final String uuid;

  /// مثل `sale.create`.
  final String type;
  final String clientCreatedAt;
  final int branchId;
  final int userId;
  final Map<String, Object?> payload;
  final List<String> dependencies;

  /// وصف قصير بالعربي للعرض (مثل "بيع 3 قطع بـ ₪120.00").
  final String summary;
  final String status;
  final int attempts;
  final Map<String, Object?>? result;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? nextAttemptAt;

  /// الشكل المرسل في `/sync/push`.
  Map<String, Object?> toWire() => {
    'operation_uuid': uuid,
    'operation_type': type,
    'client_created_at': clientCreatedAt,
    'branch_id': branchId,
    'dependencies': dependencies,
    'payload': payload,
  };

  String get typeLabel => switch (type) {
    'sale.create' => 'فاتورة بيع',
    'product.create' => 'منتج جديد',
    'product.update' => 'تعديل منتج',
    'purchase.create' => 'فاتورة شراء',
    'opening_stock.create' => 'بضاعة أول المدة',
    _ => type,
  };

  @override
  List<Object?> get props => [seq, uuid, status, attempts, errorCode, errorMessage, result];
}

class Outbox {
  Outbox(this._appDb, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _appDb;
  final Uuid _uuid;
  final _changes = StreamController<void>.broadcast();

  /// يصدر عند أي تغيير (لتحديث العدادات والشاشات).
  Stream<void> get changes => _changes.stream;

  String newUuid() => _uuid.v4();

  /// يضيف عملية **داخل نفس الـ transaction** التي تحفظ أثرها المحلي.
  Future<void> enqueue(
    DatabaseExecutor txn, {
    required String uuid,
    required String type,
    required int branchId,
    required int userId,
    required Map<String, Object?> payload,
    required String summary,
    List<String> dependencies = const [],
    DateTime? createdAt,
  }) async {
    final now = (createdAt ?? DateTime.now()).toUtc();
    await txn.insert(Tables.outbox, {
      'operation_uuid': uuid,
      'operation_type': type,
      'client_created_at': _wireTime(now),
      'branch_id': branchId,
      'user_id': userId,
      'payload': jsonEncode(payload),
      'dependencies': jsonEncode(dependencies),
      'summary': summary,
      'status': OutboxStatus.pending,
      'updated_at': now.toIso8601String(),
    });
    scheduleMicrotask(notifyChanged);
  }

  /// العمليات الجاهزة للإرسال لهذا المستخدم والفرع، بحد أقصى [limit] (حد السيرفر 20).
  ///
  /// تُستبعد العملية التي تنتظر موعد إعادة محاولة، والتابعة لأصل مرفوض أو لأصل خارج الدفعة.
  Future<List<OutboxOperation>> due({required int userId, required int branchId, DateTime? now, int limit = 20}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.outbox,
      where: 'status = ? AND user_id = ? AND branch_id = ?',
      whereArgs: [OutboxStatus.pending, userId, branchId],
      orderBy: 'seq',
    );
    final pending = rows.map(OutboxOperation.fromDb).toList();
    if (pending.isEmpty) return const [];
    final deps = {for (final op in pending) ...op.dependencies};
    final depStatus = <String, String>{};
    if (deps.isNotEmpty) {
      final found = await db.query(
        Tables.outbox,
        columns: ['operation_uuid', 'status'],
        where: 'operation_uuid IN (${List.filled(deps.length, '?').join(',')})',
        whereArgs: deps.toList(),
      );
      for (final r in found) {
        depStatus[r['operation_uuid']! as String] = r['status']! as String;
      }
    }
    final at = now ?? DateTime.now();
    final batch = <OutboxOperation>[];
    final inBatch = <String>{};
    for (final op in pending) {
      if (batch.length >= limit) break;
      if (op.nextAttemptAt != null && op.nextAttemptAt!.isAfter(at)) continue;
      final ready = op.dependencies.every((d) => depStatus[d] == OutboxStatus.accepted || inBatch.contains(d));
      if (!ready) continue;
      batch.add(op);
      inBatch.add(op.uuid);
    }
    return batch;
  }

  Future<OutboxOperation?> find(String uuid, {DatabaseExecutor? txn}) async {
    final db = txn ?? await _appDb.database;
    final rows = await db.query(Tables.outbox, where: 'operation_uuid = ?', whereArgs: [uuid], limit: 1);
    return rows.isEmpty ? null : OutboxOperation.fromDb(rows.first);
  }

  Future<void> markAccepted(DatabaseExecutor txn, String uuid, Map<String, Object?> result) => _set(txn, uuid, {
    'status': OutboxStatus.accepted,
    'result': jsonEncode(result),
    'error_code': null,
    'error_message': null,
  });

  Future<void> markReview(
    DatabaseExecutor txn,
    String uuid, {
    required String code,
    required String message,
    Object? result,
  }) => _set(txn, uuid, {
    'status': OutboxStatus.review,
    'error_code': code,
    'error_message': message,
    'result': result == null ? null : jsonEncode(result),
  });

  /// فشل مؤقت: تبقى pending حتى [nextAttemptAt].
  Future<void> markRetry(
    String uuid, {
    required String code,
    required String message,
    required DateTime nextAttemptAt,
  }) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      'UPDATE ${Tables.outbox} SET attempts = attempts + 1, error_code = ?, error_message = ?, next_attempt_at = ?, updated_at = ? '
      'WHERE operation_uuid = ? AND status = ?',
      [
        code,
        message,
        nextAttemptAt.toIso8601String(),
        DateTime.now().toUtc().toIso8601String(),
        uuid,
        OutboxStatus.pending,
      ],
    );
    notifyChanged();
  }

  /// المستخدم قرر ترك عملية مرفوضة. لا تُحذف (سجل)، لكنها تخرج من القوائم.
  Future<void> dismiss(DatabaseExecutor txn, String uuid) => _set(txn, uuid, {'status': OutboxStatus.dismissed});

  /// يعيد موعد المحاولة للآن لكل العمليات المنتظرة (زر "مزامنة الآن").
  Future<void> wakeUp() async {
    final db = await _appDb.database;
    await db.update(Tables.outbox, {'next_attempt_at': null}, where: 'status = ?', whereArgs: [OutboxStatus.pending]);
  }

  Future<List<OutboxOperation>> list({required List<String> statuses, int? userId, int limit = 200}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.outbox,
      where: 'status IN (${List.filled(statuses.length, '?').join(',')})${userId == null ? '' : ' AND user_id = ?'}',
      whereArgs: [...statuses, ?userId],
      orderBy: 'seq DESC',
      limit: limit,
    );
    return rows.map(OutboxOperation.fromDb).toList();
  }

  Future<({int pending, int review})> counts({required int userId}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS c FROM ${Tables.outbox} WHERE user_id = ? GROUP BY status',
      [userId],
    );
    var pending = 0;
    var review = 0;
    for (final row in rows) {
      if (row['status'] == OutboxStatus.pending) pending = row['c']! as int;
      if (row['status'] == OutboxStatus.review) review = row['c']! as int;
    }
    return (pending: pending, review: review);
  }

  Future<void> _set(DatabaseExecutor txn, String uuid, Map<String, Object?> values) async {
    await txn.update(
      Tables.outbox,
      {...values, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'operation_uuid = ?',
      whereArgs: [uuid],
    );
    scheduleMicrotask(notifyChanged);
  }

  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  /// صيغة التاريخ التي يقبلها السيرفر: `2026-10-31T11:00:00.000000Z`.
  static String _wireTime(DateTime utc) {
    final iso = utc.toIso8601String(); // 2026-10-31T11:00:00.123Z
    final base = iso.substring(0, 19);
    final micros = (utc.millisecond * 1000 + utc.microsecond).toString().padLeft(6, '0');
    return '$base.${micros}Z';
  }
}
