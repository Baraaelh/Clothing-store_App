import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/online_order.dart';
import '../repositories/online_orders_repository.dart';

class GetOnlineOrders implements UseCase<List<OnlineOrder>, OnlineOrderStatus?> {
  const GetOnlineOrders(this._repository);

  final OnlineOrdersRepository _repository;

  @override
  Future<Result<List<OnlineOrder>>> call(OnlineOrderStatus? status) => _repository.getOrders(status: status);
}
