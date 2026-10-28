import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/admin_models.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_inventory_widgets.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_workspace_states.dart';

class AdminPropertiesScreen extends ConsumerWidget {
  const AdminPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AdminWorkspaceScaffold(
      title: 'Khu trọ',
      location: adminPropertiesRoute,
      onRefresh: () => ref.invalidate(adminPropertiesProvider),
      body: ListView(
          key: const ValueKey('admin-properties-list'),
          padding: const EdgeInsets.all(16),
          children: const [AdminPropertiesPanel()]));
}

class AdminPropertiesPanel extends StatelessWidget {
  const AdminPropertiesPanel({super.key});
  @override
  Widget build(BuildContext context) =>
      AdminInventoryAccess(builder: (_, __) => const _PropertiesList());
}

class _PropertiesList extends ConsumerStatefulWidget {
  const _PropertiesList();
  @override
  ConsumerState<_PropertiesList> createState() => _PropertiesListState();
}

class _PropertiesListState extends ConsumerState<_PropertiesList> {
  late final String? _owner;
  late final TextEditingController _search;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _search = TextEditingController(
        text: ref.read(adminPropertiesQueryProvider).search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _update(AdminPropertiesQuery query) {
    if (mounted &&
        _owner != null &&
        ref.read(sessionIdentityProvider) == _owner &&
        !ref.read(adminCapabilitiesProvider).isLoading &&
        ref
                .read(adminCapabilitiesProvider)
                .valueOrNull
                ?.has('admin.properties.view') ==
            true) {
      ref.read(adminPropertiesQueryProvider.notifier).state = query;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminPropertiesQueryProvider);
    final result = ref.watch(adminPropertiesProvider(query));
    final canManage = ref
            .watch(adminCapabilitiesProvider)
            .valueOrNull
            ?.has('admin.properties.manage') ==
        true;
    return AdminSectionPanel(
        icon: Icons.apartment_outlined,
        title: 'Danh mục khu trọ',
        subtitle:
            'Theo dõi khu trọ, chủ sở hữu và tình trạng phòng. Liên hệ được che mặc định.',
        actions: [
          OutlinedButton.icon(
              onPressed: () => context.go(adminPropertyReviewsRoute),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Duyệt khu trọ')),
          if (canManage)
            FilledButton.icon(
                onPressed: () => context.push(adminPropertyFormPath()),
                icon: const Icon(Icons.add),
                label: const Text('Thêm khu trọ'))
        ],
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = math.min(260.0, constraints.maxWidth - 28);
            return AdminToolbarPanel(children: [
              SizedBox(
                  width: width,
                  child: TextField(
                      key: const ValueKey('property-search'),
                      controller: _search,
                      maxLength: 120,
                      decoration: const InputDecoration(
                          labelText: 'Tìm khu trọ, địa chỉ, chủ trọ',
                          prefixIcon: Icon(Icons.search),
                          counterText: ''),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 350), () {
                          if (mounted) {
                            _update(ref
                                .read(adminPropertiesQueryProvider)
                                .copyWith(page: 1, search: value.trim()));
                          }
                        });
                      })),
              adminInventoryFilter(
                  id: 'property-archived',
                  label: 'Khu trọ',
                  value: query.archived,
                  width: width,
                  options: const {
                    'all': 'Tất cả khu trọ',
                    'active': 'Chưa lưu trữ',
                    'archived': 'Đã lưu trữ'
                  },
                  onChanged: (value) =>
                      _update(query.copyWith(page: 1, archived: value))),
              adminInventoryFilter(
                  id: 'property-owner-status',
                  label: 'Tài khoản chủ trọ',
                  value: query.ownerStatus,
                  width: width,
                  options: const {
                    'all': 'Mọi chủ trọ',
                    'active': 'Đang hoạt động',
                    'inactive': 'Đã khóa'
                  },
                  onChanged: (value) =>
                      _update(query.copyWith(page: 1, ownerStatus: value))),
            ]);
          }),
          result.when(
              skipLoadingOnRefresh: false,
              loading: () => const AdminLoadingState(),
              error: (error, _) => AdminFailureState(
                  error: error,
                  retry: () => ref.invalidate(adminPropertiesProvider(query))),
              data: (page) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (page.data.isEmpty)
                          const WorkflowEmpty(
                              'Không tìm thấy khu trọ phù hợp.'),
                        for (final property in page.data)
                          AdminSectionPanel(
                              margin: const EdgeInsets.only(bottom: 12),
                              title: property.name,
                              subtitle: property.address,
                              children: [
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  AdminStatusBadge(
                                      label: property.isArchived
                                          ? 'Đã lưu trữ'
                                          : 'Chưa lưu trữ',
                                      statusKey: property.isArchived
                                          ? 'INACTIVE'
                                          : 'ACTIVE'),
                                  if (property.landlord != null)
                                    AdminStatusBadge(
                                        label: property.landlord!.isActive
                                            ? 'Chủ trọ hoạt động'
                                            : 'Chủ trọ đã khóa',
                                        statusKey: property.landlord!.isActive
                                            ? 'ACTIVE'
                                            : 'INACTIVE'),
                                ]),
                                const SizedBox(height: 12),
                                Text(property.landlord?.fullName ??
                                    'Không có chủ trọ'),
                                Text(
                                    '${property.roomCount} phòng · ${property.occupiedCount} đang thuê · ${property.vacantCount} còn trống'),
                                const SizedBox(height: 12),
                                Wrap(spacing: 12, runSpacing: 8, children: [
                                  OutlinedButton(
                                      onPressed: () => context.push(
                                          adminPropertyDetailPath(property.id)),
                                      child: const Text('Xem chi tiết')),
                                  if (canManage)
                                    TextButton(
                                        onPressed: () => context.push(
                                            adminPropertyFormPath(
                                                propertyId: property.id)),
                                        child: const Text('Chỉnh sửa')),
                                ]),
                              ]),
                        WorkflowPager(
                            page: page.page,
                            total: page.total,
                            limit: page.limit,
                            onPage: (value) =>
                                _update(query.copyWith(page: value))),
                      ])),
        ]);
  }
}
