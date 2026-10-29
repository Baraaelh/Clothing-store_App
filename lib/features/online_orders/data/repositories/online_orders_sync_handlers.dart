import '../../../../core/sync/sync_handler.dart';
import '../../../../core/sync/sync_operation.dart';
import '../datasources/online_orders_local_data_source.dart';
import '../datasources/online_orders_remote_data_source.dart';
import '../models/online_order_model.dart';

class UpdateOrderStatusSyncHandler implements SyncHandler {
  UpdateOrderStatusSyncHandler(this._local, this._remote);

  final OnlineOrdersLocalDataSource _local;
  final OnlineOrdersRemoteDataSource _remote;

  @override
  String get operation => updateOrderStatusOperation;

  @override
  Future<void> push(SyncOperation op) async {
    await _remote.updateStatus(op.entityId, op.payload['status']! as String);
    await _local.markSynced(op.entityId);
  }

  @override
  Future<void> onPermanentFailure(SyncOperation op, String error) => _local.revertStatus(op.entityId);
}

class OnlineOrdersPullHandler implements PullHandler {
  OnlineOrdersPullHandler(this._local, this._remote);

  final OnlineOrdersLocalDataSource _local;
  final OnlineOrdersRemoteDataSource _remote;

  @override
  String get name => 'online_orders';

  @override
  Future<void> pull() async {
    final json = await _remote.fetchOrders();
    await _local.upsertFromServer(json.map(OnlineOrderModel.dbRowFromJson).toList());
  }
}
