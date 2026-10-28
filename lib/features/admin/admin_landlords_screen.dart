import 'package:flutter/material.dart';
import 'admin_workspace_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import '../../models/admin_models.dart';
import '../auth/auth_navigation.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_states.dart';

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

    return AdminWorkspaceScaffold(
      title: 'Chủ trọ',
      location: '/admin/landlords',
      body: RefreshIndicator(
        color: AdminOverviewTheme.blue,
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
            AdminSectionPanel(
              title: 'Danh mục chủ trọ',
              subtitle: 'Tra cứu chủ trọ, khu trọ và tình trạng tài khoản.',
              icon: Icons.people_outline,
              actions: [
                FilledButton.icon(
                  onPressed: () => context.push(adminLandlordFormPath()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm chủ trọ'),
                ),
              ],
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Tìm chủ trọ',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _StatusChip(
                        label: 'Tất cả',
                        selected: _status == 'all',
                        onTap: () => setState(() => _status = 'all')),
                    _StatusChip(
                        label: 'Hoạt động',
                        selected: _status == 'active',
                        onTap: () => setState(() => _status = 'active')),
                    _StatusChip(
                        label: 'Đã khóa',
                        selected: _status == 'inactive',
                        onTap: () => setState(() => _status = 'inactive')),
                  ],
                ),
                const SizedBox(height: 16),
                landlordsAsync.when(
                  loading: () => const AdminLoadingState(),
                  error: (error, _) => AdminFailureState(
                      error: error,
                      retry: () =>
                          ref.invalidate(adminLandlordsProvider(query))),
                  data: (landlords) {
                    if (landlords.isEmpty) {
                      return const WorkflowEmpty('Không tìm thấy chủ trọ.');
                    }
                    return Column(
                      children: landlords
                          .map(
                            (landlord) => _LandlordCard(
                              landlord: landlord,
                              onTap: () => context
                                  .push(adminLandlordDetailPath(landlord.id)),
                              onEdit: () => context.push(adminLandlordFormPath(
                                  landlordId: landlord.id)),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
              ],
            ),
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
          '${landlord.isActive ? 'Hoạt động' : 'Đã khóa'} · '
          '${landlord.propertyCount} khu trọ · ${landlord.roomCount} phòng',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Chỉnh sửa chủ trọ',
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
