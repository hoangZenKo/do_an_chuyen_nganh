import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';

enum AdminRegistrySection {
  verifications,
  propertyReviews,
  plans,
  subscriptions
}

class LandlordVerificationPanel extends ConsumerStatefulWidget {
  const LandlordVerificationPanel({super.key});
  @override
  ConsumerState<LandlordVerificationPanel> createState() =>
      _LandlordVerificationState();
}

class _LandlordVerificationState
    extends WorkflowState<LandlordVerificationPanel> {
  Future<void> _submit(Map<String, dynamic> current) async {
    if (!active || busy) return;
    final values = await form('Gửi hồ sơ xác minh', [
      WorkflowField('ticketId', 'Mã ticket có tài liệu đã quét',
          initial: '${current['ticketId'] ?? ''}',
          minLength: 36,
          maxLength: 36),
      workflowReason,
    ]);
    if (values == null || !active) return;
    await command('/landlord-verification',
        {...values, 'version': current['version'] ?? 0});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    if (!active) return const SizedBox.shrink();
    return resource(const AdminRequest('/landlord-verification'), (response) {
      final data = workflowData(response);
      final status = '${data['status'] ?? 'NOT_SUBMITTED'}';
      return AdminSectionPanel(
          icon: Icons.verified_user_outlined,
          title: 'Xác minh chủ trọ',
          subtitle:
              'Bạn chỉ xem được hồ sơ của mình. Tài liệu gửi qua ticket hỗ trợ và phải qua quét an toàn.',
          actions: [
            if (!busy &&
                ['NOT_SUBMITTED', 'NEEDS_INFO', 'REJECTED'].contains(status))
              FilledButton.icon(
                  onPressed: () => _submit(data),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Gửi / bổ sung hồ sơ'))
          ],
          children: [
            ...operationState,
            Text(workflowLabel(status),
                style: Theme.of(context).textTheme.titleMedium),
            Text(
                'Phiên bản: ${data['version'] ?? 0} · Ticket: ${data['ticketId'] ?? 'Chưa có'}'),
            const Text(
                'Nếu cần bổ sung, xem yêu cầu và tải tài liệu trong hội thoại ticket gốc.')
          ]);
    });
  }
}

class AdminRegistryScreen extends ConsumerStatefulWidget {
  const AdminRegistryScreen({super.key, required this.section});
  final AdminRegistrySection section;
  @override
  ConsumerState<AdminRegistryScreen> createState() => _RegistryState();
}

class _RegistryState extends WorkflowState<AdminRegistryScreen> {
  int page = 1;
  int historyPage = 1;
  String status = 'ALL';
  String? historyId;

  @override
  Future<Map<String, dynamic>?> command(
      String path, Map<String, dynamic> payload,
      {bool patch = false}) async {
    final result = await super.command(path, payload, patch: patch);
    if (active && reviewQueue && !verification) {
      ref.invalidate(adminPropertiesProvider);
      ref.invalidate(adminPropertyDetailProvider);
    }
    return result;
  }

  bool get verification => widget.section == AdminRegistrySection.verifications;
  bool get plans => widget.section == AdminRegistrySection.plans;
  bool get subscriptions =>
      widget.section == AdminRegistrySection.subscriptions;
  bool get reviewQueue => !plans && !subscriptions;
  String get path => switch (widget.section) {
        AdminRegistrySection.verifications => adminVerificationsRoute,
        AdminRegistrySection.propertyReviews => adminPropertyReviewsRoute,
        AdminRegistrySection.plans => adminPlansRoute,
        AdminRegistrySection.subscriptions => adminSubscriptionsRoute,
      };
  String get title => switch (widget.section) {
        AdminRegistrySection.verifications => 'Xác minh chủ trọ',
        AdminRegistrySection.propertyReviews => 'Duyệt khu trọ',
        AdminRegistrySection.plans => 'Gói dịch vụ',
        AdminRegistrySection.subscriptions => 'Đăng ký dịch vụ',
      };
  String get viewPermission => verification
      ? 'admin.verifications.view'
      : reviewQueue
          ? 'admin.properties.view'
          : 'admin.plans.view';
  String get managePermission => verification
      ? 'admin.verifications.manage'
      : reviewQueue
          ? 'admin.properties.manage'
          : 'admin.plans.manage';
  bool get allowed =>
      can(viewPermission) && (!verification || can('admin.support.read'));

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    final ready = active && !rights.isLoading && !rights.hasError && allowed;
    return AdminWorkspaceScaffold(
        title: title,
        location: path,
        busy: busy,
        canOpen: ready,
        body: !ready
            ? const Center(child: Text('Bạn không có quyền mở chức năng này.'))
            : ListView(padding: const EdgeInsets.all(16), children: [
                ...operationState,
                AdminSectionPanel(
                    title: title,
                    icon: reviewQueue
                        ? Icons.fact_check_outlined
                        : Icons.layers_outlined,
                    subtitle: reviewQueue
                        ? 'Quyết định có lý do, phiên bản và nhật ký. Duyệt khu trọ độc lập với kiểm duyệt tin đăng.'
                        : 'Cấp quyền sử dụng hành chính; không ghi nhận doanh thu hay tự động thu tiền. Giá gói là giá niêm yết VND/tháng.',
                    actions: [
                      if (can(managePermission))
                        FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => plans
                                    ? _savePlan()
                                    : subscriptions
                                        ? _assign()
                                        : _submit(),
                            icon: const Icon(Icons.add),
                            label: Text(plans
                                ? 'Tạo gói dịch vụ'
                                : subscriptions
                                    ? 'Cấp gói'
                                    : 'Tiếp nhận hồ sơ')),
                      if (plans)
                        TextButton(
                            onPressed: () =>
                                context.go(adminSubscriptionsRoute),
                            child: const Text('Đăng ký dịch vụ')),
                      if (subscriptions)
                        TextButton(
                            onPressed: () => context.go(adminPlansRoute),
                            child: const Text('Danh mục gói')),
                    ],
                    children: [
                      if (reviewQueue)
                        DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: status,
                            decoration: const InputDecoration(
                                labelText: 'Trạng thái hồ sơ'),
                            items: const {
                              'ALL': 'Tất cả',
                              'PENDING': 'Chờ duyệt',
                              'NEEDS_INFO': 'Cần bổ sung',
                              'APPROVED': 'Đã duyệt',
                              'REJECTED': 'Từ chối'
                            }
                                .entries
                                .map((entry) => DropdownMenuItem(
                                    value: entry.key, child: Text(entry.value)))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (value) => setState(() {
                                      status = value!;
                                      page = 1;
                                    })),
                      const SizedBox(height: 16),
                      resource(
                          AdminRequest(path, {
                            'page': page,
                            'limit': 20,
                            if (reviewQueue && status != 'ALL') 'status': status
                          }), (response) {
                        final rows = workflowRows(response);
                        final total =
                            (response['meta'] as Map?)?['total'] as int? ??
                                rows.length;
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (rows.isEmpty)
                                const WorkflowEmpty('Chưa có dữ liệu phù hợp.'),
                              for (final row in rows) _card(row),
                              WorkflowPager(
                                  page: page,
                                  total: total,
                                  limit: 20,
                                  onPage: (value) =>
                                      setState(() => page = value)),
                            ]);
                      }),
                    ]),
                if (historyId != null) ...[
                  const SizedBox(height: 16),
                  AdminSectionPanel(
                      title: 'Lịch sử cấp gói',
                      icon: Icons.history,
                      actions: [
                        TextButton(
                            onPressed: () => setState(() => historyId = null),
                            child: const Text('Đóng'))
                      ],
                      children: [
                        resource(
                            AdminRequest(
                                '/admin/subscriptions/$historyId/events',
                                {'page': historyPage, 'limit': 20}),
                            (response) => Column(children: [
                                  if (workflowRows(response).isEmpty)
                                    const WorkflowEmpty('Chưa có lịch sử.'),
                                  for (final row in workflowRows(response))
                                    ListTile(
                                        title: Text(
                                            '${row['action']} · ${row['createdAt']}'),
                                        subtitle: Text(
                                            '${row['reason']}\nNgười thực hiện: ${row['actorId']}\nĐiều khoản: ${row['snapshot']}')),
                                  WorkflowPager(
                                      page: historyPage,
                                      total: (response['meta']
                                              as Map?)?['total'] as int? ??
                                          0,
                                      limit: 20,
                                      onPage: (value) =>
                                          setState(() => historyPage = value)),
                                ]))
                      ]),
                ],
              ]));
  }

  Widget _card(Map<String, dynamic> row) {
    final property = Map<String, dynamic>.from(row['property'] as Map? ?? {});
    final snapshot =
        Map<String, dynamic>.from(row['planSnapshot'] as Map? ?? {});
    final expiry = DateTime.tryParse('${row['endsAt']}');
    final expired =
        subscriptions && expiry != null && !expiry.isAfter(DateTime.now());
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  plans
                      ? '${row['name']}'
                      : subscriptions
                          ? 'Chủ trọ ${row['landlordId']}'
                          : verification
                              ? 'Chủ trọ ${row['landlordId']}'
                              : '${property['name'] ?? row['propertyId']}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(plans
                  ? '${row['code']} · ${row['price']} VND/tháng · ${row['isActive'] == true ? 'Đang mở' : 'Ngừng cấp mới'}\nGiới hạn: ${row['maxProperties']} khu trọ · ${row['maxRooms']} phòng'
                  : subscriptions
                      ? '${snapshot['name'] ?? snapshot['code']} · ${expired ? 'Đã hết hạn' : 'Được cấp'}\nTừ ${row['startsAt']} · Đến ${row['endsAt'] ?? 'Không thời hạn'}\nGiới hạn theo snapshot: ${snapshot['maxProperties']} khu trọ · ${snapshot['maxRooms']} phòng'
                      : '${workflowLabel(row['status'])} · Phiên bản ${row['version']}\nGửi: ${row['submittedAt']}\n${row['reviewNote'] ?? ''}'),
              if (row['reviewerId'] != null)
                Text(
                    'Người duyệt: ${row['reviewerId']} · ${row['reviewedAt']}'),
              if (row['informationChanged'] == true)
                const Text(
                    'Thông tin đã thay đổi sau khi gửi. Cần tiếp nhận lại hồ sơ.'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (verification)
                  OutlinedButton(
                      onPressed: () => context.go(Uri(
                              path: adminSupportCenterRoute,
                              queryParameters: {
                                'ticketId': '${row['ticketId']}'
                              }).toString()),
                      child: const Text('Tài liệu & hội thoại')),
                if (reviewQueue && !verification)
                  OutlinedButton(
                      onPressed: () => context
                          .go(adminPropertyDetailPath('${row['propertyId']}')),
                      child: const Text('Chi tiết khu trọ')),
                if (can('admin.audit.view'))
                  TextButton(
                      onPressed: () => context.go(Uri(
                              path: adminAuditLogsRoute,
                              queryParameters: {'resourceId': '${row['id']}'})
                          .toString()),
                      child: const Text('Nhật ký')),
                if (can(managePermission) && !busy) ...[
                  if (plans)
                    OutlinedButton(
                        onPressed: () => _savePlan(row),
                        child: const Text('Chỉnh sửa')),
                  if (subscriptions)
                    OutlinedButton(
                        onPressed: () => _assign(row),
                        child: const Text('Đổi gói')),
                  if (subscriptions && !expired)
                    OutlinedButton(
                        onPressed: () => _cancel(row),
                        child: const Text('Hủy cấp gói')),
                  if (reviewQueue &&
                      row['status'] == 'PENDING' &&
                      row['informationChanged'] != true)
                    for (final decision in const {
                      'APPROVED': 'Duyệt',
                      'NEEDS_INFO': 'Yêu cầu bổ sung',
                      'REJECTED': 'Từ chối'
                    }.entries)
                      OutlinedButton(
                          onPressed: () =>
                              _review(row, decision.key, decision.value),
                          child: Text(decision.value)),
                  if (reviewQueue &&
                      (['NEEDS_INFO', 'REJECTED'].contains(row['status']) ||
                          row['informationChanged'] == true))
                    OutlinedButton(
                        onPressed: () => _submit(row),
                        child: const Text('Tiếp nhận lại')),
                ],
                if (subscriptions)
                  TextButton(
                      onPressed: () => setState(() {
                            historyId = '${row['id']}';
                            historyPage = 1;
                          }),
                      child: const Text('Lịch sử')),
              ]),
            ])));
  }

  bool get writable =>
      active &&
      !ref.read(adminCapabilitiesProvider).isLoading &&
      allowed &&
      can(managePermission);

  Future<void> _review(
      Map<String, dynamic> row, String decision, String label) async {
    final input = await form('$label hồ sơ', [workflowReason]);
    if (input == null || !writable) return;
    await command('$path/${row['id']}/review', {
      'version': row['version'],
      'status': decision,
      'reason': input['reason']
    });
  }

  Future<void> _submit([Map<String, dynamic>? row]) async {
    final input = await form('Tiếp nhận hồ sơ', [
      WorkflowField(verification ? 'landlordId' : 'propertyId',
          verification ? 'ID chủ trọ' : 'ID khu trọ',
          initial: '${row?[verification ? 'landlordId' : 'propertyId'] ?? ''}',
          minLength: 36,
          maxLength: 36),
      if (verification)
        WorkflowField('ticketId', 'ID ticket có tài liệu đã quét an toàn',
            initial: '${row?['ticketId'] ?? ''}', minLength: 36, maxLength: 36),
      workflowReason,
    ]);
    if (input == null || !writable) return;
    final idKey = verification ? 'landlordId' : 'propertyId';
    final sameOwner = row?[idKey] == input[idKey];
    await command(
        verification
            ? path
            : '/admin/properties/${input['propertyId']}/submit-review',
        {
          if (verification) 'landlordId': input['landlordId'],
          if (verification) 'ticketId': input['ticketId'],
          'version': sameOwner ? (row?['version'] ?? 0) : 0,
          'reason': input['reason'],
        });
  }

  Future<void> _savePlan([Map<String, dynamic>? row]) async {
    final input = await form('Điều khoản gói dịch vụ', [
      WorkflowField('code', 'Mã gói',
          initial: '${row?['code'] ?? 'FREE'}',
          choices: const {'FREE': 'Free', 'PRO': 'Pro', 'PREMIUM': 'Premium'}),
      WorkflowField('name', 'Tên hiển thị',
          initial: '${row?['name'] ?? ''}', minLength: 2, maxLength: 80),
      WorkflowField('price', 'Giá niêm yết VND/tháng',
          initial: '${row?['price'] ?? 0}', maxLength: 10),
      WorkflowField('maxProperties', 'Số khu trọ tối đa',
          initial: '${row?['maxProperties'] ?? 1}', maxLength: 7),
      WorkflowField('maxRooms', 'Số phòng tối đa',
          initial: '${row?['maxRooms'] ?? 10}', maxLength: 7),
      WorkflowField('isActive', 'Cho phép cấp mới',
          initial: '${row?['isActive'] ?? true}',
          choices: const {'true': 'Có', 'false': 'Không'}),
      workflowReason,
    ]);
    if (input == null || !writable) return;
    final price = int.tryParse(input['price']!);
    final maxProperties = int.tryParse(input['maxProperties']!);
    final maxRooms = int.tryParse(input['maxRooms']!);
    if (price == null ||
        price < 0 ||
        price > 2147483647 ||
        maxProperties == null ||
        maxProperties < 1 ||
        maxProperties > 1000000 ||
        maxRooms == null ||
        maxRooms < 1 ||
        maxRooms > 1000000 ||
        input['code'] == 'FREE' && price != 0) {
      setState(
          () => failure = 'Giá/giới hạn không hợp lệ; Free phải có giá 0.');
      return;
    }
    await command(adminPlansRoute, {
      ...input,
      'price': price,
      'maxProperties': maxProperties,
      'maxRooms': maxRooms,
      'isActive': input['isActive'] == 'true',
      'version': row?['code'] == input['code'] ? (row?['version'] ?? 0) : 0
    });
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final input = await form(
        'Hủy cấp gói — không hoàn tiền hay xóa dữ liệu', [workflowReason]);
    if (input == null || !writable) return;
    await command('/admin/subscriptions/${row['id']}/cancel',
        {'version': row['version'], 'reason': input['reason']});
  }

  Future<void> _assign([Map<String, dynamic>? row]) async {
    if (!writable) return;
    try {
      final response = await ref.read(adminResourceProvider(
          const AdminRequest(adminPlansRoute, {'limit': 50})).future);
      if (!writable) return;
      final available = workflowRows(response)
          .where((plan) => plan['isActive'] == true)
          .toList();
      if (available.isEmpty) {
        setState(() => failure = 'Cần tạo gói đang mở trước khi cấp.');
        return;
      }
      final input = await form('Cấp gói (không thu tiền)', [
        WorkflowField('landlordId', 'ID chủ trọ',
            initial: '${row?['landlordId'] ?? ''}',
            minLength: 36,
            maxLength: 36),
        WorkflowField('planId', 'Gói dịch vụ',
            initial: '${available.first['id']}',
            choices: {
              for (final plan in available)
                '${plan['id']}':
                    '${plan['name']} · ${plan['maxProperties']} khu · ${plan['maxRooms']} phòng'
            }),
        const WorkflowField(
            'endsAt', 'Hết hạn ISO-8601 (để trống nếu không hạn)',
            minLength: 0, maxLength: 40),
        workflowReason,
      ]);
      if (input == null || !writable) return;
      if (input['endsAt']!.isNotEmpty &&
          DateTime.tryParse(input['endsAt']!) == null) {
        setState(() => failure = 'Ngày hết hạn phải là ISO-8601 hợp lệ.');
        return;
      }
      final plan =
          available.firstWhere((plan) => plan['id'] == input['planId']);
      await command('/admin/landlords/${input['landlordId']}/subscription', {
        'planId': input['planId'],
        'planVersion': plan['version'],
        'version': row?['landlordId'] == input['landlordId']
            ? (row?['version'] ?? 0)
            : 0,
        if (input['endsAt']!.isNotEmpty) 'endsAt': input['endsAt'],
        'reason': input['reason'],
      });
    } catch (error) {
      if (active) setState(() => failure = '$error');
    }
  }
}
