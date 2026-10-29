import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/catalog_item.dart';
import '../../domain/usecases/get_catalog.dart';

enum CatalogStatus { initial, loading, loaded, failure }

class CatalogState extends Equatable {
  const CatalogState({this.status = CatalogStatus.initial, this.items = const [], this.query = '', this.error});

  final CatalogStatus status;
  final List<CatalogItem> items;
  final String query;
  final String? error;

  CatalogState copyWith({CatalogStatus? status, List<CatalogItem>? items, String? query, String? error}) =>
      CatalogState(status: status ?? this.status, items: items ?? this.items, query: query ?? this.query, error: error);

  @override
  List<Object?> get props => [status, items, query, error];
}

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._getCatalog) : super(const CatalogState());

  final GetCatalog _getCatalog;

  Future<void> load() => search(state.query);

  Future<void> search(String query) async {
    emit(state.copyWith(status: state.items.isEmpty ? CatalogStatus.loading : state.status, query: query));
    final result = await _getCatalog(query);
    if (isClosed || query != state.query) return; // تجاهل نتيجة بحث قديم
    result.fold(
      (failure) => emit(state.copyWith(status: CatalogStatus.failure, error: failure.message)),
      (items) => emit(state.copyWith(status: CatalogStatus.loaded, items: items)),
    );
  }
}
