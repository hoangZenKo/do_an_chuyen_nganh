import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_navigation.dart';
import 'admin_providers.dart';

class AdminLandlordDetailScreen extends ConsumerWidget {
  const AdminLandlordDetailScreen({super.key, required this.landlordId});

  final String landlordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminLandlordDetailProvider(landlordId));
    final statusAsync = ref.watch(adminLandlordStatusControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Landlord detail')),
      body: detailAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(child: Text('$error')),
        data: (landlord) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(landlord.fullName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(landlord.email),
                  Text(landlord.phone ?? '—'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _Tag('${landlord.propertyCount} properties'),
                      _Tag('${landlord.roomCount} rooms'),
                      _Tag('${landlord.activeLeaseCount} active leases'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push(
                            adminLandlordFormPath(landlordId: landlord.id)),
                        child: const Text('Edit'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push(
                            adminPropertyFormPath(landlordId: landlord.id)),
                        child: const Text('Add property'),
                      ),
                      OutlinedButton(
                        onPressed: statusAsync.isLoading
                            ? null
                            : () => _confirmStatusChange(
                                context, ref, landlord.id, landlord.isActive),
                        child: statusAsync.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(landlord.isActive
                                ? 'Deactivate'
                                : 'Reactivate'),
                      ),
                    ],
                  ),
                  if (statusAsync.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${statusAsync.error}',
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Recent properties',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...landlord.recentProperties.map(
              (property) => Card(
                child: ListTile(
                  onTap: () =>
                      context.push(adminPropertyDetailPath(property.id)),
                  title: Text(property.name),
                  subtitle: Text(property.address),
                  trailing: Text('${property.roomCount} rooms'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref,
    String landlordId,
    bool isActive,
  ) async {
    final nextActive = !isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(nextActive ? 'Reactivate landlord?' : 'Deactivate landlord?'),
        content: Text(
          nextActive
              ? 'This landlord will be able to access protected landlord features again.'
              : 'This landlord will no longer be able to access protected landlord features.',
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => context.pop(true),
            child: Text(nextActive ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(adminLandlordStatusControllerProvider.notifier)
          .submit(landlordId: landlordId, isActive: nextActive);
    } catch (_) {
      // Provider state renders the error message.
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
