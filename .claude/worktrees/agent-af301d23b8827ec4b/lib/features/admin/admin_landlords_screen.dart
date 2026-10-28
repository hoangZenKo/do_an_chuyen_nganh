import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../auth/auth_navigation.dart';
import 'admin_providers.dart';

class AdminLandlordsScreen extends ConsumerStatefulWidget {
  const AdminLandlordsScreen({super.key});

  @override
  ConsumerState<AdminLandlordsScreen> createState() =>
      _AdminLandlordsScreenState();
}

class _AdminLandlordsScreenState extends ConsumerState<AdminLandlordsScreen> {
  final _searchController = TextEditingController();
  String _status = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = AdminLandlordsQuery(
      search: _searchController.text,
      status: _status,
    );
    final landlordsAsync = ref.watch(adminLandlordsProvider(query));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Landlord accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(adminLandlordFormPath()),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add landlord'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(adminLandlordsProvider(query));
          try {
            await ref.read(adminLandlordsProvider(query).future);
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
                hintText: 'Search landlords',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _StatusChip(
                    label: 'All',
                    selected: _status == 'all',
                    onTap: () => setState(() => _status = 'all')),
                _StatusChip(
                    label: 'Active',
                    selected: _status == 'active',
                    onTap: () => setState(() => _status = 'active')),
                _StatusChip(
                    label: 'Inactive',
                    selected: _status == 'inactive',
                    onTap: () => setState(() => _status = 'inactive')),
              ],
            ),
            const SizedBox(height: 16),
            landlordsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (error, _) => Text('$error'),
              data: (landlords) {
                if (landlords.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('No landlords found.')),
                  );
                }
                return Column(
                  children: landlords
                      .map(
                        (landlord) => _LandlordCard(
                          landlord: landlord,
                          onTap: () => context
                              .push(adminLandlordDetailPath(landlord.id)),
                          onEdit: () => context.push(
                              adminLandlordFormPath(landlordId: landlord.id)),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _LandlordCard extends StatelessWidget {
  const _LandlordCard(
      {required this.landlord, required this.onTap, required this.onEdit});

  final AdminLandlordSummary landlord;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(landlord.fullName),
        subtitle: Text(
          '${landlord.email}\n'
          '${landlord.isActive ? 'Active' : 'Inactive'} · '
          '${landlord.propertyCount} properties · ${landlord.roomCount} rooms',
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
