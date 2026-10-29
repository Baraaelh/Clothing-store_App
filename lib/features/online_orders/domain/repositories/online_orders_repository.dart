import '../../../../core/utils/result.dart';
import '../entities/online_order.dart';

abstract interface class OnlineOrdersRepository {
  /// الطلبات من النسخة المحلية. `status = null` = كل الطلبات.
  Future<Result<List<OnlineOrder>>> getOrders({OnlineOrderStatus? status});

  /// يغير الحالة محليًا فورًا ويضيف التغيير لطابور المزامنة.
  Future<Result<OnlineOrder>> updateStatus(String orderId, OnlineOrderStatus status);
}
