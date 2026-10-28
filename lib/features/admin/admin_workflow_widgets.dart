import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_failure.dart';
import 'admin_overview_theme.dart';

import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_step_up.dart';
import 'admin_workspace_states.dart';

Map<String, dynamic> workflowData(Map<String, dynamic> response) =>
    Map<String, dynamic>.from(response['data'] as Map? ?? const {});
List<Map<String, dynamic>> workflowRows(Map<String, dynamic> response) =>
    (response['data'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
String workflowDate(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null
      ? '-'
      : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String workflowLabel(Object? value) =>
    const {
      'NOT_SUBMITTED': 'Chưa gửi hồ sơ',
      'NEEDS_INFO': 'Cần bổ sung',
      'OPEN': 'Mới',
      'IN_PROGRESS': 'Đang xử lý',
      'WAITING_FOR_USER': 'Chờ phản hồi',
      'RESOLVED': 'Đã giải quyết',
      'CLOSED': 'Đã đóng',
      'UPHELD': 'Giữ quyết định',
      'REOPENED': 'Mở kiểm duyệt lại',
      'SUPERSEDED': 'Đã được thay thế',
      'LOW': 'Thấp',
      'NORMAL': 'Bình thường',
      'HIGH': 'Cao',
      'URGENT': 'Khẩn cấp',
      'PENDING': 'Đang chờ',
      'COMPLETED': 'Hoàn tất',
      'FAILED': 'Thất bại',
      'CANCELLED': 'Đã hủy',
      'EXPIRED': 'Hết hạn',
      'DAILY': 'Hằng ngày',
      'WEEKLY': 'Hằng tuần',
      'MONTHLY': 'Hằng tháng',
      'MONTHLY_FINANCE': 'Tài chính 30 ngày',
      'MODERATION': 'Kiểm duyệt 30 ngày',
      'SUPPORT_SLA': 'SLA hỗ trợ',
      'UNMATCHED': 'Chưa đối soát',
      'MATCHED': 'Đã khớp',
      'NEEDS_REVIEW': 'Cần kiểm tra',
      'DEAD': 'Dead letter',
      'ACCOUNT': 'Tài khoản',
      'PROPERTY': 'Khu trọ',
      'ROOM': 'Phòng',
      'TENANT': 'Người thuê',
      'LEASE': 'Hợp đồng',
      'INVOICE': 'Hóa đơn',
      'PAYMENT': 'Thanh toán',
      'SUPPORT_TICKET': 'Ticket hỗ trợ',
      'LISTING': 'Tin đăng',
      'REPORT': 'Báo cáo vi phạm',
      'REVIEW': 'Đánh giá',
      'REPLY': 'Phản hồi',
      'DRAFT': 'Bản nháp',
      'ACTIVE': 'Đang hoạt động',
      'RETIRED': 'Ngừng áp dụng',
    }[value] ??
    '$value';

class WorkflowField {
  const WorkflowField(this.key, this.label,
      {this.initial = '',
      this.choices,
      this.minLength = 1,
      this.maxLength = 5000,
      this.lines = 1});
  final String key, label, initial;
  final Map<String, String>? choices;
  final int minLength, maxLength, lines;
}

abstract class WorkflowState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  late final String? workflowOwner;
  bool busy = false;
  String? failure;
  @override
  void initState() {
    super.initState();
    workflowOwner = ref.read(sessionIdentityProvider);
  }

  bool get active =>
      mounted &&
      workflowOwner != null &&
      ref.read(sessionIdentityProvider) == workflowOwner;
  bool can(String permission) =>
      ref.read(adminCapabilitiesProvider).valueOrNull?.has(permission) ?? false;

  Future<Map<String, dynamic>?> command(
      String path, Map<String, dynamic> payload,
      {bool patch = false}) async {
    if (!active || busy) return null;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final result = await ref.read(adminApiProvider).authorizedCommand(
          path, payload,
          patch: patch, prompt: () => promptAdminStepUp(context, () => active));
      if (!active) return null;
      ref.invalidate(adminResourceProvider);
      ref.invalidate(adminWorkspaceResourceProvider);
      return result;
    } catch (error) {
      if (active) {
        if (error is ApiFailure &&
            (error.statusCode == 409 || error.statusCode == 403)) {
          ref.invalidate(adminResourceProvider);
          ref.invalidate(adminWorkspaceResourceProvider);
          if (error.statusCode == 403) {
            ref.invalidate(adminCapabilitiesProvider);
          }
        }
        setState(() => failure = '$error');
      }
      return null;
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<Map<String, String>?> form(
      String title, List<WorkflowField> fields) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _WorkflowDialog(title: title, fields: fields),
    );
    return active ? result : null;
  }

  Widget resource(AdminRequest request,
          Widget Function(Map<String, dynamic>) builder) =>
      WorkflowResource(
          key: ValueKey(request), request: request, builder: builder);
  List<Widget> get operationState => [
        if (busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ),
        if (failure != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AdminOverviewTheme.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AdminOverviewTheme.red.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: AdminOverviewTheme.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ];
}

const workflowReason = WorkflowField('reason', 'Lý do (ghi vào audit)',
    minLength: 10, maxLength: 1000, lines: 2);

class _WorkflowDialog extends StatefulWidget {
  const _WorkflowDialog({required this.title, required this.fields});
  final String title;
  final List<WorkflowField> fields;
  @override
  State<_WorkflowDialog> createState() => _WorkflowDialogState();
}

class _WorkflowDialogState extends State<_WorkflowDialog> {
  final formKey = GlobalKey<FormState>();
  late final controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initial)
  };
  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AdminOverviewTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminOverviewTheme.line),
        ),
        title: Text(widget.title),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Form(
                    key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final field in widget.fields)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: field.choices == null
                                ? TextFormField(
                                    controller: controllers[field.key],
                                    minLines: field.lines,
                                    maxLines: field.lines + 2,
                                    maxLength: field.maxLength,
                                    decoration:
                                        InputDecoration(labelText: field.label),
                                    validator: (value) =>
                                        (value?.trim().length ?? 0) < field.minLength
                                            ? 'Nhập ít nhất ${field.minLength} ký tự.'
                                            : null)
                                : DropdownButtonFormField<String>(
                                    value:
                                        field.choices!.containsKey(field.initial)
                                            ? field.initial
                                            : field.choices!.keys.first,
                                    isExpanded: true,
                                    decoration:
                                        InputDecoration(labelText: field.label),
                                    items: field.choices!.entries
                                        .map((entry) => DropdownMenuItem(
                                            value: entry.key,
                                            child: Text(entry.value,
                                                overflow: TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: (_) {},
                                    onSaved: (value) => controllers[field.key]!.text = value ?? '')),
                    ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(
                      context,
                      controllers.map(
                          (key, value) => MapEntry(key, value.text.trim())));
                }
              },
              child: const Text('Xác nhận'))
        ],
      );
}

class WorkflowResource extends ConsumerWidget {
  const WorkflowResource(
      {super.key, required this.request, required this.builder});
  final AdminRequest request;
  final Widget Function(Map<String, dynamic>) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(adminWorkspaceResourceProvider(request)).when(
            skipLoadingOnRefresh: false,
            loading: () => const AdminLoadingState(),
            error: (error, _) => AdminFailureState(
                error: error,
                retry: () {
                  ref.invalidate(adminResourceProvider(request));
                  ref.invalidate(adminWorkspaceResourceProvider(request));
                }),
            data: builder,
          );
}

class WorkflowEmpty extends StatelessWidget {
  const WorkflowEmpty(this.message,
      {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminOverviewTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminOverviewTheme.line),
          ),
          child: Icon(icon, size: 20, color: AdminOverviewTheme.muted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AdminOverviewTheme.muted),
          ),
        )
      ]));
}

class WorkflowPager extends StatelessWidget {
  const WorkflowPager(
      {super.key,
      required this.page,
      required this.total,
      required this.limit,
      required this.onPage});
  final int page, total, limit;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AdminOverviewTheme.background.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminOverviewTheme.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                tooltip: 'Trang trước',
                visualDensity: VisualDensity.compact,
                onPressed: page > 1 ? () => onPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Trang $page · $total kết quả',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            IconButton(
                tooltip: 'Trang sau',
                visualDensity: VisualDensity.compact,
                onPressed: page * limit < total ? () => onPage(page + 1) : null,
                icon: const Icon(Icons.chevron_right))
          ],
        ),
      );
}

Color workflowStatusColor(Object? raw) {
  final key = '${raw ?? ''}'.trim().toUpperCase();
  return switch (key) {
    'ACTIVE' ||
    'RESOLVED' ||
    'COMPLETED' ||
    'MATCHED' ||
    'OK' ||
    'HEALTHY' ||
    'UPHELD' ||
    'APPROVED' ||
    'READY' ||
    'ENABLED' ||
    'TRUE' =>
      AdminOverviewTheme.green,
    'IN_PROGRESS' ||
    'WAITING_FOR_USER' ||
    'PENDING' ||
    'HIGH' ||
    'NEEDS_REVIEW' ||
    'WARNING' ||
    'DRAFT' ||
    'REOPENED' ||
    'SNOOZED' ||
    'ESCALATED' ||
    'DEGRADED' =>
      AdminOverviewTheme.amber,
    'URGENT' ||
    'CRITICAL' ||
    'FAILED' ||
    'DEAD' ||
    'UNMATCHED' ||
    'REJECTED' ||
    'LOCKED' ||
    'SUSPENDED' ||
    'OVERDUE' ||
    'EXPIRED' ||
    'ERROR' ||
    'BREACHED' =>
      AdminOverviewTheme.red,
    'CLOSED' ||
    'CANCELLED' ||
    'RETIRED' ||
    'SUPERSEDED' ||
    'LOW' ||
    'DISABLED' ||
    'INACTIVE' ||
    'FALSE' =>
      AdminOverviewTheme.muted,
    _ => AdminOverviewTheme.blue,
  };
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({
    super.key,
    required this.label,
    this.statusKey,
    this.color,
    this.icon,
    this.showDot = true,
  });

  factory AdminStatusBadge.fromStatus(
    Object? status, {
    Key? key,
    IconData? icon,
    bool showDot = true,
  }) =>
      AdminStatusBadge(
        key: key,
        label: workflowLabel(status),
        statusKey: status,
        icon: icon,
        showDot: showDot,
      );

  final String label;
  final Object? statusKey;
  final Color? color;
  final IconData? icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? workflowStatusColor(statusKey ?? label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone),
            const SizedBox(width: 5),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionPanel extends StatelessWidget {
  const AdminSectionPanel({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.actions = const [],
    this.child,
    this.children = const [],
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.elevated = false,
    this.accentColor,
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> actions;
  final Widget? child;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool elevated;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null ||
        subtitle != null ||
        trailing != null ||
        actions.isNotEmpty;
    final borderColor = accentColor != null
        ? accentColor!.withValues(alpha: 0.45)
        : AdminOverviewTheme.line;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: elevated
            ? AdminOverviewTheme.background
            : AdminOverviewTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (accentColor ?? AdminOverviewTheme.blue)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (accentColor ?? AdminOverviewTheme.blue)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: accentColor ?? AdminOverviewTheme.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AdminOverviewTheme.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (trailing != null || actions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (trailing != null) trailing!,
                      ...actions,
                    ],
                  ),
              ],
            ),
            if (child != null || children.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
          ],
          if (child != null) child!,
          ...children,
        ],
      ),
    );
  }
}

class AdminToolbarPanel extends StatelessWidget {
  const AdminToolbarPanel({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: AdminOverviewTheme.background.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminOverviewTheme.line),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.tone,
    this.badge,
    this.onTap,
    this.width,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? tone;
  final Widget? badge;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AdminOverviewTheme.blue;
    final card = Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdminOverviewTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminOverviewTheme.muted,
                  ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: card,
    );
  }
}

class AdminRecordCard extends StatelessWidget {
  const AdminRecordCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingColor,
    this.badges = const [],
    this.metadata = const [],
    this.body,
    this.trailing,
    this.actions = const [],
    this.selected = false,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final Widget title;
  final Widget? subtitle;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final List<Widget> badges;
  final List<Widget> metadata;
  final Widget? body;
  final Widget? trailing;
  final List<Widget> actions;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final tone = leadingColor ?? AdminOverviewTheme.blue;
    final borderColor = selected
        ? AdminOverviewTheme.blue.withValues(alpha: 0.65)
        : AdminOverviewTheme.line;
    final bgColor =
        selected ? AdminOverviewTheme.background : AdminOverviewTheme.surface;

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tone.withValues(alpha: 0.3)),
                  ),
                  child: Icon(leadingIcon, size: 18, color: tone),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DefaultTextStyle.merge(
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          child: title,
                        ),
                        ...badges,
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AdminOverviewTheme.muted, height: 1.4),
                        child: subtitle!,
                      ),
                    ],
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: metadata,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            body!,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class AdminKeyValueGrid extends StatelessWidget {
  const AdminKeyValueGrid({
    super.key,
    required this.entries,
    this.itemWidth = 220,
  });

  final Map<String, String> entries;
  final double itemWidth;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final entry in entries.entries)
            Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AdminOverviewTheme.background.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminOverviewTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AdminOverviewTheme.muted,
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    entry.value.isEmpty ? '-' : entry.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}

class AdminMetaChip extends StatelessWidget {
  const AdminMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AdminOverviewTheme.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: tone),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tone,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
