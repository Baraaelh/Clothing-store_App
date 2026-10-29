import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/online_order.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.busy, required this.onAccept, required this.onReject});

  final OnlineOrder order;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  static final _date = DateFormat('d/M  HH:mm', 'en');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (order.status) {
      OnlineOrderStatus.pending => Colors.orange.shade800,
      OnlineOrderStatus.accepted => Colors.green.shade700,
      OnlineOrderStatus.rejected => theme.colorScheme.error,
    };
    final place = [order.city, order.address].whereType<String>().where((s) => s.isNotEmpty).join(' - ');

    return Card.outlined(
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(Money.format(order.total), style: theme.textTheme.titleMedium),
          ],
        ),
        subtitle: Row(
          children: [
            Text('${order.id} • ${_date.format(order.createdAt.toLocal())}'),
            const Spacer(),
            if (order.hasUnsyncedChange)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 6),
                child: Tooltip(message: 'لم يُرسل للسيرفر بعد', child: Icon(Icons.cloud_upload_outlined, size: 16)),
              ),
            Text(
              order.status.label,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.phone != null) _info(Icons.phone_outlined, order.phone!),
          if (place.isNotEmpty) _info(Icons.location_on_outlined, place),
          if (order.notes?.isNotEmpty ?? false) _info(Icons.notes, order.notes!),
          const Divider(),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name}${[item.color, item.size].whereType<String>().isEmpty ? '' : ' (${[item.color, item.size].whereType<String>().join(' / ')})'}',
                    ),
                  ),
                  Text('×${item.quantity}  ${Money.format(item.lineTotal)}'),
                ],
              ),
            ),
          if (order.canChangeStatus) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('قبول'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
