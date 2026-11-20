import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/reference_data.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/sync/outbox.dart';
import '../data/catalog_local_data_source.dart';
import '../domain/product.dart';

class ProductsState extends Equatable {
  const ProductsState({this.products = const [], this.pending = const [], this.query = '', this.loading = true});

  final List<ProductSummary> products;

  /// عمليات منتجات لم يقبلها السيرفر بعد.
  final List<OutboxOperation> pending;
  final String query;
  final bool loading;

  @override
  List<Object?> get props => [products, pending, query, loading];
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit(this._catalog, this._session) : super(const ProductsState());

  final CatalogLocalDataSource _catalog;
  final SessionManager _session;

  Future<void> load() => search(state.query);

  Future<void> search(String query) async {
    final q = query.trim();
    final products = await _catalog.products(query: q);
    final userId = _session.current?.userId;
    final pending = userId == null ? const <OutboxOperation>[] : await _catalog.pendingProductOps(userId);
    if (isClosed || q != query.trim()) return;
    emit(ProductsState(products: products, pending: pending, query: q, loading: false));
  }
}

/// تفاصيل منتج واحد.
class ProductDetailCubit extends Cubit<ProductDetail?> {
  ProductDetailCubit(this._catalog, this.productId) : super(null);

  final CatalogLocalDataSource _catalog;
  final int productId;

  Future<void> load() async {
    final detail = await _catalog.product(productId);
    if (!isClosed) emit(detail);
  }
}

class ProductFormState extends Equatable {
  const ProductFormState({
    this.categories = const [],
    this.colors = const [],
    this.sizes = const [],
    this.saving = false,
    this.saved = false,
    this.error,
  });

  final List<NamedRef> categories;
  final List<NamedRef> colors;
  final List<NamedRef> sizes;
  final bool saving;
  final bool saved;
  final String? error;

  ProductFormState copyWith({
    List<NamedRef>? categories,
    List<NamedRef>? colors,
    List<NamedRef>? sizes,
    bool? saving,
    bool? saved,
    String? error,
  }) => ProductFormState(
    categories: categories ?? this.categories,
    colors: colors ?? this.colors,
    sizes: sizes ?? this.sizes,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    error: error,
  );

  @override
  List<Object?> get props => [categories, colors, sizes, saving, saved, error];
}

/// إضافة منتج أو تعديله. الحفظ محلي في الـ Outbox، والسيرفر يعتمده عند المزامنة.
class ProductFormCubit extends Cubit<ProductFormState> {
  ProductFormCubit(this._catalog, this._reference, this._session) : super(const ProductFormState());

  final CatalogLocalDataSource _catalog;
  final ReferenceData _reference;
  final SessionManager _session;

  bool get canSetMinimum => _session.current?.canManageMinimumPrice ?? false;

  Future<void> load() async {
    final categories = await _reference.categories();
    final colors = await _reference.colors();
    final sizes = await _reference.sizes();
    if (!isClosed) emit(state.copyWith(categories: categories, colors: colors, sizes: sizes));
  }

  Future<void> save(ProductDraft draft, {ProductDetail? current}) async {
    final error = validate(draft);
    if (error != null) return emit(state.copyWith(error: error));
    final session = _session.current;
    if (session == null) return;
    emit(state.copyWith(saving: true));
    try {
      if (current == null) {
        await _catalog.createProduct(session, draft, includeMinimum: canSetMinimum);
      } else {
        await _catalog.updateProduct(session, current, draft, includeMinimum: canSetMinimum);
      }
      if (!isClosed) emit(state.copyWith(saving: false, saved: true));
    } on CacheException catch (e) {
      if (!isClosed) emit(state.copyWith(saving: false, error: e.message));
    }
  }

  static String? validate(ProductDraft draft) {
    if (draft.name.trim().isEmpty) return 'أدخل اسم المنتج';
    if (draft.categoryId == null) return 'اختر التصنيف';
    if (draft.variants.isEmpty) return 'أضف صنفًا واحدًا على الأقل (لون ومقاس وسعر)';
    final combos = <String>{};
    for (final v in draft.variants) {
      if (!combos.add('${v.colorId}-${v.sizeId}')) return 'تركيبة اللون والمقاس مكررة';
      if (v.price <= 0) return 'أدخل سعر بيع لكل صنف';
      if (v.minPrice != null && v.minPrice! > v.price) return 'الحد الأدنى أكبر من سعر البيع';
    }
    return null;
  }
}
