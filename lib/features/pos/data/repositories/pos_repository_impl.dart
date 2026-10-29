import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/pos_repository.dart';
import '../datasources/pos_local_data_source.dart';
import '../models/sale_model.dart';

/// Offline-first: كل القراءة والكتابة من SQLite. الإرسال للسيرفر عبر طابور المزامنة.
class PosRepositoryImpl implements PosRepository {
  PosRepositoryImpl(this._local, this._session, {Uuid uuid = const Uuid(), DateTime Function()? clock})
    : _uuid = uuid,
      _clock = clock ?? DateTime.now;

  final PosLocalDataSource _local;
  final SessionManager _session;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<Result<List<CatalogItem>>> getCatalog({String query = ''}) async {
    try {
      return Ok(await _local.getCatalog(query: query));
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<Sale>> createSale(CheckoutRequest request) async {
    final session = _session.current;
    if (session == null) return const Err(UnauthorizedFailure());
    final sale = Sale(
      id: _uuid.v4(),
      branchId: session.branchId,
      cashierName: session.userName,
      customerName: (request.customerName?.trim().isEmpty ?? true) ? null : request.customerName!.trim(),
      paymentMethod: request.paymentMethod,
      subtotal: request.subtotal,
      discount: request.discount,
      total: request.total,
      amountPaid: request.paymentMethod == PaymentMethod.cash ? request.amountPaid : request.total,
      createdAt: _clock(),
      syncState: SaleSyncState.pending,
      items: [
        for (final line in request.lines)
          SaleItem(
            variantId: line.item.variantId,
            productName: line.item.productName,
            colorName: line.item.colorName,
            sizeName: line.item.sizeName,
            sku: line.item.sku,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
          ),
      ],
    );
    try {
      await _local.insertSale(sale, SaleModel.toApiPayload(sale));
      return Ok(sale);
    } on CacheException catch (e) {
      return Err(ValidationFailure(e.message));
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Sale>>> getRecentSales({int limit = 20}) async {
    try {
      return Ok(await _local.getRecentSales(limit: limit));
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }
}
