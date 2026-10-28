import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../../../models/billing.dart';

class InvoiceLineItems extends StatelessWidget {
  const InvoiceLineItems({super.key, required this.items});

  final List<InvoiceLineItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (!item.isLegacy)
                        Text(
                            '${item.quantity} ${item.unitLabel} × ${formatCurrencyVnd(item.unitPrice)}',
                            style: theme.textTheme.bodySmall),
                      if (item.tariffVersion != null)
                        Text('Biểu phí v${item.tariffVersion}',
                            style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 2,
                  child: Align(
                      alignment: Alignment.topRight,
                      child: Text(formatCurrencyVnd(item.amount),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700))),
                ),
              ],
            ),
          ),
        if (items.any((item) => item.isLegacy))
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Dữ liệu cũ: không có đơn giá và số lượng gốc.',
                  style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
