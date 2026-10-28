import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final overviewAsync = ref.watch(adminOverviewProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(adminOverviewProvider);
          try {
            await ref.read(adminOverviewProvider.future);
          } catch (_) {}
        },
        child: overviewAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _Header(name: session?.user.fullName),
              _ErrorCard(
                  message: '$error',
                  onRetry: () => ref.invalidate(adminOverviewProvider)),
            ],
          ),
          data: (overview) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _Header(name: session?.user.fullName),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Landlords',
                      value: '${overview.landlordsTotal}',
                      sub: '${overview.landlordsActive} active',
                      icon: Icons.people_alt_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Properties',
                      value: '${overview.propertiesTotal}',
                      sub: '${overview.roomsTotal} rooms',
                      icon: Icons.apartment_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Tenants',
                      value: '${overview.tenantsTotal}',
                      sub: '${overview.activeLeasesTotal} active leases',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Inactive',
                      value: '${overview.landlordsInactive}',
                      sub: 'landlords',
                      icon: Icons.block_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ActionTile(
                icon: Icons.people_alt_outlined,
                title: 'Landlord accounts',
                subtitle: 'Manage platform-wide landlord users.',
                onTap: () => context.push(adminLandlordsRoute),
              ),
              _ActionTile(
                icon: Icons.apartment_outlined,
                title: 'Properties',
                subtitle: 'Review every property across the platform.',
                onTap: () => context.push(adminPropertiesRoute),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Recent landlords'),
              const SizedBox(height: 10),
              ...overview.recentLandlords.map(
                (landlord) => _LandlordRow(
                  landlord: landlord,
                  onTap: () =>
                      context.push(adminLandlordDetailPath(landlord.id)),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Recent properties'),
              const SizedBox(height: 10),
              ...overview.recentProperties.map(
                (property) => _PropertyRow(
                  property: property,
                  onTap: () =>
                      context.push(adminPropertyDetailPath(property.id)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${name ?? 'Admin'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Manage landlords and properties from one place.'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _LandlordRow extends StatelessWidget {
  const _LandlordRow({required this.landlord, required this.onTap});

  final AdminLandlordSummary landlord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(landlord.fullName),
        subtitle:
            Text('${landlord.email} · ${landlord.propertyCount} properties'),
        trailing: Text(
          landlord.isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            color: landlord.isActive ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.property, required this.onTap});

  final AdminPropertySummary property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(property.name),
        subtitle: Text('${property.address} · ${property.roomCount} rooms'),
        trailing: Text('${property.occupiedCount}/${property.roomCount}'),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
