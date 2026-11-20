import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/sync/sync_cubit.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/color_dot.dart';
import '../domain/product.dart';
import 'product_form_page.dart';
import 'products_cubit.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canManage = sl<SessionManager>().current?.canManageCatalog ?? false;
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt || a.pendingCount != b.pendingCount,
      listener: (context, _) => context.read<ProductsCubit>().load(),
      child: Scaffold(
        floatingActionButton: canManage
            ? FloatingActionButton.extended(
                heroTag: 'add-product',
                onPressed: () => ProductFormPage.open(context),
                icon: const Icon(Icons.add),
                label: const Text('منتج جديد'),
              )
            : null,
        body: BlocBuilder<ProductsCubit, ProductsState>(
          builder: (context, state) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث بالاسم أو الكود أو SKU',
                  ),
                  onChanged: context.read<ProductsCubit>().search,
                ),
              ),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.products.isEmpty && state.pending.isEmpty
                    ? Center(
                        child: Text(state.query.isEmpty ? 'لا توجد منتجات بعد. تظهر بعد أول مزامنة.' : 'لا توجد نتائج'),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        children: [
                          for (final op in state.pending)
                            Card.outlined(
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.cloud_upload_outlined)),
                                title: Text(op.summary),
                                subtitle: const Text('بانتظار اعتماد السيرفر'),
                              ),
                            ),
                          for (final p in state.products) _ProductTile(product: p),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = product.minPrice == product.maxPrice
        ? Money.format(product.minPrice)
        : '${Money.format(product.minPrice)} – ${Money.format(product.maxPrice)}';
    return Card.outlined(
      child: ListTile(
        onTap: () => ProductDetailPage.open(context, product.id),
        leading: CircleAvatar(child: Text('${product.variantCount}')),
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.w600, color: product.isActive ? null : Colors.grey),
        ),
        subtitle: Text(
          [product.code, product.categoryName, if (!product.isActive) 'غير فعّال'].whereType<String>().join(' • '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price, style: theme.textTheme.titleSmall),
            Text(
              'متاح: ${product.totalAvailable}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: product.totalAvailable == 0 ? theme.colorScheme.error : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key});

  static Future<void> open(BuildContext context, int productId) {
    final sync = context.read<SyncCubit>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sync),
            BlocProvider(create: (_) => ProductDetailCubit(sl(), productId)..load()),
          ],
          child: const ProductDetailPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>().current;
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt,
      listener: (context, _) => context.read<ProductDetailCubit>().load(),
      child: BlocBuilder<ProductDetailCubit, ProductDetail?>(
        builder: (context, product) => Scaffold(
          appBar: AppBar(
            title: Text(product?.name ?? 'المنتج'),
            actions: [
              if (product != null && (session?.canManageCatalog ?? false))
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => ProductFormPage.open(context, current: product),
                ),
            ],
          ),
          body: product == null
              ? const Center(child: Text('المنتج غير موجود في البيانات المحلية'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      [
                        product.code,
                        product.categoryName,
                        product.isActive ? 'فعّال' : 'غير فعّال',
                      ].whereType<String>().join(' • '),
                    ),
                    if (product.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(product.description!),
                    ],
                    const SizedBox(height: 16),
                    Text('الأصناف', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final v in product.variants)
                      Card.outlined(
                        child: ListTile(
                          leading: ColorDot(hex: v.colorHex, size: 22),
                          title: Text(v.label.isEmpty ? v.sku : v.label),
                          subtitle: Text(
                            [
                              v.sku,
                              if (v.minPrice != null) 'الحد الأدنى ${Money.format(v.minPrice!)}',
                              if (v.averageCost != null && (session?.canSeeCost ?? false))
                                'التكلفة ${Money.format(v.averageCost!)}',
                              if (!v.isActive) 'غير فعّال',
                            ].join(' • '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(Money.format(v.price), style: Theme.of(context).textTheme.titleSmall),
                              Text(
                                v.quantity == null
                                    ? 'لا رصيد بالفرع'
                                    : 'متاح ${v.available}${(v.reserved ?? 0) > 0 ? ' • محجوز ${v.reserved}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
