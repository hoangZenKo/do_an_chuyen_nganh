import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_notification_queue.dart';
import 'admin_step_up.dart';
import 'admin_workflow_widgets.dart';
import 'admin_inbox_filters.dart';
import 'admin_delivery_jobs_panel.dart';

String _time(Object? raw) {
  final date = DateTime.tryParse('$raw')?.toLocal();
  return date == null
      ? 'Chưa ghi nhận'
      : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Future<String?> _reason(BuildContext context, String title) {
  return showDialog<String>(
      context: context, builder: (_) => _ReasonDialog(title: title));
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});
  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _input = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
          key: _form,
          child: TextFormField(
              controller: _input,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Lý do (tối thiểu 10 ký tự)'),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Nhập lý do rõ ràng để lưu nhật ký.'
                  : null)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, _input.text.trim());
              }
            },
            child: const Text('Xác nhận'))
      ],
    );
  }
}

class _ResourceError extends StatelessWidget {
  const _ResourceError(this.error, this.retry);
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Không tải được dữ liệu: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại')),
      ]);
}

class AdminOperationsPanel extends ConsumerStatefulWidget {
  const AdminOperationsPanel({super.key, this.initialFilters = const {}});
  final Map<String, String> initialFilters;
  @override
  ConsumerState<AdminOperationsPanel> createState() =>
      _AdminOperationsPanelState();
}

class _AdminOperationsPanelState extends ConsumerState<AdminOperationsPanel> {
  static const _request = AdminRequest('/admin/operations/health');
  late final String? _owner;
  bool _busy = false;
  String? _error;
  String _incidentStatus = 'all';
  String _incidentSeverity = 'all';
  String _incidentAssignment = 'all';
  String _incidentWindow = 'all';
  String _incidentSearch = '';
  int _incidentPage = 1;
  AdminRequest get _incidentsRequest => AdminRequest(
        '/admin/operations/incidents',
        {
          'page': _incidentPage,
          'limit': 50,
          if (_incidentStatus != 'all') 'status': _incidentStatus,
          if (_incidentSeverity != 'all') 'severity': _incidentSeverity,
          if (_incidentAssignment != 'all') 'assignment': _incidentAssignment,
          if (_incidentWindow != 'all') 'window': _incidentWindow,
          if (_incidentSearch.trim().isNotEmpty)
            'search': _incidentSearch.trim(),
        },
      );
  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _applyFilters();
  }

  void _applyFilters() {
    final filters = adminInboxFilters(widget.initialFilters, incidents: true);
    _incidentStatus = filters['status'] ?? 'all';
    _incidentSeverity = filters['severity'] ?? 'all';
    _incidentAssignment = filters['assignment'] ?? 'all';
    _incidentWindow = filters['window'] ?? 'all';
    _incidentSearch = filters['search'] ?? '';
    _incidentPage = 1;
  }

  @override
  void didUpdateWidget(covariant AdminOperationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Uri(queryParameters: oldWidget.initialFilters).query !=
        Uri(queryParameters: widget.initialFilters).query) {
      _applyFilters();
    }
  }

  Future<void> _acknowledge(Map incident) async {
    final reason = await _reason(context, 'Tiếp nhận sự cố');
    if (!_active || reason == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider).authorizedCommand(
          '/admin/operations/incidents/${incident['id']}/actions',
          {
            'action': 'ACKNOWLEDGE',
            'version': incident['version'],
            'reason': reason,
          },
          prompt: () => promptAdminStepUp(context, () => _active));
      if (_active) refreshAdminWorkspace(ref);
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _incidentAction(Map incident, String action) async {
    if (!_active || _busy) return;
    final reason = await _reason(
        context,
        switch (action) {
          'ASSIGN' => 'Phân công sự cố',
          'SNOOZE' => 'Tạm hoãn sự cố',
          'RESOLVE' => 'Đóng sự cố',
          'REOPEN' => 'Mở lại sự cố',
          _ => 'Cập nhật sự cố',
        });
    if (!_active || reason == null) return;
    final payload = <String, dynamic>{
      'action': action,
      'version': incident['version'],
      'reason': reason,
    };
    if (action == 'SNOOZE') {
      final until = DateTime.now().add(const Duration(hours: 4));
      payload['snoozedUntil'] = until.toUtc().toIso8601String();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == 'ASSIGN') {
        final response = await ref
            .read(adminApiProvider)
            .resource('/admin/operations/incidents/assignees');
        if (!mounted || !_active) return;
        final agents = (response['data'] as List? ?? []).whereType<Map>();
        if (agents.isEmpty) {
          throw StateError('Chưa có admin đủ quyền vận hành.');
        }
        final owner = await showDialog<String>(
            context: context,
            builder: (_) => SimpleDialog(
                  title: const Text('Chọn người phụ trách'),
                  children: [
                    for (final agent in agents)
                      SimpleDialogOption(
                        onPressed: () =>
                            Navigator.pop(context, '${agent['id']}'),
                        child: Text('${agent['fullName']}'),
                      )
                  ],
                ));
        if (!_active || owner == null) return;
        payload['ownerId'] = owner;
      }
      await ref.read(adminApiProvider).authorizedCommand(
          '/admin/operations/incidents/${incident['id']}/actions', payload,
          prompt: () => promptAdminStepUp(context, () => _active));
      if (_active) refreshAdminWorkspace(ref);
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _incidentDetail(Map incident) async {
    if (!_active || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(adminApiProvider)
          .resource('/admin/operations/incidents/${incident['id']}');
      if (!mounted || !_active) return;
      final data = response['data'] as Map;
      await showDialog<void>(
          context: context,
          builder: (_) => Consumer(
                builder: (dialogContext, dialogRef, child) {
                  final visible =
                      dialogRef.watch(sessionIdentityProvider) == _owner &&
                          dialogRef
                                  .watch(adminCapabilitiesProvider)
                                  .valueOrNull
                                  ?.has('admin.operations.view') ==
                              true;
                  return AlertDialog(
                    title: Text(visible
                        ? '${data['title']}'
                        : 'Quyền truy cập đã thay đổi'),
                    content: visible
                        ? SizedBox(
                            width: 640,
                            child: SingleChildScrollView(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Runbook: ${data['runbook']}'),
                                if (data['runbookPath'] != null)
                                  SelectableText('${data['runbookPath']}'),
                                const SizedBox(height: 16),
                                Text(
                                    'Người phụ trách: ${data['ownerId'] ?? 'Chưa phân công'}'),
                                Text(
                                    'Điều kiện lỗi: ${data['conditionActive'] == true ? 'Đang tồn tại' : 'Đã phục hồi'}'),
                                if (data['snoozedUntil'] != null)
                                  Text(
                                      'Tạm hoãn đến ${_time(data['snoozedUntil'])}'),
                                if (data['resolutionNote'] != null)
                                  Text('Kết quả: ${data['resolutionNote']}'),
                                const Divider(height: 24),
                                for (final event
                                    in (data['history'] as List? ?? [])
                                        .whereType<Map>())
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                        '${_time(event['createdAt'])} · ${event['action']}\n${event['summary']}'),
                                  ),
                              ],
                            )))
                        : const Text('Đóng hộp thoại và tải lại màn hình.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Đóng'))
                    ],
                  );
                },
              ));
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Widget _metric(String label, String value, {IconData? icon, Color? tone}) =>
      AdminMetricCard(
        width: 210,
        label: label,
        value: value,
        icon: icon,
        tone: tone,
      );

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionIdentityProvider) != _owner || _owner == null) {
      return const Text('Phiên đăng nhập đã thay đổi.');
    }
    final capabilities = ref.watch(adminCapabilitiesProvider).valueOrNull;
    if (capabilities?.has('admin.operations.view') != true) {
      return const Text('Bạn không có quyền xem vận hành hệ thống.');
    }
    return ref.watch(adminWorkspaceResourceProvider(_request)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _ResourceError(error, () => refreshAdminWorkspace(ref)),
          data: (response) {
            final data = response['data'] as Map;
            final metrics = data['metrics'] as Map? ?? {};
            final workers = (data['workers'] as List? ?? []).whereType<Map>();
            final deliveries =
                (data['deliveries'] as List? ?? []).whereType<Map>();
            final errorRate = ((metrics['errorRate'] as num? ?? 0) * 100);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminSectionPanel(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Vận hành hệ thống',
                    subtitle:
                        'Chỉ số trong 15 phút gần nhất · Cập nhật ${_time(data['generatedAt'])}',
                    children: [
                      Text(
                        'Dùng nút Làm mới để cập nhật. Đây không thay thế giám sát uptime bên ngoài.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AdminOverviewTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      if (data['releaseGate'] is Map) ...[
                        Text(
                            'Release gate: ${(data['releaseGate'] as Map)['status']} · chưa nghiệm thu production',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        for (final blocker in ((data['releaseGate']
                                as Map)['blockers'] as List? ??
                            []))
                          Text('• $blocker'),
                        const Text(
                            'Cần bằng chứng staging, restore, MFA thật, provider delivery, recovery/alert và device QA; cấu hình đúng không đồng nghĩa đã nghiệm thu.'),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (data['readiness'] is Map)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AdminOverviewTheme.background
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AdminOverviewTheme.line),
                              ),
                              child: Text(
                                  'Readiness schema: ${(data['readiness'] as Map)['status'] == 'UNAVAILABLE' ? 'không kiểm tra được' : (data['readiness'] as Map)['ready'] == true ? 'sẵn sàng' : 'chưa sẵn sàng'} · migration thiếu/drift: ${((data['readiness'] as Map)['missing'] as List? ?? []).length}/${((data['readiness'] as Map)['drifted'] as List? ?? []).length}'),
                            ),
                          if (data['backup'] is Map)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AdminOverviewTheme.background
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AdminOverviewTheme.line),
                              ),
                              child: Text(
                                  'Backup age: ${(data['backup'] as Map)['ageMinutes'] == null ? 'chưa có telemetry tin cậy' : '${(data['backup'] as Map)['ageMinutes']} phút'} · ${(data['backup'] as Map)['status']} · restore cần nghiệm thu riêng'),
                            ),
                        ],
                      ),
                      if (data['queues'] is Map) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AdminOverviewTheme.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Báo cáo đã lên lịch: ${(((data['queues'] as Map)['reports'] as List?) ?? []).whereType<Map>().map((row) => '${workflowLabel(row['status'])}: ${row['total']}').join(' · ')}'),
                              const SizedBox(height: 4),
                              Text(
                                'Báo cáo lỗi: mở Lịch báo cáo để xử lý run thuộc sở hữu và quyền dữ liệu của bạn; quyền operations không cấp quyền tải báo cáo của người khác.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AdminOverviewTheme.muted),
                              ),
                              if (capabilities?.has('admin.reports.manage') ==
                                  true)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                        onPressed: () => context
                                            .go('/admin/report-schedules'),
                                        icon: const Icon(
                                            Icons.summarize_outlined),
                                        label: const Text(
                                            'Mở lịch báo cáo của tôi'))),
                            ],
                          ),
                        ),
                      ],
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ),
                      const SizedBox(height: 18),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        _metric(
                          'Yêu cầu API',
                          '${metrics['requests'] ?? 0}',
                          icon: Icons.api_outlined,
                          tone: AdminOverviewTheme.blue,
                        ),
                        _metric(
                          'Tỷ lệ lỗi máy chủ',
                          '${errorRate.toStringAsFixed(1)}%',
                          icon: Icons.error_outline,
                          tone: errorRate > 1
                              ? AdminOverviewTheme.red
                              : AdminOverviewTheme.green,
                        ),
                        _metric(
                          'Thời gian trung bình',
                          '${metrics['averageDurationMs'] ?? 0} ms',
                          icon: Icons.speed_outlined,
                          tone: AdminOverviewTheme.blue,
                        ),
                        _metric(
                          'Đăng nhập / MFA lỗi',
                          '${metrics['loginFailures'] ?? 0} / ${metrics['mfaFailures'] ?? 0}',
                          icon: Icons.security_outlined,
                          tone: AdminOverviewTheme.amber,
                        ),
                        _metric(
                          'Kiểm duyệt quá hạn',
                          '${data['moderationOverdue'] ?? 0}',
                          icon: Icons.fact_check_outlined,
                          tone: ((data['moderationOverdue'] as num? ?? 0) > 0)
                              ? AdminOverviewTheme.amber
                              : AdminOverviewTheme.green,
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionPanel(
                    icon: Icons.hub_outlined,
                    title: 'Worker và kênh gửi',
                    children: [
                      for (final worker in workers)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AdminOverviewTheme.line),
                          ),
                          child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              leading: Icon(
                                worker['status'] == 'OK'
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_outlined,
                                color: worker['status'] == 'OK'
                                    ? AdminOverviewTheme.green
                                    : AdminOverviewTheme.amber,
                              ),
                              title: Text(
                                '${worker['name']} · ${worker['status']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                  'Chạy cuối: ${_time(worker['lastRunAt'])}')),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AdminOverviewTheme.background
                                  .withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AdminOverviewTheme.line),
                            ),
                            child: Text(
                                'Email tài khoản: ${data['accountDeliveryConfigured'] == true ? 'đã cấu hình' : 'chưa cấu hình'}'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AdminOverviewTheme.background
                                  .withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AdminOverviewTheme.line),
                            ),
                            child: Text(
                                'Webhook cảnh báo: ${data['alertDeliveryConfigured'] == true ? 'đã cấu hình' : 'chưa cấu hình'}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 8, children: [
                        for (final delivery in deliveries)
                          Chip(
                              label: Text(
                                  '${delivery['status']}: ${delivery['total']}')),
                      ]),
                      const AdminDeliveryJobsPanel(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionPanel(
                    icon: Icons.warning_amber_outlined,
                    accentColor: AdminOverviewTheme.amber,
                    title: 'Sự cố và lịch sử phục hồi',
                    children: [
                      AdminToolbarPanel(
                        children: [
                          SizedBox(
                              width: 210,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _incidentStatus,
                                onChanged: (value) => setState(() {
                                  _incidentStatus = value ?? 'all';
                                  _incidentPage = 1;
                                }),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Mọi trạng thái')),
                                  DropdownMenuItem(
                                      value: 'OPEN', child: Text('Mở')),
                                  DropdownMenuItem(
                                      value: 'ACKNOWLEDGED',
                                      child: Text('Đã tiếp nhận')),
                                  DropdownMenuItem(
                                      value: 'SNOOZED',
                                      child: Text('Tạm hoãn')),
                                  DropdownMenuItem(
                                      value: 'RESOLVED',
                                      child: Text('Đã đóng')),
                                ],
                              )),
                          SizedBox(
                              width: 210,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _incidentSeverity,
                                onChanged: (value) => setState(() {
                                  _incidentSeverity = value ?? 'all';
                                  _incidentPage = 1;
                                }),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all', child: Text('Mọi mức độ')),
                                  DropdownMenuItem(
                                      value: 'CRITICAL',
                                      child: Text('Nghiêm trọng')),
                                  DropdownMenuItem(
                                      value: 'WARNING',
                                      child: Text('Cảnh báo')),
                                ],
                              )),
                          SizedBox(
                              width: 210,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _incidentAssignment,
                                onChanged: (value) => setState(() {
                                  _incidentAssignment = value ?? 'all';
                                  _incidentPage = 1;
                                }),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Mọi người phụ trách')),
                                  DropdownMenuItem(
                                      value: 'mine', child: Text('Của tôi')),
                                  DropdownMenuItem(
                                      value: 'unassigned',
                                      child: Text('Chưa phân công')),
                                ],
                              )),
                          SizedBox(
                              width: 210,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _incidentWindow,
                                onChanged: (value) => setState(() {
                                  _incidentWindow = value ?? 'all';
                                  _incidentPage = 1;
                                }),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Mọi thời gian')),
                                  DropdownMenuItem(
                                      value: '24h', child: Text('24 giờ')),
                                  DropdownMenuItem(
                                      value: '7d', child: Text('7 ngày')),
                                  DropdownMenuItem(
                                      value: '30d', child: Text('30 ngày')),
                                ],
                              )),
                          SizedBox(
                            width: 240,
                            child: TextFormField(
                              key: ValueKey(widget.initialFilters.toString()),
                              initialValue: _incidentSearch,
                              maxLength: 100,
                              textInputAction: TextInputAction.search,
                              onFieldSubmitted: (value) => setState(() {
                                _incidentSearch = value;
                                _incidentPage = 1;
                              }),
                              decoration: const InputDecoration(
                                isDense: true,
                                counterText: '',
                                labelText: 'Tìm sự cố',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final query = Map<String, dynamic>.from(
                                  _incidentsRequest.query)
                                ..remove('page')
                                ..remove('limit');
                              await Clipboard.setData(ClipboardData(
                                  text: Uri(
                                path: '/admin/operations',
                                queryParameters: query.map(
                                    (key, value) => MapEntry(key, '$value')),
                              ).toString()));
                              if (!context.mounted || !_active) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Đã sao chép đường dẫn bộ lọc.')));
                            },
                            icon: const Icon(Icons.link),
                            label: const Text('Sao chép bộ lọc'),
                          ),
                        ],
                      ),
                      ref
                          .watch(
                              adminWorkspaceResourceProvider(_incidentsRequest))
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) => _ResourceError(
                                error,
                                () => ref.invalidate(
                                    adminWorkspaceResourceProvider(
                                        _incidentsRequest))),
                            data: (incidentResponse) {
                              final incidents =
                                  (incidentResponse['data'] as List? ??
                                          const [])
                                      .whereType<Map>();
                              if (incidents.isEmpty) {
                                return const WorkflowEmpty(
                                    'Không có sự cố phù hợp bộ lọc.');
                              }
                              return Column(children: [
                                for (final incident in incidents)
                                  Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AdminOverviewTheme.background
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: workflowStatusColor(
                                                  incident['severity'])
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text('${incident['title']}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                AdminStatusBadge.fromStatus(
                                                    incident['severity']),
                                                AdminStatusBadge.fromStatus(
                                                    incident['status']),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                                '${incident['severity']} · ${incident['status']} · ${incident['occurrences']} lần ghi nhận'),
                                            Text(
                                                'Ghi nhận cuối: ${_time(incident['lastSeenAt'])}'),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                TextButton.icon(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _incidentDetail(
                                                            incident),
                                                    icon: const Icon(
                                                        Icons.history_outlined),
                                                    label: const Text(
                                                        'Lịch sử / runbook')),
                                                if (capabilities?.has(
                                                        'admin.operations.manage') ==
                                                    true) ...[
                                                  if (incident['status'] ==
                                                      'OPEN')
                                                    TextButton.icon(
                                                        onPressed: _busy
                                                            ? null
                                                            : () =>
                                                                _acknowledge(
                                                                    incident),
                                                        icon: const Icon(Icons
                                                            .assignment_turned_in_outlined),
                                                        label: const Text(
                                                            'Tiếp nhận')),
                                                  PopupMenuButton<String>(
                                                      enabled: !_busy,
                                                      onSelected: (action) =>
                                                          _incidentAction(
                                                              incident, action),
                                                      itemBuilder: (_) => [
                                                            if (incident[
                                                                    'status'] !=
                                                                'RESOLVED') ...[
                                                              const PopupMenuItem(
                                                                  value:
                                                                      'ASSIGN',
                                                                  child: Text(
                                                                      'Phân công')),
                                                              const PopupMenuItem(
                                                                  value:
                                                                      'SNOOZE',
                                                                  child: Text(
                                                                      'Tạm hoãn 4 giờ')),
                                                              if (incident[
                                                                      'conditionActive'] ==
                                                                  false)
                                                                const PopupMenuItem(
                                                                    value:
                                                                        'RESOLVE',
                                                                    child: Text(
                                                                        'Đóng sự cố')),
                                                            ] else
                                                              const PopupMenuItem(
                                                                  value:
                                                                      'REOPEN',
                                                                  child: Text(
                                                                      'Mở lại')),
                                                          ],
                                                      child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(8),
                                                          child: Icon(Icons
                                                              .more_horiz))),
                                                ],
                                              ],
                                            ),
                                          ])),
                                WorkflowPager(
                                  page: _incidentPage,
                                  limit: 50,
                                  total: ((incidentResponse['meta']
                                              as Map?)?['total'] as num?)
                                          ?.toInt() ??
                                      incidents.length,
                                  onPage: (page) =>
                                      setState(() => _incidentPage = page),
                                ),
                              ]);
                            },
                          ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionPanel(
                    icon: Icons.storage_outlined,
                    title: 'Database và migration',
                    children: [
                      if (data['queues'] is Map) ...[
                        Text(
                            'Report queue: ${((data['queues'] as Map)['reports'] as List? ?? []).map((row) => '${row['status']}: ${row['total']}').join(' · ')}'),
                        const AdminNotificationQueue(),
                      ],
                      Text(
                        'Kết nối database: ${data['database']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      for (final migration
                          in (data['migrations'] as List? ?? [])
                              .whereType<Map>())
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AdminOverviewTheme.line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                migration['applied'] == true
                                    ? Icons.check_circle_outline
                                    : Icons.pending_outlined,
                                size: 16,
                                color: migration['applied'] == true
                                    ? AdminOverviewTheme.green
                                    : AdminOverviewTheme.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    '${migration['applied'] == true ? 'Đã áp dụng' : 'Chưa hoàn tất'} · ${migration['name']}'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Backup/restore và deploy migration chạy bằng CLI trên máy vận hành. Không có nút xóa dữ liệu hoặc restore trực tiếp trong admin.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AdminOverviewTheme.muted),
                      ),
                    ],
                  ),
                ]);
          },
        );
  }
}

class AdminAuditPanel extends ConsumerStatefulWidget {
  const AdminAuditPanel({super.key, this.initialFilters = const {}});
  final Map<String, String> initialFilters;
  @override
  ConsumerState<AdminAuditPanel> createState() => _AdminAuditPanelState();
}

class _AdminAuditPanelState extends ConsumerState<AdminAuditPanel> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final name in [
      'action',
      'actorId',
      'resourceType',
      'resourceId',
      'requestId',
      'search'
    ])
      name: TextEditingController()
  };
  late final String? _owner;
  late DateTimeRange _range;
  Map<String, dynamic> _filters = {};
  int _page = 1;
  bool _busy = false;
  String? _error;
  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    final now = DateTime.now();
    _range = DateTimeRange(
        start: DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6)),
        end: DateTime(now.year, now.month, now.day));
    _applyInitialFilters();
  }

  void _applyInitialFilters() {
    for (final entry in _fields.entries) {
      entry.value.text = widget.initialFilters[entry.key] ?? '';
    }
    _apply();
  }

  @override
  void didUpdateWidget(covariant AdminAuditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Uri(queryParameters: oldWidget.initialFilters).query !=
        Uri(queryParameters: widget.initialFilters).query) {
      _applyInitialFilters();
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _apply() {
    _filters = {
      'from': _range.start.toUtc().toIso8601String(),
      'to': DateTime(_range.end.year, _range.end.month, _range.end.day + 1)
          .subtract(const Duration(milliseconds: 1))
          .toUtc()
          .toIso8601String(),
      for (final entry in _fields.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
    _page = 1;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: DateTime(now.year - 5),
        lastDate: now);
    if (_active && picked != null) setState(() => _range = picked);
  }

  Future<void> _export() async {
    final reason = await _reason(context, 'Xuất nhật ký đang lọc');
    if (!mounted || !_active || reason == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final csv = await ref.read(adminApiProvider).authorizedAuditExport(
          _filters,
          reason: reason,
          prompt: () => promptAdminStepUp(context, () => _active));
      if (!_active) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (_active) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Đã sao chép audit CSV vào clipboard.')));
      }
      if (_active) refreshAdminWorkspace(ref);
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _detail(String id) async {
    if (!_active || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(adminApiProvider).resource('/admin/audit-logs/$id');
      if (!mounted || !_active) return;
      final data = response['data'] as Map;
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                backgroundColor: AdminOverviewTheme.surface,
                title: const Text('Chi tiết nhật ký (chỉ đọc)'),
                content: SizedBox(
                    width: 640,
                    child: SingleChildScrollView(
                        child: SelectableText(
                            'Hành động: ${data['action']}\nNgười thực hiện: ${data['actorId'] ?? 'Hệ thống'}\nĐối tượng: ${data['resourceType']} / ${data['resourceId'] ?? '—'}\nRequest ID: ${data['requestId'] ?? 'Chưa có'}\n\n${data['summary']}\n\nDữ liệu trước/sau đã che thông tin nhạy cảm:\n${const JsonEncoder.withIndent('  ').convert(data['metadata'])}'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Đóng'))
                ],
              ));
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionIdentityProvider) != _owner || _owner == null) {
      return const Text('Phiên đăng nhập đã thay đổi.');
    }
    final permissions = ref.watch(adminCapabilitiesProvider).valueOrNull;
    if (permissions?.has('admin.audit.view') != true) {
      return const Text('Bạn không có quyền đọc nhật ký.');
    }
    final request = AdminRequest(
        '/admin/audit-logs', {..._filters, 'page': _page, 'limit': 30});
    return AdminSectionPanel(
      icon: Icons.history_edu_outlined,
      title: 'Nhật ký kiểm toán (Audit Log)',
      subtitle:
          'Nhật ký chỉ đọc. Xuất tối đa 5.000 dòng trong 31 ngày; mọi lần xuất đều được ghi nhận. Không tự động xóa audit log.',
      children: [
        Form(
          key: _form,
          child: AdminToolbarPanel(
            children: [
              for (final entry in const {
                'action': 'Mã hành động',
                'actorId': 'ID người thực hiện',
                'resourceType': 'Loại đối tượng',
                'resourceId': 'ID đối tượng',
                'requestId': 'Request ID',
                'search': 'Nội dung nhật ký'
              }.entries)
                SizedBox(
                    width: 240,
                    child: TextFormField(
                        controller: _fields[entry.key],
                        maxLength: entry.key == 'requestId' ? 128 : 100,
                        decoration: InputDecoration(
                            isDense: true,
                            labelText: entry.value,
                            counterText: ''),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          if (['actorId', 'resourceId'].contains(entry.key) &&
                              !RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
                                  .hasMatch(text)) {
                            return 'Nhập UUID hợp lệ.';
                          }
                          if (entry.key == 'requestId' && text.length < 8) {
                            return 'Request ID cần ít nhất 8 ký tự.';
                          }
                          return null;
                        })),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _pickRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                      '${_time(_range.start.toIso8601String()).split(' ').first} – ${_time(_range.end.toIso8601String()).split(' ').first}')),
              FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_form.currentState!.validate()) {
                            setState(_apply);
                          }
                        },
                  child: const Text('Áp dụng bộ lọc')),
              if (permissions?.has('admin.audit.export') == true)
                OutlinedButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.content_copy_outlined),
                    label: const Text('Sao chép CSV')),
            ],
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ref.watch(adminWorkspaceResourceProvider(request)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  _ResourceError(error, () => refreshAdminWorkspace(ref)),
              data: (response) {
                final rows = (response['data'] as List? ?? []).whereType<Map>();
                final meta = response['meta'] as Map? ?? {};
                final total = (meta['total'] as num? ?? 0).toInt();
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (rows.isEmpty)
                        const WorkflowEmpty(
                            'Không có nhật ký phù hợp với bộ lọc.'),
                      for (final row in rows)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminOverviewTheme.line),
                          ),
                          child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AdminOverviewTheme.blue
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: AdminOverviewTheme.blue,
                                ),
                              ),
                              title: Text(
                                '${row['summary']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                  '${row['action']} · ${_time(row['createdAt'])}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap:
                                  _busy ? null : () => _detail('${row['id']}')),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminOverviewTheme.line),
                          ),
                          child: Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '$total kết quả · Trang $_page',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                IconButton(
                                    tooltip: 'Trang trước',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: !_busy && _page > 1
                                        ? () => setState(() => _page--)
                                        : null,
                                    icon: const Icon(Icons.chevron_left)),
                                IconButton(
                                    tooltip: 'Trang sau',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: !_busy && _page * 30 < total
                                        ? () => setState(() => _page++)
                                        : null,
                                    icon: const Icon(Icons.chevron_right)),
                              ]),
                        ),
                      ),
                    ]);
              },
            ),
      ],
    );
  }
}
