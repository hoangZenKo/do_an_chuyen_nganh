import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_navigation.dart';
import 'admin_workspace_states.dart';

class AdminWorkspaceActionQueue extends ConsumerStatefulWidget {
  const AdminWorkspaceActionQueue({super.key});
  @override
  ConsumerState<AdminWorkspaceActionQueue> createState() =>
      _AdminWorkspaceActionQueueState();
}

class _AdminWorkspaceActionQueueState
    extends ConsumerState<AdminWorkspaceActionQueue> {
  bool _showAll = false;
  String _sort = 'priority';

  void _retry() {
    ref.invalidate(adminResourceProvider(adminWorkspaceSummaryRequest));
    ref.invalidate(
        adminWorkspaceResourceProvider(adminWorkspaceSummaryRequest));
    ref.invalidate(adminWorkspaceSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final rightsState = ref.watch(adminCapabilitiesProvider);
    if (rightsState.isLoading || rightsState.valueOrNull == null) {
      return const AdminLoadingState();
    }
    final rights = rightsState.requireValue;
    return ref.watch(adminWorkspaceSummaryProvider).when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const AdminLoadingState(),
        error: (error, _) => AdminFailureState(error: error, retry: _retry),
        data: (summary) {
          final items = summary.items
              .where((item) =>
                  item.key != 'notifications' &&
                  rights.has(item.permission) &&
                  (adminDestinationFor(item.route)?.allowed(rights) ?? false) &&
                  (_showAll || !item.available || (item.count ?? 0) > 0))
              .toList();
          items.sort((left, right) => _sort == 'count'
              ? (right.count ?? -1).compareTo(left.count ?? -1)
              : left.priority.compareTo(right.priority));
          final stale = summary.updatedAt == null ||
              DateTime.now().difference(summary.updatedAt!).inMinutes >= 2;
          final updatedAt = summary.updatedAt?.toLocal();
          final updated = updatedAt == null
              ? 'Chưa có thời gian cập nhật'
              : 'Cập nhật ${updatedAt.day}/${updatedAt.month}/${updatedAt.year} '
                  '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
          return AdminSectionPanel(
              icon: Icons.bolt_outlined,
              title: 'Hàng đợi điều hành',
              subtitle:
                  'Các nhóm công việc trong phạm vi quyền của bạn. Chọn một nhóm để mở màn hình xử lý.',
              children: [
                AdminToolbarPanel(
                  margin: const EdgeInsets.only(bottom: 14),
                  children: [
                    FilterChip(
                        label: const Text('Hiện cả nhóm không tồn đọng'),
                        selected: _showAll,
                        onSelected: (value) =>
                            setState(() => _showAll = value)),
                    SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                            value: _sort,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Sắp xếp', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'priority',
                                  child: Text('Mức độ ưu tiên')),
                              DropdownMenuItem(
                                  value: 'count',
                                  child: Text('Số lượng tồn đọng'))
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sort = value);
                              }
                            })),
                  ],
                ),
                if (summary.partial)
                  Semantics(
                      liveRegion: true,
                      child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.amber
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AdminOverviewTheme.amber
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off_outlined,
                                    color: AdminOverviewTheme.amber, size: 18),
                                const Text(
                                    'Một số nguồn chưa sẵn sàng. Không coi số chưa tải được là 0.'),
                                TextButton(
                                    onPressed: _retry,
                                    child: const Text('Tải lại các nguồn')),
                              ]))),
                if (items.isEmpty)
                  Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminOverviewTheme.background
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminOverviewTheme.line),
                      ),
                      child: Row(children: [
                        Icon(
                          summary.partial
                              ? Icons.info_outline
                              : Icons.check_circle_outline,
                          color: summary.partial
                              ? AdminOverviewTheme.amber
                              : AdminOverviewTheme.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(summary.partial
                                ? 'Chưa có công việc từ các nguồn đã tải. Vẫn còn nguồn cần kiểm tra.'
                                : 'Không có việc tồn đọng cần xử lý ngay.'))
                      ])),
                for (final item in items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color:
                          AdminOverviewTheme.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !item.available || item.priority == 0
                            ? AdminOverviewTheme.red.withValues(alpha: 0.45)
                            : AdminOverviewTheme.line,
                      ),
                    ),
                    child: ListTile(
                      key: ValueKey('admin-action-${item.key}'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: (!item.available || item.priority == 0
                                  ? AdminOverviewTheme.red
                                  : AdminOverviewTheme.blue)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _icon(item.key),
                          size: 20,
                          color: !item.available || item.priority == 0
                              ? Theme.of(context).colorScheme.error
                              : AdminOverviewTheme.blue,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          !item.available
                              ? 'Chưa tải được số liệu; mở để kiểm tra.'
                              : '${item.count} mục${item.priority == 0 ? ' · Cần tiếp nhận trước' : ''}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: !item.available || item.priority == 0
                                ? AdminOverviewTheme.red
                                : AdminOverviewTheme.muted,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          GoRouter.maybeOf(context)?.go(item.destination),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: 14,
                            color: AdminOverviewTheme.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              updated,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AdminOverviewTheme.muted),
                            ),
                          ),
                        ],
                      ),
                      if (stale)
                        TextButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.update, size: 16),
                            label:
                                const Text('Dữ liệu có thể đã cũ · Làm mới')),
                    ]),
              ]);
        });
  }

  IconData _icon(String key) => switch (key) {
        'incidents' => Icons.warning_amber_outlined,
        'support_overdue' => Icons.support_agent_outlined,
        'support_due_soon' => Icons.schedule_outlined,
        'moderation' => Icons.fact_check_outlined,
        'notification_delivery' => Icons.notifications_off_outlined,
        'reports' => Icons.description_outlined,
        'finance' => Icons.account_balance_outlined,
        _ => Icons.pending_actions,
      };
}
