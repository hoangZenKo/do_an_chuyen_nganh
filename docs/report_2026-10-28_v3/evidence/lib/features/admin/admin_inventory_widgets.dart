import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../models/admin_inventory.dart';
import '../../models/admin_models.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_states.dart';

class AdminInventoryAccess extends ConsumerStatefulWidget {
  const AdminInventoryAccess({super.key, required this.builder});
  final Widget Function(BuildContext, WidgetRef) builder;
  @override
  ConsumerState<AdminInventoryAccess> createState() =>
      _AdminInventoryAccessState();
}

class _AdminInventoryAccessState extends ConsumerState<AdminInventoryAccess> {
  late final String? _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    if (owner == null || owner != _owner) return const SizedBox.shrink();
    if (rights.isLoading) return const AdminLoadingState();
    if (rights.hasError) {
      return AdminFailureState(
          error: rights.error!,
          retry: () => ref.invalidate(adminCapabilitiesProvider));
    }
    if (!rights.requireValue.has('admin.properties.view')) {
      return const WorkflowEmpty('Bạn không có quyền xem khu trọ/phòng.');
    }
    return widget.builder(context, ref);
  }
}

Widget adminInventoryFilter(
        {required String id,
        required String label,
        required String value,
        required Map<String, String> options,
        required double width,
        required ValueChanged<String> onChanged}) =>
    SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
            key: ValueKey(id),
            value: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: options.entries
                .map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            }));

const adminRoomStatuses = {
  'all': 'Mọi tình trạng',
  'VACANT': 'Còn trống',
  'OCCUPIED': 'Đang thuê',
  'MAINTENANCE': 'Bảo trì'
};
const adminListingStatuses = {
  'all': 'Mọi tin đăng',
  'NONE': 'Chưa có tin',
  'DRAFT': 'Bản nháp',
  'PENDING': 'Chờ duyệt',
  'PUBLISHED': 'Đã đăng',
  'REJECTED': 'Bị từ chối',
  'HIDDEN': 'Đã ẩn'
};

class AdminInventoryRoomCard extends ConsumerWidget {
  const AdminInventoryRoomCard({super.key, required this.room});
  final AdminPropertyRoom room;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property =
        room is AdminRoomSummary ? (room as AdminRoomSummary).property : null;
    final listing = room.listing;
    final canModerate = ref
            .watch(adminCapabilitiesProvider)
            .valueOrNull
            ?.has('admin.listings.moderate') ==
        true;
    return AdminSectionPanel(
        margin: const EdgeInsets.only(bottom: 12),
        title: room.name,
        children: [
          if (property != null) ...[
            Text(
                '${property.name} · ${property.landlord?.fullName ?? 'Không có chủ trọ'}'),
            if (property.isArchived) const Text('Khu trọ đã lưu trữ'),
            const SizedBox(height: 8)
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            AdminStatusBadge(
                label:
                    adminRoomStatuses[room.status.toUpperCase()] ?? room.status,
                statusKey: room.status),
            AdminStatusBadge(
                label: room.isActive ? 'Hoạt động' : 'Ngừng hoạt động',
                statusKey: room.isActive ? 'ACTIVE' : 'INACTIVE'),
          ]),
          const SizedBox(height: 12),
          Text('Giá nội bộ: ${formatCurrencyVnd(room.basePrice)}/tháng',
              style: Theme.of(context).textTheme.titleSmall),
          if (room.floor != null || room.areaSqm != null)
            Text([
              if (room.floor != null) 'Tầng ${room.floor}',
              if (room.areaSqm != null) formatArea(room.areaSqm)
            ].join(' · ')),
          const SizedBox(height: 8),
          if (listing == null)
            const Text('Chưa có tin đăng')
          else ...[
            Text('Tin đăng: ${listing.title}'),
            Text(
                'Giá tin đăng: ${formatCurrencyVnd(listing.monthlyRent)}/tháng'),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerLeft,
                child: AdminStatusBadge(
                    label:
                        adminListingStatuses[listing.status] ?? listing.status,
                    statusKey: listing.status)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: [
            if (property != null)
              OutlinedButton(
                  onPressed: () =>
                      context.push(adminPropertyDetailPath(property.id)),
                  child: const Text('Xem khu trọ')),
            if (listing?.status == 'PENDING' && canModerate)
              FilledButton.tonal(
                  onPressed: () async {
                    final owner = ref.read(sessionIdentityProvider);
                    await context.push(adminListingModerationPath(listing!.id));
                    if (!context.mounted ||
                        owner != ref.read(sessionIdentityProvider)) {
                      return;
                    }
                    ref.invalidate(adminRoomsProvider);
                    ref.invalidate(adminPropertyDetailProvider);
                  },
                  child: const Text('Kiểm duyệt tin này')),
          ]),
        ]);
  }
}
