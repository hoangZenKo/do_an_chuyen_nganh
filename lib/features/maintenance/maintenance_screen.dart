import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../models/maintenance.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'maintenance_providers.dart';
import 'maintenance_assignment_dialog.dart';
import 'maintenance_attachments.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key, this.ticketId});

  final String? ticketId;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  MaintenanceStatus? _status;
  MaintenancePriority? _priority;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final canManageMaintenance =
        sessionHasPermission(session, 'maintenance.manage');
    final canCompleteMaintenance =
        sessionHasPermission(session, 'maintenance.complete');
    final ticketId = widget.ticketId;
    if (ticketId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sửa chữa')),
        body: ref.watch(maintenanceDetailProvider(ticketId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _CenteredError(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(maintenanceDetailProvider(ticketId)),
              ),
              data: (ticket) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(maintenanceDetailProvider(ticketId).future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _ticketCard(context, ref, ticket, canManageMaintenance,
                        canCompleteMaintenance),
                  ],
                ),
              ),
            ),
      );
    }
    final query = MaintenanceListQuery(status: _status, priority: _priority);
    final ticketsAsync = ref.watch(maintenanceListProvider(query));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sửa chữa'),
        actions: [
          if (canManageMaintenance)
            IconButton(
              tooltip: 'Báo sửa chữa',
              onPressed: () => context.push(maintenanceFormRoute),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary),
        ),
        error: (error, _) => _CenteredError(
          message: '$error',
          onRetry: () => ref.invalidate(maintenanceListProvider(query)),
        ),
        data: (result) {
          final items = _visibleItems(result.items);
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async =>
                ref.invalidate(maintenanceListProvider(query)),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _MaintenanceHeader(
                    summary: result.summary,
                    onAdd: canManageMaintenance
                        ? () => context.push(maintenanceFormRoute)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MaintenanceFilters(
                    search: _search,
                    status: _status,
                    priority: _priority,
                    onStatusChanged: (value) => setState(() => _status = value),
                    onPriorityChanged: (value) =>
                        setState(() => _priority = value),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyMaintenance(
                      onAdd: canManageMaintenance
                          ? () => context.push(maintenanceFormRoute)
                          : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ticketCard(
                        context,
                        ref,
                        items[index],
                        canManageMaintenance,
                        canCompleteMaintenance,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<MaintenanceTicket> _visibleItems(List<MaintenanceTicket> items) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((ticket) {
      final haystack = [
        ticket.title,
        ticket.description,
        ticket.propertyName,
        ticket.roomName,
        ticket.note,
        ticket.status.label,
        ticket.priority.label,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }
}

Widget _ticketCard(BuildContext context, WidgetRef ref,
    MaintenanceTicket ticket, bool canManage, bool canComplete) {
  return _MaintenanceCard(
    ticket: ticket,
    onAssign: canManage
        ? () => showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => MaintenanceAssignmentDialog(ticket: ticket))
        : null,
    onEdit: canManage
        ? () => context.push(maintenanceFormPath(ticketId: ticket.id))
        : null,
    onComment: canManage ? () => _showCommentDialog(context, ticket) : null,
    onStart: canManage
        ? () => _setStatus(context, ref, ticket, MaintenanceStatus.inProgress)
        : null,
    onComplete:
        canComplete ? () => _completeTicket(context, ref, ticket) : null,
    onCancel: canManage
        ? () => _setStatus(context, ref, ticket, MaintenanceStatus.cancelled)
        : null,
    onDelete: canManage ? () => _confirmDelete(context, ref, ticket) : null,
  );
}

class _MaintenanceHeader extends StatelessWidget {
  const _MaintenanceHeader({required this.summary, this.onAdd});

  final MaintenanceSummary summary;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Báo sửa chữa',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (onAdd != null)
                  IconButton.filled(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Báo sửa chữa',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Đang mở',
                    value: '${summary.openCount}',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryTile(
                    label: 'Đã xong',
                    value: '${summary.doneCount}',
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryTile(
                    label: 'Thực chi',
                    value: formatCurrencyVnd(summary.actualCost),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceFilters extends StatelessWidget {
  const _MaintenanceFilters({
    required this.search,
    required this.status,
    required this.priority,
    required this.onStatusChanged,
    required this.onPriorityChanged,
  });

  final TextEditingController search;
  final MaintenanceStatus? status;
  final MaintenancePriority? priority;
  final ValueChanged<MaintenanceStatus?> onStatusChanged;
  final ValueChanged<MaintenancePriority?> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Tìm theo tiêu đề, phòng, ghi chú',
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: status == null,
                  onTap: () => onStatusChanged(null),
                ),
                const SizedBox(width: 8),
                for (final item in MaintenanceStatus.values) ...[
                  _FilterChip(
                    label: item.label,
                    selected: status == item,
                    color: item.color,
                    onTap: () => onStatusChanged(item),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Mọi mức',
                  selected: priority == null,
                  onTap: () => onPriorityChanged(null),
                ),
                const SizedBox(width: 8),
                for (final item in MaintenancePriority.values) ...[
                  _FilterChip(
                    label: item.label,
                    selected: priority == item,
                    color: item.color,
                    onTap: () => onPriorityChanged(item),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.ticket,
    this.onEdit,
    this.onAssign,
    this.onComment,
    this.onStart,
    this.onComplete,
    this.onCancel,
    this.onDelete,
  });

  final MaintenanceTicket ticket;
  final VoidCallback? onEdit;
  final VoidCallback? onAssign;
  final VoidCallback? onComment;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ticket.status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ticket.status.icon, color: ticket.status.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(
                        label: ticket.status.label, color: ticket.status.color),
                    _Badge(
                      label: ticket.priority.label,
                      color: ticket.priority.color,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (ticket.roomName != null) 'Phòng ${ticket.roomName}',
                    if (ticket.propertyName != null) ticket.propertyName!,
                    formatDate(ticket.reportedAt),
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (ticket.description != null &&
                    ticket.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    ticket.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
                if (ticket.assigneeName != null || ticket.dueAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                      '${ticket.assigneeName ?? 'Chưa giao nhân viên'} · Hạn ${formatDate(ticket.dueAt?.toLocal())}${ticket.escalatedAt == null ? '' : ' · Đã báo quá SLA'}',
                      style: TextStyle(
                          color: ticket.escalatedAt == null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.error)),
                ],
                if (ticket.estimatedCost != null ||
                    ticket.actualCost != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (ticket.estimatedCost != null)
                        'Dự kiến ${formatCurrencyVnd(ticket.estimatedCost!)}',
                      if (ticket.actualCost != null)
                        'Thực tế ${formatCurrencyVnd(ticket.actualCost!)}',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
                if (ticket.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  MaintenanceAttachments(urls: ticket.imageUrls),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onEdit != null ||
              onComment != null ||
              onStart != null ||
              onComplete != null ||
              onCancel != null ||
              onDelete != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'start') onStart?.call();
                if (value == 'complete') onComplete?.call();
                if (value == 'edit') onEdit?.call();
                if (value == 'assign') onAssign?.call();
                if (value == 'comment') onComment?.call();
                if (value == 'cancel') onCancel?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onAssign != null)
                  const PopupMenuItem(
                      value: 'assign', child: Text('Giao việc / SLA')),
                if (ticket.status == MaintenanceStatus.open && onStart != null)
                  const PopupMenuItem(
                      value: 'start', child: Text('Đang xử lý')),
                if (!ticket.isDone &&
                    ticket.status != MaintenanceStatus.cancelled &&
                    onComplete != null)
                  const PopupMenuItem(
                      value: 'complete', child: Text('Hoàn tất')),
                if (onComment != null)
                  const PopupMenuItem(
                      value: 'comment', child: Text('Phản hồi')),
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                if (!ticket.isDone &&
                    ticket.status != MaintenanceStatus.cancelled &&
                    onCancel != null)
                  const PopupMenuItem(value: 'cancel', child: Text('Hủy')),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = _accentForeground(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: foreground),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _accentForeground(context, color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = color ?? colors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(active.withValues(alpha: 0.12), colors.surface)
              : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? active : colors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? _accentForeground(context, active)
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

Color _accentForeground(BuildContext context, Color color) {
  final colors = Theme.of(context).colorScheme;
  return Color.lerp(color, colors.onSurface,
      colors.brightness == Brightness.dark ? 0.30 : 0.45)!;
}

class _EmptyMaintenance extends StatelessWidget {
  const _EmptyMaintenance({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'Chưa có yêu cầu sửa chữa',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Ghi nhận hỏng hóc theo từng phòng và chốt chi phí khi hoàn tất.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (onAdd != null)
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Báo sửa chữa'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CenteredError extends StatelessWidget {
  const _CenteredError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

Future<void> _setStatus(
  BuildContext context,
  WidgetRef ref,
  MaintenanceTicket ticket,
  MaintenanceStatus status,
) async {
  try {
    await ref
        .read(maintenanceActionControllerProvider.notifier)
        .updateStatus(ticket.id, status);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chuyển sang "${status.label}".')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

Future<void> _showCommentDialog(
  BuildContext context,
  MaintenanceTicket ticket,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _MaintenanceCommentDialog(ticket: ticket),
  );
}

class _MaintenanceCommentDialog extends ConsumerStatefulWidget {
  const _MaintenanceCommentDialog({required this.ticket});

  final MaintenanceTicket ticket;

  @override
  ConsumerState<_MaintenanceCommentDialog> createState() =>
      _MaintenanceCommentDialogState();
}

class _MaintenanceCommentDialogState
    extends ConsumerState<_MaintenanceCommentDialog> {
  final body = TextEditingController();
  String? error;
  var loading = false;

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return AlertDialog(
      title: Text(ticket.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final comment in ticket.comments) ...[
              Text(
                '${comment.authorName ?? comment.authorRole} · ${formatDate(comment.createdAt)}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              Text(comment.body),
              if (comment.imageUrls.isNotEmpty)
                MaintenanceAttachments(urls: comment.imageUrls),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: body,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Phản hồi'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: loading
              ? null
              : () async {
                  if (body.text.trim().isEmpty) {
                    setState(() => error = 'Nhập nội dung phản hồi.');
                    return;
                  }
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  try {
                    await ref
                        .read(maintenanceActionControllerProvider.notifier)
                        .addComment(ticket.id, body: body.text);
                    if (context.mounted &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.pop(context);
                    }
                  } catch (err) {
                    if (!mounted) return;
                    setState(() {
                      loading = false;
                      error = '$err';
                    });
                  }
                },
          child: const Text('Gửi'),
        ),
      ],
    );
  }
}

Future<void> _completeTicket(
  BuildContext context,
  WidgetRef ref,
  MaintenanceTicket ticket,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CompleteMaintenanceDialog(ticket: ticket),
  );
}

class _CompleteMaintenanceDialog extends ConsumerStatefulWidget {
  const _CompleteMaintenanceDialog({required this.ticket});
  final MaintenanceTicket ticket;

  @override
  ConsumerState<_CompleteMaintenanceDialog> createState() =>
      _CompleteMaintenanceDialogState();
}

class _CompleteMaintenanceDialogState
    extends ConsumerState<_CompleteMaintenanceDialog> {
  late final amount = TextEditingController(
    text: (widget.ticket.actualCost ?? widget.ticket.estimatedCost ?? '')
        .toString(),
  );
  late final note = TextEditingController(text: widget.ticket.note ?? '');
  late var createExpense = widget.ticket.expenseId == null;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading) return;
    final text = amount.text.trim();
    final actualCost = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty &&
        (actualCost == null || actualCost < 0 || actualCost > 2147483647)) {
      setState(() => error = 'Chi phí phải từ 0 đến 2.147.483.647 đ.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(maintenanceActionControllerProvider.notifier).complete(
            widget.ticket.id,
            actualCost: actualCost,
            note: note.text,
            createExpense: createExpense,
          );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hoàn tất sửa chữa.')),
      );
      Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hoàn tất sửa chữa'),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amount,
            enabled: !loading && widget.ticket.expenseId == null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Chi phí thực tế'),
          ),
          TextField(
            controller: note,
            enabled: !loading,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          CheckboxListTile(
            value: createExpense,
            contentPadding: EdgeInsets.zero,
            onChanged: !loading && widget.ticket.expenseId == null
                ? (value) => setState(() => createExpense = value ?? true)
                : null,
            title: const Text('Tạo chi phí sửa chữa'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      )),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: loading ? null : _submit,
          child: Text(loading ? 'Đang lưu...' : 'Hoàn tất'),
        ),
      ],
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  MaintenanceTicket ticket,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xóa yêu cầu'),
      content: Text('Xóa yêu cầu "${ticket.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref
        .read(maintenanceActionControllerProvider.notifier)
        .delete(ticket.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa yêu cầu sửa chữa.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}
