import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import 'billing_providers.dart';

class BillingAgingScreen extends ConsumerStatefulWidget {
  const BillingAgingScreen({super.key});

  @override
  ConsumerState<BillingAgingScreen> createState() => _BillingAgingScreenState();
}

class _BillingAgingScreenState extends ConsumerState<BillingAgingScreen> {
  String _groupBy = 'tenant';

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(billingAgingProvider(_groupBy));
    return Scaffold(
      appBar: AppBar(title: const Text('Tuổi nợ')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(billingAgingProvider(_groupBy)),
                child: const Text('Thử lại'),
              ),
            ]),
          ),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>;
          final groups = (data['groups'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          final total = (summary['total'] as num).toInt();
          const labels = {
            'notDue': 'Chưa quá hạn / đến hạn hôm nay',
            'overdue1To7': 'Quá hạn 1–7 ngày',
            'overdue8To30': 'Quá hạn 8–30 ngày',
            'overdueOver30': 'Quá hạn trên 30 ngày',
            'undated': 'Chưa đặt hạn thanh toán',
          };
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(billingAgingProvider(_groupBy));
              await ref.read(billingAgingProvider(_groupBy).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text('Tổng công nợ',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(formatCurrencyVnd(total),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                    'Tính đến ${data['asOf']} · Giờ Việt Nam. Tiền dư chưa phân bổ không tự động bù trừ công nợ.'),
                const SizedBox(height: 20),
                for (final entry in labels.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(child: Text(entry.value)),
                      const SizedBox(width: 12),
                      Text(formatCurrencyVnd(
                          (summary[entry.key] as num).toInt())),
                    ]),
                  ),
                const Divider(height: 32),
                DropdownButtonFormField<String>(
                  value: _groupBy,
                  decoration: const InputDecoration(labelText: 'Tổng hợp theo'),
                  items: const [
                    DropdownMenuItem(
                        value: 'tenant', child: Text('Người thuê')),
                    DropdownMenuItem(value: 'property', child: Text('Khu trọ')),
                    DropdownMenuItem(value: 'room', child: Text('Phòng')),
                  ],
                  onChanged: (value) => setState(() => _groupBy = value!),
                ),
                const SizedBox(height: 12),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text('Không có công nợ trong khu trọ đang chọn.',
                        textAlign: TextAlign.center),
                  ),
                for (final group in groups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(group['name'] as String),
                    subtitle: Text('${group['invoiceCount']} hóa đơn còn nợ'),
                    trailing: Text(
                        formatCurrencyVnd((group['total'] as num).toInt())),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
