import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/lease.dart';
import 'tenant_providers.dart';

class LeaseExpiryScreen extends ConsumerWidget {
  const LeaseExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leasesAsync = ref.watch(expiringLeasesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Hợp đồng sắp hết hạn')),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => ref.invalidate(expiringLeasesProvider),
        child: leasesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [_Card(child: Text('$error'))],
          ),
          data: (leases) {
            if (leases.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _Card(child: Text('Không có hợp đồng hết hạn trong 30 ngày.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: leases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _LeaseTile(lease: leases[index]),
            );
          },
        ),
      ),
    );
  }
}

class _LeaseTile extends StatelessWidget {
  const _LeaseTile({required this.lease});

  final ExpiringLease lease;

  @override
  Widget build(BuildContext context) {
    final days = lease.daysUntilEnd;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lease.tenantName ?? 'Tenant',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                days == null ? '-- ngày' : '$days ngày',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: days != null && days <= 7
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${lease.propertyName ?? 'Khu trọ'} · ${lease.roomName ?? 'Phòng'}'),
          const SizedBox(height: 6),
          Text('Hết hạn: ${formatDate(lease.endDate)}'),
          Text('Tiền thuê: ${formatCurrencyVnd(lease.monthlyRent)}'),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}
