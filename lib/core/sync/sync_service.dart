import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';

import '../error/exceptions.dart';
import 'sync_handler.dart';
import 'sync_queue.dart';

/// نتيجة دورة مزامنة واحدة.
class SyncReport extends Equatable {
  const SyncReport({
    this.pushed = 0,
    this.failed = 0,
    this.pulled = const [],
    this.offline = false,
    this.notConfigured = false,
    this.unauthorized = false,
  });

  final int pushed;
  final int failed;
  final List<String> pulled;

  /// توقفت الدورة لأن الاتصال انقطع.
  final bool offline;

  /// الـ API غير مضبوط بعد، فلم يُرسل شيء.
  final bool notConfigured;

  /// السيرفر رد بـ 401: الجلسة انتهت. العمليات تبقى في الطابور كما هي.
  final bool unauthorized;

  @override
  List<Object?> get props => [pushed, failed, pulled, offline, notConfigured, unauthorized];
}

/// محرك المزامنة: يرسل الطابور أولًا (push) ثم يسحب التحديثات (pull).
///
/// الإرسال أولًا مهم: حتى تصل مبيعات الجهاز للسيرفر قبل سحب الكميات الجديدة.
class SyncService {
  SyncService({
    required SyncQueue queue,
    required List<SyncHandler> handlers,
    required List<PullHandler> pullers,
    this.maxAttempts = 10,
  }) : _queue = queue,
       _handlers = {for (final h in handlers) h.operation: h},
       _pullers = pullers;

  final SyncQueue _queue;
  final Map<String, SyncHandler> _handlers;
  final List<PullHandler> _pullers;
  final int maxAttempts;

  bool _running = false;

  bool get isRunning => _running;

  /// تشغيل دورة مزامنة. إذا كانت هناك دورة جارية، ترجع `null` بدون تشغيل أخرى.
  Future<SyncReport?> run() async {
    if (_running) return null;
    _running = true;
    try {
      final push = await _pushAll();
      if (push.offline || push.notConfigured || push.unauthorized) return push;
      final pulled = await _pullAll();
      return SyncReport(
        pushed: push.pushed,
        failed: push.failed,
        pulled: pulled.names,
        offline: pulled.offline,
        notConfigured: pulled.notConfigured,
        unauthorized: pulled.unauthorized,
      );
    } finally {
      _running = false;
    }
  }

  Future<SyncReport> _pushAll() async {
    var pushed = 0;
    var failed = 0;
    final skipped = <int>{};

    while (true) {
      final batch = (await _queue.pending()).where((op) => !skipped.contains(op.id)).toList();
      if (batch.isEmpty) break;

      for (final op in batch) {
        final handler = _handlers[op.operation];
        if (handler == null) {
          await _queue.markFailed(op.id, 'No handler for ${op.operation}');
          failed++;
          continue;
        }
        try {
          await handler.push(op);
          await _queue.remove(op.id);
          pushed++;
        } on NetworkException {
          return SyncReport(pushed: pushed, failed: failed, offline: true);
        } on UnauthorizedException {
          return SyncReport(pushed: pushed, failed: failed, unauthorized: true);
        } on ApiNotConfiguredException {
          return SyncReport(pushed: pushed, failed: failed, notConfigured: true);
        } on ServerException catch (e) {
          if (e.isPermanent || op.attempts + 1 >= maxAttempts) {
            await _queue.markFailed(op.id, e.toString());
            await handler.onPermanentFailure(op, e.message);
            failed++;
          } else {
            // خطأ مؤقت (5xx...): نتركها للدورة القادمة ونكمل بالباقي.
            await _queue.recordAttempt(op.id, e.toString());
            skipped.add(op.id);
          }
        } catch (e, st) {
          developer.log('Sync push failed', error: e, stackTrace: st, name: 'sync');
          if (op.attempts + 1 >= maxAttempts) {
            await _queue.markFailed(op.id, e.toString());
            await handler.onPermanentFailure(op, e.toString());
            failed++;
          } else {
            await _queue.recordAttempt(op.id, e.toString());
            skipped.add(op.id);
          }
        }
      }
    }
    return SyncReport(pushed: pushed, failed: failed);
  }

  Future<({List<String> names, bool offline, bool notConfigured, bool unauthorized})> _pullAll() async {
    final names = <String>[];
    var notConfigured = false;
    for (final puller in _pullers) {
      try {
        await puller.pull();
        names.add(puller.name);
      } on NetworkException {
        return (names: names, offline: true, notConfigured: false, unauthorized: false);
      } on UnauthorizedException {
        return (names: names, offline: false, notConfigured: false, unauthorized: true);
      } on ApiNotConfiguredException {
        notConfigured = true;
      } catch (e, st) {
        developer.log('Sync pull "${puller.name}" failed', error: e, stackTrace: st, name: 'sync');
      }
    }
    return (names: names, offline: false, notConfigured: notConfigured, unauthorized: false);
  }
}
