import 'package:uuid/uuid.dart';

import '../../../../core/data/reference_data.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/pos_repository.dart';
import '../datasources/pos_local_data_source.dart';

/// Offline-first: كل القراءة والكتابة من SQLite. الإرسال للسيرفر عبر الـ Outbox.
class PosRepositoryImpl implements PosRepository {
  PosRepositoryImpl(this._local, this._reference, this._session, {Uuid uuid = const Uuid(), DateTime Function()? clock})
    : _uuid = uuid,
      _clock = clock ?? DateTime.now;

  final PosLocalDataSource _local;
  final ReferenceData _reference;
  final SessionManager _session;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<Result<List<CatalogItem>>> getCatalog({String query = ''}) => _guard(() => _local.getCatalog(query: query));

  @override
  Future<Result<List<PaymentAccount>>> getAccounts() => _guard(_reference.accounts);

  @override
  Future<Result<List<Party>>> searchCustomers(String query) => _guard(() => _reference.customers(query: query));

  @override
  Future<Result<Sale>> createSale(CheckoutRequest request) async {
    final session = _session.current;
    if (session == null) return const Err(UnauthorizedFailure());
    try {
      return Ok(
        await _local.insertSale(
          saleId: _uuid.v4(),
          operationUuid: _uuid.v4(),
          session: session,
          request: request,
          createdAt: _clock(),
        ),
      );
    } on CacheException catch (e) {
      return Err(ValidationFailure(e.message));
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Sale>>> getRecentSales({int limit = 50}) async {
    final session = _session.current;
    if (session == null) return const Err(UnauthorizedFailure());
    return _guard(() => _local.getRecentSales(userId: session.userId, branchId: session.branchId, limit: limit));
  }

  static Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }
}
