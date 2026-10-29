import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/sale.dart';
import '../../domain/usecases/create_sale.dart';

sealed class CheckoutState extends Equatable {
  const CheckoutState();

  @override
  List<Object?> get props => [];
}

class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

class CheckoutSubmitting extends CheckoutState {
  const CheckoutSubmitting();
}

class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess(this.sale);

  final Sale sale;

  @override
  List<Object?> get props => [sale];
}

class CheckoutFailure extends CheckoutState {
  const CheckoutFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._createSale) : super(const CheckoutIdle());

  final CreateSale _createSale;

  Future<void> submit(CheckoutRequest request) async {
    if (state is CheckoutSubmitting) return;
    emit(const CheckoutSubmitting());
    final result = await _createSale(request);
    if (isClosed) return;
    emit(result.fold((f) => CheckoutFailure(f.message), CheckoutSuccess.new));
  }

  void reset() => emit(const CheckoutIdle());
}
