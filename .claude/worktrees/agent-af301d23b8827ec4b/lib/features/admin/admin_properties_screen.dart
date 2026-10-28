import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../auth/auth_navigation.dart';
import 'admin_providers.dart';

class AdminPropertiesScreen extends ConsumerStatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  ConsumerState<AdminPropertiesScreen> createState() =>
      _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends ConsumerState<AdminPropertiesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = AdminPropertiesQuery(search: _searchController.text);
    final propertiesAsync = ref.watch(adminPropertiesProvider(query));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Properties')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(adminPropertyFormPath()),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add property'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(adminPropertiesProvider(query));
          try {
            await ref.read(adminPropertiesProvider(query).future);
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search properties',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            propertiesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (error, _) => Text('$error'),
              data: (properties) {
                if (properties.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('No properties found.')),
                  );
                }
                return Column(
                  children: properties
                      .map(
                        (property) => _PropertyCard(
                          property: property,
                          onTap: () => context
                              .push(adminPropertyDetailPath(property.id)),
                          onEdit: () => context.push(
                              adminPropertyFormPath(propertyId: property.id)),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard(
      {required this.property, required this.onTap, required this.onEdit});

  final AdminPropertySummary property;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(property.name),
        subtitle: Text(
          '${property.address}\n'
          '${property.landlord?.fullName ?? 'No landlord'} · '
          '${property.roomCount} rooms · ${property.vacantCount} vacant',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
