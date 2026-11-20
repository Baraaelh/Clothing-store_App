import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/reference_data.dart';
import '../../../core/session/session_manager.dart';
import '../../products/data/catalog_local_data_source.dart';
import '../../products/domain/product.dart';
import '../data/stock_entry_data_source.dart';
import '../domain/stock_entry.dart';

enum StockFilter {
  all('الكل'),
  low('قليل (3 أو أقل)'),
  out('نفد');

  const StockFilter(this.label);

  final String label;
}

/// صف في قائمة المخزون: الصنف مع اسم منتجه.
class StockLine extends Equatable {
  const StockLine({required this.productName, required this.variant});

  final String productName;
  final VariantInfo variant;

  @override
  List<Object?> get props => [productName, variant];
}

class InventoryState extends Equatable {
  const InventoryState({
    this.lines = const [],
    this.filter = StockFilter.all,
    this.query = '',
    this.loading = true,
    this.totalUnits = 0,
    this.totalValue,
  });

  final List<StockLine> lines;
  final StockFilter filter;
  final String query;
  final bool loading;
  final int totalUnits;

  /// قيمة المخزون بالتكلفة (فقط لمن يملك صلاحية التكلفة).
  final int? totalValue;

  @override
  List<Object?> get props => [lines, filter, query, loading, totalUnits, totalValue];
}

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit(this._catalog, this._session) : super(const InventoryState());

  final CatalogLocalDataSource _catalog;
  final SessionManager _session;

  Future<void> load() => _run(state.query, state.filter);

  Future<void> search(String query) => _run(query.trim(), state.filter);

  Future<void> setFilter(StockFilter filter) => _run(state.query, filter);

  Future<void> _run(String query, StockFilter filter) async {
    final products = {for (final p in await _catalog.products()) p.id: p.name};
    final variants = await _catalog.variantsWithProduct(query: query);
    final all = [
      for (final (productId, v) in variants)
        if (v.quantity != null) StockLine(productName: products[productId] ?? '', variant: v),
    ];
    final filtered = switch (filter) {
      StockFilter.all => all,
      StockFilter.low => all.where((l) => (l.variant.available ?? 0) > 0 && (l.variant.available ?? 0) <= 3).toList(),
      StockFilter.out => all.where((l) => (l.variant.available ?? 0) <= 0).toList(),
    };
    final canCost = _session.current?.canSeeCost ?? false;
    final units = all.fold(0, (s, l) => s + (l.variant.quantity ?? 0));
    final value = canCost ? all.fold(0, (s, l) => s + (l.variant.quantity ?? 0) * (l.variant.averageCost ?? 0)) : null;
    if (isClosed) return;
    emit(
      InventoryState(
        lines: filtered,
        filter: filter,
        query: query,
        loading: false,
        totalUnits: units,
        totalValue: value,
      ),
    );
  }
}

class StockEntryState extends Equatable {
  const StockEntryState({
    this.variants = const [],
    this.accounts = const [],
    this.openingAllowed = false,
    this.saving = false,
    this.saved = false,
    this.error,
  });

  final List<StockLine> variants;
  final List<PaymentAccount> accounts;

  /// بضاعة أول المدة متاحة فقط قبل إغلاق فترة الإعداد في الفرع.
  final bool openingAllowed;
  final bool saving;
  final bool saved;
  final String? error;

  StockEntryState copyWith({
    List<StockLine>? variants,
    List<PaymentAccount>? accounts,
    bool? openingAllowed,
    bool? saving,
    bool? saved,
    String? error,
  }) => StockEntryState(
    variants: variants ?? this.variants,
    accounts: accounts ?? this.accounts,
    openingAllowed: openingAllowed ?? this.openingAllowed,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    error: error,
  );

  @override
  List<Object?> get props => [variants, accounts, openingAllowed, saving, saved, error];
}

class StockEntryCubit extends Cubit<StockEntryState> {
  StockEntryCubit(this._catalog, this._reference, this._entries, this._session) : super(const StockEntryState());

  final CatalogLocalDataSource _catalog;
  final ReferenceData _reference;
  final StockEntryDataSource _entries;
  final SessionManager _session;

  Future<void> load() async {
    final session = _session.current;
    if (session == null) return;
    final products = {for (final p in await _catalog.products(includeInactive: false)) p.id: p.name};
    final variants = [
      for (final (productId, v) in await _catalog.variantsWithProduct(activeOnly: true))
        StockLine(productName: products[productId] ?? '', variant: v),
    ];
    final accounts = await _reference.accounts();
    final known = await _catalog.isBranchKnown(session.branchId);
    final closedAt = await _catalog.branchOpeningClosedAt(session.branchId);
    if (isClosed) return;
    emit(
      state.copyWith(
        variants: variants,
        accounts: accounts,
        openingAllowed: session.canOpeningStock && known && closedAt == null,
      ),
    );
  }

  Future<List<Party>> searchSuppliers(String query) => _reference.suppliers(query: query);

  Future<void> submit(StockEntryDraft draft) async {
    final error = draft.validate();
    if (error != null) return emit(state.copyWith(error: error));
    final session = _session.current;
    if (session == null) return;
    emit(state.copyWith(saving: true));
    await _entries.submit(session, draft);
    if (!isClosed) emit(state.copyWith(saving: false, saved: true));
  }
}
