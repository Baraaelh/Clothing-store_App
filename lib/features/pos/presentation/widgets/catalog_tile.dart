import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/catalog_item.dart';

class CatalogTile extends StatelessWidget {
  const CatalogTile({super.key, required this.item, required this.inCart, required this.onTap});

  final CatalogItem item;
  final int inCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockColor = item.isOutOfStock
        ? theme.colorScheme.error
        : item.availableQuantity <= 5
        ? Colors.orange.shade800
        : Colors.green.shade700;
    return Card.outlined(
      child: ListTile(
        enabled: !item.isOutOfStock,
        onTap: onTap,
        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([item.variantLabel, item.sku].where((s) => s.isNotEmpty).join(' • ')),
        leading: inCart > 0 ? CircleAvatar(child: Text('$inCart')) : const CircleAvatar(child: Icon(Icons.checkroom)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Money.format(item.sellingPrice), style: theme.textTheme.titleMedium),
            Text(
              item.isOutOfStock ? 'نفد' : 'متوفر: ${item.availableQuantity}',
              style: theme.textTheme.bodySmall?.copyWith(color: stockColor),
            ),
          ],
        ),
      ),
    );
  }
}
