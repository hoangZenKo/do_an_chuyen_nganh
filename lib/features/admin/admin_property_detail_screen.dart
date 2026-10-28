import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../auth/auth_navigation.dart';
import 'admin_inventory_widgets.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_workspace_states.dart';

class AdminPropertyDetailScreen extends ConsumerWidget {
  const AdminPropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AdminWorkspaceScaffold(
      title: 'Chi tiết khu trọ',
      location: adminPropertyDetailPath(propertyId),
      onRefresh: () => ref.invalidate(adminPropertyDetailProvider(propertyId)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(adminPropertiesRoute),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Danh sách khu trọ'))),
        AdminPropertyDetailPanel(propertyId: propertyId),
      ]));
}

class AdminPropertyDetailPanel extends StatelessWidget {
  const AdminPropertyDetailPanel({super.key, required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context) =>
      AdminInventoryAccess(builder: (context, ref) {
        final result = ref.watch(adminPropertyDetailProvider(propertyId));
        final canManage = ref
                .watch(adminCapabilitiesProvider)
                .valueOrNull
                ?.has('admin.properties.manage') ==
            true;
        return result.when(
            skipLoadingOnRefresh: false,
            loading: () => const AdminLoadingState(),
            error: (error, _) => error is ApiFailure && error.statusCode == 404
                ? const WorkflowEmpty(
                    'Khu trọ không còn tồn tại hoặc không khả dụng.')
                : AdminFailureState(
                    error: error,
                    retry: () => ref
                        .invalidate(adminPropertyDetailProvider(propertyId))),
            data: (property) => AdminSectionPanel(
                    icon: Icons.apartment_outlined,
                    title: property.name,
                    subtitle: property.address,
                    actions: [
                      OutlinedButton(
                          onPressed: () =>
                              context.go(adminPropertyReviewsRoute),
                          child: const Text('Hồ sơ duyệt khu trọ')),
                      if (canManage)
                        OutlinedButton(
                            onPressed: () => context.push(
                                adminPropertyFormPath(propertyId: property.id)),
                            child: const Text('Chỉnh sửa'))
                    ],
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: AdminStatusBadge(
                              label: property.isArchived
                                  ? 'Đã lưu trữ'
                                  : 'Chưa lưu trữ',
                              statusKey:
                                  property.isArchived ? 'INACTIVE' : 'ACTIVE')),
                      const SizedBox(height: 16),
                      Text(
                          '${property.roomCount} phòng · ${property.occupiedCount} đang thuê · ${property.vacantCount} còn trống',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          'Hồ sơ khu trọ: ${workflowLabel(property.approvalStatus)} · v${property.approvalVersion}'),
                      const Text(
                          'Trạng thái hồ sơ độc lập với lưu trữ và kiểm duyệt tin đăng.'),
                      const SizedBox(height: 16),
                      Text(
                          'Chủ trọ: ${property.landlord?.fullName ?? 'Không có'}'),
                      if (property.landlord != null) ...[
                        Text(property.landlord!.isActive
                            ? 'Tài khoản chủ trọ đang hoạt động'
                            : 'Tài khoản chủ trọ đã khóa'),
                        Text(property.landlord!.email),
                        if (property.landlord!.phone != null)
                          Text(property.landlord!.phone!),
                        const Text('Thông tin liên hệ đã được che.'),
                      ],
                      const SizedBox(height: 24),
                      Text(
                          'Xem trước ${property.rooms.length} / ${property.roomCount} phòng',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text(
                          'Danh sách xem trước tối đa 20 phòng. Số liệu tổng bao gồm toàn bộ phòng trong khu trọ.'),
                      const SizedBox(height: 12),
                      if (property.rooms.isEmpty)
                        const WorkflowEmpty('Khu trọ chưa có phòng.'),
                      for (final room in property.rooms)
                        AdminInventoryRoomCard(room: room),
                      OutlinedButton.icon(
                          onPressed: () => context
                              .push(adminRoomsPath(propertyId: property.id)),
                          icon: const Icon(Icons.meeting_room_outlined),
                          label: const Text('Xem toàn bộ phòng của khu trọ')),
                    ]));
      });
}
