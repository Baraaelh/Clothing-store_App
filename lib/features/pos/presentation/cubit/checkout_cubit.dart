import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/reference_data.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/pos_repository.dart';
import '../../domain/usecases/create_sale.dart';

class CheckoutState extends Equatable {
  const CheckoutState({this.accounts = const [], this.submitting = false, this.sale, this.error});

  final List<PaymentAccount> accounts;
  final bool submitting;

  /// الفاتورة المحفوظة (نجاح).
  final Sale? sale;

  /// رسالة خطأ لمرة واحدة.
  final String? error;

  CheckoutState copyWith({List<PaymentAccount>? accounts, bool? submitting, Sale? sale, String? error}) =>
      CheckoutState(
        accounts: accounts ?? this.accounts,
        submitting: submitting ?? this.submitting,
        sale: sale,
        error: error,
      );

  @override
  List<Object?> get props => [accounts, submitting, sale, error];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._createSale, this._repository) : super(const CheckoutState());

  final CreateSale _createSale;
  final PosRepository _repository;

  Future<void> load() async {
    final result = await _repository.getAccounts();
    if (isClosed) return;
    result.fold((f) => emit(state.copyWith(error: f.message)), (accounts) => emit(state.copyWith(accounts: accounts)));
  }

  Future<List<Party>> searchCustomers(String query) async =>
      (await _repository.searchCustomers(query)).fold((_) => const [], (list) => list);

  Future<void> submit(CheckoutRequest request) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    final result = await _createSale(request);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(submitting: false, error: f.message)),
      (sale) => emit(state.copyWith(submitting: false, sale: sale)),
    );
  }
}
