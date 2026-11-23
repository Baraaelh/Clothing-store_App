import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/schema.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/sync/outbox.dart';
import '../../pos/data/datasources/pos_local_data_source.dart';

/// صنف تحت الحد الأدنى كما يعيده السيرفر في `errors.minimum_quote`.
class MinimumQuote extends Equatable {
  const MinimumQuote({required this.token, required this.items});

  /// يستخرج العرض من نتيجة عملية مرفوضة، أو null إن لم تكن بسبب الحد الأدنى.
  static MinimumQuote? fromResult(Map<String, Object?>? result) {
    final errors = result?['errors'];
    if (errors is! Map) return null;
    var raw = errors['minimum_quote'];
    if (raw is List && raw.isNotEmpty) raw = raw.first;
    if (raw is! String) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      final token = json['token'];
      if (token is! String) return null;
      return MinimumQuote(
        token: token,
        items: [for (final i in (json['items'] as List?) ?? const []) (i as Map).cast<String, Object?>()],
      );
    } on FormatException {
      return null;
    }
  }

  final String token;
  final List<Map<String, Object?>> items;

  @override
  List<Object?> get props => [token, items];
}

class OperationsState extends Equatable {
  const OperationsState({this.review = const [], this.pending = const [], this.loading = true, this.message});

  final List<OutboxOperation> review;
  final List<OutboxOperation> pending;
  final bool loading;
  final String? message;

  @override
  List<Object?> get props => [review, pending, loading, message];
}

/// شاشة العمليات: المنتظرة للإرسال، والمرفوضة التي تحتاج قرارًا من المستخدم.
class OperationsCubit extends Cubit<OperationsState> {
  OperationsCubit(this._outbox, this._pos, this._session, this._db) : super(const OperationsState());

  final Outbox _outbox;
  final PosLocalDataSource _pos;
  final SessionManager _session;
  final AppDatabase _db;

  Future<void> load() async {
    final userId = _session.current?.userId;
    if (userId == null) return;
    final review = await _outbox.list(statuses: [OutboxStatus.review], userId: userId);
    final pending = await _outbox.list(statuses: [OutboxStatus.pending], userId: userId);
    if (!isClosed) emit(OperationsState(review: review, pending: pending, loading: false));
  }

  /// تأكيد البيع تحت الحد الأدنى: عملية جديدة بنفس السلة مع رمز التأكيد من السيرفر.
  Future<void> confirmBelowMinimum(OutboxOperation op, MinimumQuote quote) async {
    await _pos.resubmitSale(
      rejected: op,
      newOperationUuid: _outbox.newUuid(),
      extraPayload: {'below_minimum_confirmed': true, 'below_minimum_confirmation': quote.token},
    );
    await load();
    if (!isClosed) emit(_withMessage('أُعيد إرسال الفاتورة مع التأكيد'));
  }

  /// إعادة إرسال فاتورة رُفضت بسبب تغيّر المخزون، بمراجعات المخزون الحالية.
  Future<void> resubmitSale(OutboxOperation op) async {
    await _pos.resubmitSale(rejected: op, newOperationUuid: _outbox.newUuid(), extraPayload: const {});
    await load();
    if (!isClosed) emit(_withMessage('أُعيد إرسال الفاتورة'));
  }

  Future<void> dismiss(OutboxOperation op) async {
    if (op.type == saleOperation) {
      await _pos.dismissSale(op);
    } else {
      final db = await _db.database;
      await db.transaction((txn) => _outbox.dismiss(txn, op.uuid));
    }
    await load();
  }

  OperationsState _withMessage(String message) =>
      OperationsState(review: state.review, pending: state.pending, loading: false, message: message);
}
