import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_navigation.dart';
import 'admin_providers.dart';

class AdminPropertyDetailScreen extends ConsumerWidget {
  const AdminPropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminPropertyDetailProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Property detail')),
      body: detailAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(child: Text('$error')),
        data: (property) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(property.name,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(property.address),
            const SizedBox(height: 12),
            Text('Landlord: ${property.landlord?.fullName ?? '—'}'),
            Text('Rooms: ${property.roomCount}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  context.push(adminPropertyFormPath(propertyId: property.id)),
              child: const Text('Edit'),
            ),
            const SizedBox(height: 20),
            const Text('Rooms',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...property.rooms.map(
              (room) => Card(
                child: ListTile(
                  title: Text(room.name),
                  subtitle: Text(room.id),
                  trailing: Text(room.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
