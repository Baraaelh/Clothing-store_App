import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/money.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/catalog_tile.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      listenWhen: (_, s) => s.message != null,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث بالاسم أو الكود أو SKU',
              ),
              onChanged: context.read<CatalogCubit>().search,
            ),
          ),
          const Expanded(child: _CatalogList()),
          const _CartBar(),
        ],
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, state) {
        switch (state.status) {
          case CatalogStatus.initial:
          case CatalogStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case CatalogStatus.failure:
            return Center(child: Text(state.error ?? 'حدث خطأ'));
          case CatalogStatus.loaded:
            if (state.items.isEmpty) {
              return Center(
                child: Text(state.query.isEmpty ? 'لا توجد منتجات بعد. ستظهر بعد أول مزامنة.' : 'لا توجد نتائج'),
              );
            }
            return BlocBuilder<CartCubit, CartState>(
              builder: (context, cart) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = state.items[i];
                  return CatalogTile(
                    item: item,
                    inCart: cart.quantityOf(item.variantId),
                    onTap: () => context.read<CartCubit>().add(item),
                  );
                },
              ),
            );
        }
      },
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        if (cart.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => CartSheet.show(context),
              child: Row(
                children: [
                  Badge(label: Text('${cart.itemCount}'), child: const Icon(Icons.shopping_cart)),
                  const SizedBox(width: 16),
                  const Text('عرض السلة'),
                  const Spacer(),
                  Text(Money.format(cart.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
