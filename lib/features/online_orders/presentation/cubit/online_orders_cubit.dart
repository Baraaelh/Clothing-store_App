import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/online_order.dart';
import '../../domain/usecases/change_online_order_status.dart';
import '../../domain/usecases/get_online_orders.dart';

enum OrdersStatus { initial, loading, loaded, failure }

class OnlineOrdersState extends Equatable {
  const OnlineOrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.filter = OnlineOrderStatus.pending,
    this.busyOrderIds = const {},
    this.message,
  });

  final OrdersStatus status;
  final List<OnlineOrder> orders;

  /// `null` = الكل.
  final OnlineOrderStatus? filter;
  final Set<String> busyOrderIds;
  final String? message;

  OnlineOrdersState copyWith({
    OrdersStatus? status,
    List<OnlineOrder>? orders,
    OnlineOrderStatus? Function()? filter,
    Set<String>? busyOrderIds,
    String? message,
  }) => OnlineOrdersState(
    status: status ?? this.status,
    orders: orders ?? this.orders,
    filter: filter != null ? filter() : this.filter,
    busyOrderIds: busyOrderIds ?? this.busyOrderIds,
    message: message,
  );

  @override
  List<Object?> get props => [status, orders, filter, busyOrderIds, message];
}

class OnlineOrdersCubit extends Cubit<OnlineOrdersState> {
  OnlineOrdersCubit(this._getOrders, this._changeStatus) : super(const OnlineOrdersState());

  final GetOnlineOrders _getOrders;
  final ChangeOnlineOrderStatus _changeStatus;

  Future<void> load() async {
    if (state.orders.isEmpty) emit(state.copyWith(status: OrdersStatus.loading));
    final filter = state.filter;
    final result = await _getOrders(filter);
    if (isClosed || filter != state.filter) return;
    result.fold(
      (f) => emit(state.copyWith(status: OrdersStatus.failure, message: f.message)),
      (orders) => emit(state.copyWith(status: OrdersStatus.loaded, orders: orders)),
    );
  }

  Future<void> setFilter(OnlineOrderStatus? filter) async {
    emit(state.copyWith(filter: () => filter, orders: const []));
    await load();
  }

  Future<void> accept(OnlineOrder order) => _change(order, OnlineOrderStatus.accepted);

  Future<void> reject(OnlineOrder order) => _change(order, OnlineOrderStatus.rejected);

  Future<void> _change(OnlineOrder order, OnlineOrderStatus status) async {
    if (state.busyOrderIds.contains(order.id)) return;
    emit(state.copyWith(busyOrderIds: {...state.busyOrderIds, order.id}));
    final result = await _changeStatus(ChangeOrderStatusParams(order, status));
    if (isClosed) return;
    final busy = {...state.busyOrderIds}..remove(order.id);
    result.fold(
      (f) => emit(state.copyWith(busyOrderIds: busy, message: f.message)),
      (_) => emit(
        state.copyWith(
          busyOrderIds: busy,
          message: 'تم ${status == OnlineOrderStatus.accepted ? 'قبول' : 'رفض'} الطلب',
        ),
      ),
    );
    await load();
  }
}
