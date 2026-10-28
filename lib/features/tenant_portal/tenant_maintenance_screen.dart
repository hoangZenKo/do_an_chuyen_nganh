import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/maintenance.dart';
import '../listings/listing_widgets.dart';
import 'tenant_portal_providers.dart';

const _background = Color(0xFFF7F7F7);
const _panel = Color(0xFFFFFFFF);
const _panelAlt = Color(0xFFF7F7F7);
const _line = Color(0xFFEBEBEB);
const _muted = Color(0xFF717171);
const _ink = Color(0xFF222222);
const _success = Color(0xFF0F8A6A);
const _warning = Color(0xFFD97706);
const _danger = Color(0xFFDC2626);

enum _TenantMaintenanceFilter {
  all,
  open,
  inProgress,
  done,
  cancelled;

  String get label => switch (this) {
        _TenantMaintenanceFilter.all => 'Tất cả',
        _TenantMaintenanceFilter.open => 'Đang mở',
        _TenantMaintenanceFilter.inProgress => 'Đang xử lý',
        _TenantMaintenanceFilter.done => 'Đã xong',
        _TenantMaintenanceFilter.cancelled => 'Đã hủy',
      };
}

class TenantMaintenanceScreen extends ConsumerStatefulWidget {
  const TenantMaintenanceScreen({super.key});

  @override
  ConsumerState<TenantMaintenanceScreen> createState() =>
      _TenantMaintenanceScreenState();
}

class _TenantMaintenanceScreenState
    extends ConsumerState<TenantMaintenanceScreen> {
  var _filter = _TenantMaintenanceFilter.all;

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(tenantPortalMaintenanceProvider.future),
      ref.refresh(tenantPortalDashboardProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceAsync = ref.watch(tenantPortalMaintenanceProvider);

    return ListingTheme(
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'Yêu cầu bảo trì',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateMaintenanceSheet(context, ref),
          backgroundColor: kAirbnbRose,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Báo sự cố',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: RefreshIndicator(
          color: kAirbnbRose,
          onRefresh: _refresh,
          child: maintenanceAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                _EmptyPanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được yêu cầu bảo trì',
                  subtitle: '$error',
                  action: TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(tenantPortalMaintenanceProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ),
              ],
            ),
            data: (tickets) {
              final visible = tickets
                  .where((ticket) => _matchesFilter(ticket, _filter))
                  .toList(growable: false);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _SummaryPanel(tickets: tickets),
                  const SizedBox(height: 14),
                  _QuickIssueGrid(
                    onSelect: (presetTitle) => _showCreateMaintenanceSheet(
                      context,
                      ref,
                      initialTitle: presetTitle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(
                    value: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 14),
                  if (tickets.isEmpty)
                    _EmptyPanel(
                      icon: Icons.construction_rounded,
                      title: 'Chưa có yêu cầu bảo trì',
                      subtitle:
                          'Khi có hư hỏng trong phòng, gửi mô tả và ảnh để chủ trọ xử lý nhanh hơn.',
                      action: FilledButton.icon(
                        onPressed: () => _showCreateMaintenanceSheet(
                          context,
                          ref,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Báo sự cố'),
                      ),
                    )
                  else if (visible.isEmpty)
                    _EmptyPanel(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Không có yêu cầu phù hợp',
                      subtitle: 'Đổi bộ lọc để xem các yêu cầu khác.',
                      action: TextButton(
                        onPressed: () => setState(
                          () => _filter = _TenantMaintenanceFilter.all,
                        ),
                        child: const Text('Xem tất cả'),
                      ),
                    )
                  else
                    for (final ticket in visible) ...[
                      _MaintenanceTile(
                        ticket: ticket,
                        onTap: () => _showMaintenanceDetailSheet(
                          context,
                          ref,
                          ticket,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _matchesFilter(
  MaintenanceTicket ticket,
  _TenantMaintenanceFilter filter,
) {
  return switch (filter) {
    _TenantMaintenanceFilter.all => true,
    _TenantMaintenanceFilter.open => ticket.status == MaintenanceStatus.open,
    _TenantMaintenanceFilter.inProgress =>
      ticket.status == MaintenanceStatus.inProgress,
    _TenantMaintenanceFilter.done => ticket.status == MaintenanceStatus.done,
    _TenantMaintenanceFilter.cancelled =>
      ticket.status == MaintenanceStatus.cancelled,
  };
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.tickets});

  final List<MaintenanceTicket> tickets;

  @override
  Widget build(BuildContext context) {
    final openCount = tickets
        .where((ticket) =>
            ticket.status == MaintenanceStatus.open ||
            ticket.status == MaintenanceStatus.inProgress)
        .length;
    final urgentCount = tickets
        .where((ticket) =>
            ticket.priority == MaintenancePriority.urgent &&
            ticket.status != MaintenanceStatus.done &&
            ticket.status != MaintenanceStatus.cancelled)
        .length;
    final doneCount = tickets
        .where((ticket) => ticket.status == MaintenanceStatus.done)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(
                icon: openCount > 0
                    ? Icons.construction_rounded
                    : Icons.check_circle_rounded,
                color: openCount > 0 ? _warning : _success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      openCount > 0
                          ? 'Đang chờ xử lý'
                          : 'Không còn sự cố đang mở',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$openCount yêu cầu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: openCount > 0 ? _warning : _success,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                icon: Icons.format_list_bulleted_rounded,
                label: '${tickets.length} tổng yêu cầu',
              ),
              _MetricChip(
                icon: Icons.priority_high_rounded,
                label: '$urgentCount khẩn cấp',
                color: urgentCount > 0 ? _danger : _muted,
              ),
              _MetricChip(
                icon: Icons.verified_rounded,
                label: '$doneCount đã xong',
                color: doneCount > 0 ? _success : _muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _TenantMaintenanceFilter value;
  final ValueChanged<_TenantMaintenanceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _TenantMaintenanceFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: value == filter,
              onSelected: (_) => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _MaintenanceTile extends StatelessWidget {
  const _MaintenanceTile({required this.ticket, required this.onTap});

  final MaintenanceTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roomLabel = [
      if (ticket.roomName?.trim().isNotEmpty == true) ticket.roomName!.trim(),
      if (ticket.propertyName?.trim().isNotEmpty == true)
        ticket.propertyName!.trim(),
    ].join(' · ');

    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: ticket.status.icon, color: ticket.status.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (roomLabel.isNotEmpty) roomLabel,
                        if (ticket.reportedAt != null)
                          'Báo ${formatDate(ticket.reportedAt)}',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusPill(
                          label: ticket.status.label,
                          color: ticket.status.color,
                        ),
                        _StatusPill(
                          label: ticket.priority.label,
                          color: ticket.priority.color,
                        ),
                        if (ticket.comments.isNotEmpty)
                          _StatusPill(
                            label: '${ticket.comments.length} phản hồi',
                            color: _muted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickIssueGrid extends StatelessWidget {
  const _QuickIssueGrid({required this.onSelect});

  final ValueChanged<String> onSelect;

  static const _items = <({String emoji, String label, String preset})>[
    (
      emoji: '❄️',
      label: 'Điều hòa / Nóng lạnh',
      preset: 'Kiểm tra điều hòa / bình nóng lạnh',
    ),
    (
      emoji: '💡',
      label: 'Hệ thống Điện',
      preset: 'Sự cố điện / bóng đèn trong phòng',
    ),
    (
      emoji: '🚿',
      label: 'Ống nước / Vòi',
      preset: 'Rò rỉ nước / vòi nước cần sửa',
    ),
    (
      emoji: '🔑',
      label: 'Khóa cửa / Wifi',
      preset: 'Hỗ trợ khóa cửa / kết nối Wifi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn nhanh sự cố cần hỗ trợ',
            style: TextStyle(
              color: _ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final colWidth = constraints.maxWidth >= 340
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in _items)
                    SizedBox(
                      width: colWidth,
                      child: Material(
                        color: _panelAlt,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => onSelect(item.preset),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: kAirbnbRose.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showCreateMaintenanceSheet(
  BuildContext context,
  WidgetRef ref, {
  String initialTitle = '',
}) async {
  final title = TextEditingController(text: initialTitle);
  final description = TextEditingController();
  final imageUrl = TextEditingController();
  final imageUrls = <String>[];
  var priority = MaintenancePriority.medium;
  String? error;
  var loading = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 10),
                const Text(
                  'Báo sự cố bảo trì',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gửi tiêu đề, mức độ và ảnh hiện trạng để chủ trọ nắm nhanh tình hình.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  enabled: !loading,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<MaintenancePriority>(
                  value: priority,
                  items: MaintenancePriority.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: loading
                      ? null
                      : (value) => setState(() => priority = value ?? priority),
                  decoration: const InputDecoration(labelText: 'Mức độ'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  enabled: !loading,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    hintText: 'Ví dụ: vòi nước rò, ổ điện chập chờn...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageUrl,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'Link ảnh/file bổ sung',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          try {
                            final uploaded = await _pickAndUploadFile(ref);
                            if (uploaded != null) {
                              setState(() {
                                imageUrls.add(uploaded);
                                imageUrl.text = uploaded;
                              });
                            }
                          } catch (err) {
                            setState(() => error = '$err');
                          }
                        },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    imageUrls.isEmpty
                        ? 'Upload ảnh/file'
                        : 'Đã upload ${imageUrls.length} file',
                  ),
                ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < imageUrls.length; i += 1)
                        Chip(
                          label: Text('File ${i + 1}'),
                          onDeleted: loading
                              ? null
                              : () => setState(() => imageUrls.removeAt(i)),
                        ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: _danger)),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            loading ? null : () => Navigator.pop(sheetContext),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                if (title.text.trim().isEmpty) {
                                  setState(
                                    () => error = 'Nhập tiêu đề sự cố.',
                                  );
                                  return;
                                }
                                setState(() {
                                  loading = true;
                                  error = null;
                                });
                                try {
                                  await ref
                                      .read(
                                    tenantMaintenanceControllerProvider
                                        .notifier,
                                  )
                                      .submit(
                                    title: title.text,
                                    description: description.text,
                                    priority: priority,
                                    imageUrls: [
                                      ...imageUrls,
                                      if (imageUrl.text.trim().isNotEmpty &&
                                          !imageUrls.contains(
                                            imageUrl.text.trim(),
                                          ))
                                        imageUrl.text.trim(),
                                    ],
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (err) {
                                  setState(() {
                                    loading = false;
                                    error = '$err';
                                  });
                                }
                              },
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Gửi yêu cầu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  title.dispose();
  description.dispose();
  imageUrl.dispose();
}

Future<void> _showMaintenanceDetailSheet(
  BuildContext context,
  WidgetRef ref,
  MaintenanceTicket ticket,
) async {
  final body = TextEditingController();
  final imageUrls = <String>[];
  String? error;
  var loading = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconBubble(
                      icon: ticket.status.icon,
                      color: ticket.status.color,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _StatusPill(
                                label: ticket.status.label,
                                color: ticket.status.color,
                              ),
                              _StatusPill(
                                label: ticket.priority.label,
                                color: ticket.priority.color,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailLine(
                  icon: Icons.meeting_room_rounded,
                  label: 'Phòng',
                  value: ticket.roomName ?? 'Chưa có thông tin phòng',
                ),
                if (ticket.reportedAt != null)
                  _DetailLine(
                    icon: Icons.event_rounded,
                    label: 'Ngày báo',
                    value: formatDate(ticket.reportedAt),
                  ),
                if (ticket.completedAt != null)
                  _DetailLine(
                    icon: Icons.task_alt_rounded,
                    label: 'Hoàn tất',
                    value: formatDate(ticket.completedAt),
                  ),
                if (ticket.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Mô tả',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ticket.description!.trim(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (ticket.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _AttachmentWrap(urls: ticket.imageUrls),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Trao đổi',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (ticket.comments.isEmpty)
                  const Text(
                    'Chưa có phản hồi nào cho yêu cầu này.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  for (final comment in ticket.comments) ...[
                    _CommentBlock(comment: comment),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 10),
                TextField(
                  controller: body,
                  enabled: !loading,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Phản hồi'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          try {
                            final uploaded = await _pickAndUploadFile(ref);
                            if (uploaded != null) {
                              setState(() => imageUrls.add(uploaded));
                            }
                          } catch (err) {
                            setState(() => error = '$err');
                          }
                        },
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(
                    imageUrls.isEmpty
                        ? 'Đính kèm ảnh/file'
                        : 'Đã đính kèm ${imageUrls.length} file',
                  ),
                ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < imageUrls.length; i += 1)
                        Chip(
                          label: Text('File ${i + 1}'),
                          onDeleted: loading
                              ? null
                              : () => setState(() => imageUrls.removeAt(i)),
                        ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: _danger)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            loading ? null : () => Navigator.pop(sheetContext),
                        child: const Text('Đóng'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                if (body.text.trim().isEmpty) {
                                  setState(
                                    () => error = 'Nhập nội dung phản hồi.',
                                  );
                                  return;
                                }
                                setState(() {
                                  loading = true;
                                  error = null;
                                });
                                try {
                                  await ref
                                      .read(
                                        tenantMaintenanceControllerProvider
                                            .notifier,
                                      )
                                      .comment(
                                        ticketId: ticket.id,
                                        body: body.text,
                                        imageUrls: imageUrls,
                                      );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (err) {
                                  setState(() {
                                    loading = false;
                                    error = '$err';
                                  });
                                }
                              },
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.reply_rounded),
                        label: const Text('Gửi phản hồi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  body.dispose();
}

class _CommentBlock extends StatelessWidget {
  const _CommentBlock({required this.comment});

  final MaintenanceComment comment;

  @override
  Widget build(BuildContext context) {
    final author = comment.authorName?.trim().isNotEmpty == true
        ? comment.authorName!.trim()
        : comment.authorRole;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$author · ${formatDate(comment.createdAt)}',
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            comment.body,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (comment.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _AttachmentWrap(urls: comment.imageUrls),
          ],
        ],
      ),
    );
  }
}

class _AttachmentWrap extends ConsumerWidget {
  const _AttachmentWrap({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < urls.length; i += 1)
          ActionChip(
            avatar: const Icon(Icons.attachment_rounded, size: 16),
            label: Text('File ${i + 1}'),
            onPressed: () async {
              try {
                final url =
                    await ref.read(uploadApiProvider).accessUrl(urls[i]);
                if (!await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication)) {
                  throw Exception('Không mở được file.');
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Không mở được file. Hãy thử lại hoặc kiểm tra quyền truy cập.')));
                }
              }
            },
          ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.color = _muted,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _line,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

Future<String?> _pickAndUploadFile(WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
      'pdf',
    ],
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  final url = await ref.read(uploadApiProvider).uploadFile(path);
  return url.isEmpty ? null : ApiConfig.resolveUrl(url);
}
