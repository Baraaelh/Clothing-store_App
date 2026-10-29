import '../../../../core/session/session_manager.dart';
import '../../../../core/sync/sync_handler.dart';
import '../../../../core/sync/sync_operation.dart';
import '../datasources/pos_local_data_source.dart';
import '../datasources/pos_remote_data_source.dart';
import '../models/catalog_item_model.dart';

/// يرسل الفواتير المحفوظة محليًا للسيرفر.
class CreateSaleSyncHandler implements SyncHandler {
  CreateSaleSyncHandler(this._local, this._remote);

  final PosLocalDataSource _local;
  final PosRemoteDataSource _remote;

  @override
  String get operation => createSaleOperation;

  @override
  Future<void> push(SyncOperation op) async {
    final serverId = await _remote.createSale(op.payload);
    await _local.markSaleSynced(op.entityId, serverId);
  }

  @override
  Future<void> onPermanentFailure(SyncOperation op, String error) => _local.markSaleFailed(op.entityId);
}

/// يسحب منتجات الفرع وكمياتها من السيرفر.
class CatalogPullHandler implements PullHandler {
  CatalogPullHandler(this._local, this._remote, this._session);

  final PosLocalDataSource _local;
  final PosRemoteDataSource _remote;
  final SessionManager _session;

  @override
  String get name => 'catalog';

  @override
  Future<void> pull() async {
    final json = await _remote.fetchCatalog(_session.requireSession.branchId);
    final now = DateTime.now().toUtc().toIso8601String();
    await _local.replaceCatalog([for (final item in json) CatalogItemModel.dbRowFromJson(item, now)]);
  }
}
