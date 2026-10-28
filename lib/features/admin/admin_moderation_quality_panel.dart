import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminModerationQualityPanel extends ConsumerStatefulWidget {
  const AdminModerationQualityPanel({super.key});

  @override
  ConsumerState<AdminModerationQualityPanel> createState() => _QualityState();
}

class _QualityState extends WorkflowState<AdminModerationQualityPanel> {
  late DateTime _to = DateTime.now().toUtc();
  late DateTime _from = _to.subtract(const Duration(days: 30));
  String _timezone = 'Asia/Ho_Chi_Minh';
  String _state = 'PENDING';
  int _page = 1;

  Map<String, dynamic> get _range => {
        'from': _from.toIso8601String(),
        'to': _to.toIso8601String(),
        'timezone': _timezone
      };

  Future<void> _customRange() async {
    final input = await form('Khoảng thời gian QA', [
      WorkflowField('from', 'Từ · ISO8601 có Z hoặc ±hh:mm',
          initial: _from.toIso8601String(), maxLength: 40),
      WorkflowField('to', 'Đến · không bao gồm thời điểm này',
          initial: _to.toIso8601String(), maxLength: 40),
      WorkflowField('timezone', 'Múi giờ IANA (ngữ cảnh hiển thị)',
          initial: _timezone, maxLength: 80),
    ]);
    if (input == null || !active || !mounted) return;
    final from = DateTime.tryParse('${input['from']}'),
        to = DateTime.tryParse('${input['to']}');
    final explicitOffset = RegExp(r'T.*(?:Z|[+-]\d{2}:\d{2})$');
    if (from == null ||
        to == null ||
        !explicitOffset.hasMatch('${input['from']}') ||
        !explicitOffset.hasMatch('${input['to']}') ||
        !from.isBefore(to) ||
        to.isAfter(DateTime.now()) ||
        to.difference(from) > const Duration(days: 93)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Dùng ISO8601 có múi giờ, tối đa 93 ngày và không ở tương lai.')));
      return;
    }
    setState(() {
      _from = from.toUtc();
      _to = to.toUtc();
      _timezone = '${input['timezone']}';
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    if (!active || rights?.has('admin.moderation.reports') != true)
      return const SizedBox.shrink();
    final canReview = rights?.has('admin.listings.moderate') == true ||
        rights?.has('admin.reviews.moderate') == true;
    return AdminSectionPanel(
      icon: Icons.fact_check_outlined,
      title: 'Chất lượng kiểm duyệt và QA',
      subtitle:
          'QA độc lập chỉ ghi nhận chất lượng; không đảo quyết định, không tự áp dụng chế tài.',
      children: [
        Wrap(spacing: 10, runSpacing: 8, children: [
          for (final days in [7, 30, 90])
            OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          _to = DateTime.now().toUtc();
                          _from = _to.subtract(Duration(days: days));
                          _page = 1;
                        }),
                child: Text('$days ngày')),
          TextButton(
              onPressed: busy ? null : _customRange,
              child: const Text('Khoảng tùy chỉnh')),
        ]),
        Text(
            'UTC: ${_from.toIso8601String()} → ${_to.toIso8601String()} (không gồm mốc cuối) · $_timezone'),
        const SizedBox(height: 12),
        resource(AdminRequest('/admin/moderation-policies/quality', _range),
            (response) {
          final data = workflowData(response);
          final qa = Map<String, dynamic>.from(data['qa'] as Map? ?? {});
          final reopen = data['appealReopenRate'];
          final disagreement = qa['disagreementRate'];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['displayFrom'] != null)
                  Text(
                      '${data['timezone']}: ${data['displayFrom']} → ${data['displayTo']} (không gồm mốc cuối)'),
                Text('Cập nhật: ${data['generatedAt'] ?? '-'}'),
                Text(
                    'Appeal mở lại / (giữ nguyên + mở lại): ${reopen is num ? '${(reopen * 100).toStringAsFixed(1)}%' : 'chưa có mẫu'}'),
                Text(
                    'QA không đồng ý / toàn bộ QA: ${disagreement is num ? '${(disagreement * 100).toStringAsFixed(1)}%' : 'chưa có mẫu'} · ${qa['total'] ?? 0} review'),
                if (data['supportFeedback'] is Map)
                  Text(
                      'CSAT: ${(data['supportFeedback'] as Map)['average'] ?? '-'} / 5 · ${(data['supportFeedback'] as Map)['responses']} phản hồi'),
                for (final row
                    in (data['decisions'] as List? ?? []).whereType<Map>())
                  Text(
                      '${workflowLabel(row['kind'])}: ${row['total']} quyết định · Admin ${row['actorId']}'),
                if ((data['decisions'] as List? ?? []).isEmpty)
                  const WorkflowEmpty(
                      'Chưa có quyết định trong khoảng thời gian này.'),
                const Text(
                    'Mốc đo: decision.createdAt, appeal.resolvedAt, QA.createdAt, feedbackAt. Mẫu QA không đại diện toàn bộ nền tảng; appeal mở lại chưa phải kết luận đảo quyết định.'),
              ]);
        }),
        if (canReview) ...[
          const Divider(height: 32),
          DropdownButtonFormField<String>(
            value: _state,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mẫu QA'),
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('Chưa review')),
              DropdownMenuItem(value: 'REVIEWED', child: Text('Đã review')),
              DropdownMenuItem(value: 'ALL', child: Text('Tất cả'))
            ],
            onChanged: (value) => setState(() {
              _state = value ?? 'PENDING';
              _page = 1;
            }),
          ),
          const SizedBox(height: 12),
          resource(
              AdminRequest('/admin/moderation-policies/quality/samples', {
                ..._range,
                'state': _state,
                'page': _page,
                'limit': 10
              }), (response) {
            final rows = workflowRows(response);
            final meta =
                Map<String, dynamic>.from(response['meta'] as Map? ?? {});
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Thứ tự lấy mẫu theo hash ổn định trong khoảng đã chọn; loại trừ quyết định do chính bạn tạo.'),
                  if (rows.isEmpty)
                    const WorkflowEmpty(
                        'Không có mẫu QA phù hợp với quyền hiện tại.'),
                  for (final row in rows)
                    _QualitySample(
                        key: ValueKey('${row['id']}:${row['reviewedAt']}'),
                        row: row),
                  Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Trang $_page'),
                        OutlinedButton(
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                            child: const Text('Mẫu trước')),
                        OutlinedButton(
                            onPressed: meta['hasMore'] == true && _page < 100
                                ? () => setState(() => _page++)
                                : null,
                            child: const Text('Mẫu tiếp')),
                      ]),
                ]);
          }),
        ],
      ],
    );
  }
}

class _QualitySample extends ConsumerStatefulWidget {
  const _QualitySample({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  ConsumerState<_QualitySample> createState() => _QualitySampleState();
}

class _QualitySampleState extends WorkflowState<_QualitySample> {
  bool _open = false;

  Future<void> _review(Map<String, dynamic> decision) async {
    final input = await form('Ghi nhận QA độc lập', const [
      WorkflowField('outcome', 'Kết luận QA', choices: {
        'AGREE': 'Đồng ý',
        'DISAGREE': 'Không đồng ý',
        'NEEDS_DISCUSSION': 'Cần trao đổi'
      }),
      workflowReason,
    ]);
    if (input != null)
      await command(
          '/admin/moderation-policies/quality/samples/${widget.row['id']}/review',
          {...input, 'version': decision['version']});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    final permission = ['REVIEW', 'REPLY'].contains(widget.row['kind'])
        ? 'admin.reviews.moderate'
        : 'admin.listings.moderate';
    if (!active ||
        rights?.has('admin.moderation.reports') != true ||
        rights?.has(permission) != true) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(
          '${workflowLabel(widget.row['kind'])} · ${widget.row['fromStatus']} → ${widget.row['toStatus']}'),
      subtitle: Text(
          'Moderator ${widget.row['actorId']} · ${widget.row['outcome'] ?? 'Chưa QA'}'),
      onExpansionChanged: (open) => setState(() => _open = open),
      children: [
        if (_open)
          resource(
              AdminRequest(
                  '/admin/moderation-policies/quality/samples/${widget.row['id']}'),
              (response) {
            final data = workflowData(response);
            final evidence =
                const JsonEncoder.withIndent('  ').convert(data['evidence']);
            final review = data['qualityReview'];
            return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...operationState,
                      Text('Lý do quyết định: ${data['reason']}'),
                      Text(
                          'Policy: ${data['policy'] is Map ? (data['policy'] as Map)['title'] : 'không có'}'),
                      const SizedBox(height: 8),
                      SelectableText(evidence.length > 20000
                          ? '${evidence.substring(0, 20000)}\n[Nội dung được rút gọn]'
                          : evidence),
                      if (review is Map)
                        Text(
                            'QA: ${review['outcome']} · ${review['reason']} · Reviewer ${review['reviewerId']} · ${review['createdAt']}'),
                      if (review == null)
                        FilledButton(
                            onPressed: busy ? null : () => _review(data),
                            child: const Text('Ghi nhận QA')),
                    ]));
          }),
      ],
    );
  }
}
