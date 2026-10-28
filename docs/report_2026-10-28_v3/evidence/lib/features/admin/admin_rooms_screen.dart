import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_inventory.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_inventory_widgets.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_workspace_states.dart';

class AdminRoomsScreen extends ConsumerWidget {
  const AdminRoomsScreen({super.key, this.propertyId});
  final String? propertyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AdminWorkspaceScaffold(
      title: 'Danh mục phòng',
      location: adminRoomsRoute,
      onRefresh: () => ref.invalidate(adminRoomsProvider),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: [AdminRoomsPanel(propertyId: propertyId)]));
}

class AdminRoomsPanel extends StatelessWidget {
  const AdminRoomsPanel({super.key, this.propertyId});
  final String? propertyId;
  @override
  Widget build(BuildContext context) => AdminInventoryAccess(
      builder: (_, __) =>
          _RoomsList(key: ValueKey(propertyId), propertyId: propertyId));
}

class _RoomsList extends ConsumerStatefulWidget {
  const _RoomsList({super.key, this.propertyId});
  final String? propertyId;
  @override
  ConsumerState<_RoomsList> createState() => _RoomsListState();
}

class _RoomsListState extends ConsumerState<_RoomsList> {
  late final String? _owner;
  late final TextEditingController _search, _min, _max;
  Timer? _debounce;
  String? _priceError;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    final query = ref.read(adminRoomsQueryProvider(widget.propertyId));
    _search = TextEditingController(text: query.search);
    _min = TextEditingController(text: query.minPrice?.toString());
    _max = TextEditingController(text: query.maxPrice?.toString());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _update(AdminRoomsQuery query) {
    if (mounted &&
        _owner != null &&
        ref.read(sessionIdentityProvider) == _owner &&
        !ref.read(adminCapabilitiesProvider).isLoading &&
        ref
                .read(adminCapabilitiesProvider)
                .valueOrNull
                ?.has('admin.properties.view') ==
            true) {
      ref.read(adminRoomsQueryProvider(widget.propertyId).notifier).state =
          query;
    }
  }

  void _applyPrices() {
    final minText = _min.text.trim(), maxText = _max.text.trim();
    final minPrice = int.tryParse(minText), maxPrice = int.tryParse(maxText);
    String? error;
    if ((minText.isNotEmpty &&
            (!RegExp(r'^\d+$').hasMatch(minText) ||
                minPrice == null ||
                minPrice > 2147483647)) ||
        (maxText.isNotEmpty &&
            (!RegExp(r'^\d+$').hasMatch(maxText) ||
                maxPrice == null ||
                maxPrice > 2147483647))) {
      error = 'Nhập giá nguyên từ 0 đến 2.147.483.647 đồng.';
    } else if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      error = 'Giá tối thiểu không được lớn hơn giá tối đa.';
    }
    setState(() => _priceError = error);
    if (error != null) return;
    _update(ref
        .read(adminRoomsQueryProvider(widget.propertyId))
        .copyWith(page: 1, clearPrices: true)
        .copyWith(minPrice: minPrice, maxPrice: maxPrice));
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminRoomsQueryProvider(widget.propertyId));
    final result = ref.watch(adminRoomsProvider(query));
    return AdminSectionPanel(
        icon: Icons.meeting_room_outlined,
        title: 'Danh mục phòng',
        subtitle:
            'Chỉ xem dữ liệu vận hành. Giá nội bộ và giá tin đăng được hiển thị riêng; kiểm duyệt không thay đổi hợp đồng hay hóa đơn.',
        children: [
          if (query.propertyId != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(spacing: 12, runSpacing: 8, children: [
                  const Text('Đang lọc phòng theo khu trọ'),
                  TextButton(
                      onPressed: () =>
                          _update(query.copyWith(page: 1, clearProperty: true)),
                      child: const Text('Bỏ lọc khu trọ')),
                ])),
          LayoutBuilder(builder: (context, constraints) {
            final width = math.min(260.0, constraints.maxWidth - 28);
            return AdminToolbarPanel(children: [
              SizedBox(
                  width: width,
                  child: TextField(
                      key: const ValueKey('room-search'),
                      controller: _search,
                      maxLength: 120,
                      decoration: const InputDecoration(
                          labelText: 'Tìm phòng, khu trọ, chủ trọ',
                          prefixIcon: Icon(Icons.search),
                          counterText: ''),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 350), () {
                          if (mounted) {
                            _update(ref
                                .read(
                                    adminRoomsQueryProvider(widget.propertyId))
                                .copyWith(page: 1, search: value.trim()));
                          }
                        });
                      })),
              adminInventoryFilter(
                  id: 'room-status',
                  label: 'Tình trạng phòng',
                  value: query.status,
                  width: width,
                  options: adminRoomStatuses,
                  onChanged: (value) =>
                      _update(query.copyWith(page: 1, status: value))),
              adminInventoryFilter(
                  id: 'room-activity',
                  label: 'Hoạt động',
                  value: query.activity,
                  width: width,
                  options: const {
                    'all': 'Mọi trạng thái',
                    'active': 'Hoạt động',
                    'inactive': 'Ngừng hoạt động'
                  },
                  onChanged: (value) =>
                      _update(query.copyWith(page: 1, activity: value))),
              adminInventoryFilter(
                  id: 'room-listing-status',
                  label: 'Tin đăng',
                  value: query.listingStatus,
                  width: width,
                  options: adminListingStatuses,
                  onChanged: (value) =>
                      _update(query.copyWith(page: 1, listingStatus: value))),
              SizedBox(
                  width: width,
                  child: TextField(
                      key: const ValueKey('room-min-price'),
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Giá nội bộ từ (đồng)'),
                      onSubmitted: (_) => _applyPrices())),
              SizedBox(
                  width: width,
                  child: TextField(
                      key: const ValueKey('room-max-price'),
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Giá nội bộ đến (đồng)'),
                      onSubmitted: (_) => _applyPrices())),
              OutlinedButton(
                  onPressed: _applyPrices, child: const Text('Áp dụng giá')),
              if (query.minPrice != null ||
                  query.maxPrice != null ||
                  _priceError != null)
                TextButton(
                    onPressed: () {
                      _min.clear();
                      _max.clear();
                      setState(() => _priceError = null);
                      _update(query.copyWith(page: 1, clearPrices: true));
                    },
                    child: const Text('Xóa lọc giá')),
            ]);
          }),
          if (_priceError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_priceError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (query.minPrice != null || query.maxPrice != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                    'Đang áp dụng giá nội bộ: ${query.minPrice ?? 0} – ${query.maxPrice?.toString() ?? 'không giới hạn'} đồng')),
          result.when(
              skipLoadingOnRefresh: false,
              loading: () => const AdminLoadingState(),
              error: (error, _) => AdminFailureState(
                  error: error,
                  retry: () => ref.invalidate(adminRoomsProvider(query))),
              data: (page) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (page.data.isEmpty)
                          const WorkflowEmpty('Không tìm thấy phòng phù hợp.'),
                        for (final room in page.data)
                          AdminInventoryRoomCard(room: room),
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
