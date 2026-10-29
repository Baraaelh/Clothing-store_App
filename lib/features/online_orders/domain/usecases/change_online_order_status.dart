import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/online_order.dart';
import '../repositories/online_orders_repository.dart';

class ChangeOrderStatusParams extends Equatable {
  const ChangeOrderStatusParams(this.order, this.newStatus);

  final OnlineOrder order;
  final OnlineOrderStatus newStatus;

  @override
  List<Object?> get props => [order, newStatus];
}

/// قبول أو رفض طلب. فقط الطلبات المعلقة يمكن تغيير حالتها.
class ChangeOnlineOrderStatus implements UseCase<OnlineOrder, ChangeOrderStatusParams> {
  const ChangeOnlineOrderStatus(this._repository);

  final OnlineOrdersRepository _repository;

  @override
  Future<Result<OnlineOrder>> call(ChangeOrderStatusParams params) {
    if (!params.order.canChangeStatus) {
      return Future.value(const Err(ValidationFailure('تمت معالجة هذا الطلب مسبقًا')));
    }
    if (params.newStatus == OnlineOrderStatus.pending) {
      return Future.value(const Err(ValidationFailure('حالة غير صالحة')));
    }
    return _repository.updateStatus(params.order.id, params.newStatus);
  }
}
