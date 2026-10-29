import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/online_order.dart';
import '../../domain/repositories/online_orders_repository.dart';
import '../datasources/online_orders_local_data_source.dart';

class OnlineOrdersRepositoryImpl implements OnlineOrdersRepository {
  OnlineOrdersRepositoryImpl(this._local);

  final OnlineOrdersLocalDataSource _local;

  @override
  Future<Result<List<OnlineOrder>>> getOrders({OnlineOrderStatus? status}) async {
    try {
      return Ok(await _local.getOrders(status: status));
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<OnlineOrder>> updateStatus(String orderId, OnlineOrderStatus status) async {
    try {
      return Ok(await _local.updateStatus(orderId, status));
    } on CacheException catch (e) {
      return Err(ValidationFailure(e.message));
    } on Exception catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }
}
