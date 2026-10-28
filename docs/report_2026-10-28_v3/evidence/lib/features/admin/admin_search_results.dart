import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_states.dart';

const adminSearchPermissions = {
  'ACCOUNT': 'admin.accounts.view',
  'PROPERTY': 'admin.properties.view',
  'ROOM': 'admin.properties.view',
  'TENANT': 'admin.support.read',
  'LEASE': 'admin.support.read',
  'SUPPORT_TICKET': 'admin.support.read',
  'INVOICE': 'admin.finance.read',
  'PAYMENT': 'admin.finance.read',
};

class AdminSearchResultGroup extends ConsumerStatefulWidget {
  const AdminSearchResultGroup(
      {super.key, required this.query, required this.group});
  final String query;
  final Map<String, dynamic> group;

  @override
  ConsumerState<AdminSearchResultGroup> createState() =>
      _AdminSearchResultGroupState();
}

class _AdminSearchResultGroupState
    extends ConsumerState<AdminSearchResultGroup> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final kind = '${widget.group['kind']}';
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    if (ref.watch(sessionIdentityProvider) == null ||
        rights?.has(adminSearchPermissions[kind] ?? '') != true) {
      return const SizedBox.shrink();
    }
    final request = AdminRequest('/admin/search',
        {'search': widget.query, 'kind': kind, 'page': _page, 'limit': 10});
    if (_page == 1) return _content(context, widget.group);
    return ref.watch(adminWorkspaceResourceProvider(request)).when(
          skipLoadingOnRefresh: false,
          loading: () => const AdminLoadingState(),
          error: (error, _) => Column(children: [
            AdminFailureState(
                error: error,
                retry: () => ref.invalidate(adminResourceProvider(request))),
            TextButton(
                onPressed: () => setState(() => _page = 1),
                child: const Text('Về trang đầu')),
          ]),
          data: (response) {
            final groups = workflowRows(response);
            return groups.isEmpty
                ? const WorkflowEmpty('Không còn kết quả theo quyền hiện tại.')
                : _content(context, groups.first);
          },
        );
  }

  Widget _content(BuildContext context, Map<String, dynamic> group) {
    final kind = '${group['kind']}';
    final items = (group['items'] as List? ?? []).whereType<Map>().toList();
    final meta = Map<String, dynamic>.from(group['meta'] as Map? ?? {});
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text('${workflowLabel(kind)} (${meta['total'] ?? items.length})'),
      children: [
        for (final item in items)
          ListTile(
            title: Text(
                '${item['name'] ?? item['fullName'] ?? item['subject'] ?? item['id']}'),
            subtitle: Text([
              if (item['email'] != null) '${item['email']}',
              if (item['status'] != null) workflowLabel(item['status']),
              if (item['amount'] != null) 'Số tiền: ${item['amount']}',
              if (item['invoiceId'] != null) 'Hóa đơn: ${item['invoiceId']}',
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final id = Uri.encodeComponent('${item['id']}');
              if (kind == 'ACCOUNT') {
                context.push('/admin/accounts/$id');
              } else if (kind == 'PROPERTY') {
                context.push('/admin/properties/$id');
              } else if (kind == 'SUPPORT_TICKET') {
                context.push('/admin/tickets?ticketId=$id');
              } else {
                context.push(Uri(path: '/admin/search', queryParameters: {
                  'q': '${item['id']}',
                  'kind': kind,
                  'resourceId': '${item['id']}'
                }).toString());
              }
            },
          ),
        if (items.isEmpty) const WorkflowEmpty('Không có kết quả ở trang này.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Trang $_page'),
                OutlinedButton(
                    onPressed: _page > 1 ? () => setState(() => _page--) : null,
                    child: const Text('Trang trước')),
                OutlinedButton(
                    onPressed: meta['hasMore'] == true && _page < 100
                        ? () => setState(() => _page++)
                        : null,
                    child: const Text('Trang sau')),
              ]),
        ),
      ],
    );
  }
}

class AdminSearchResourceDetail extends ConsumerWidget {
  const AdminSearchResourceDetail(
      {super.key, required this.kind, required this.id});
  final String kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    if (ref.watch(sessionIdentityProvider) == null ||
        rights?.has(adminSearchPermissions[kind] ?? '') != true) {
      return const WorkflowEmpty('Không có quyền xem tài nguyên này.');
    }
    return AdminSectionPanel(
        title: '${workflowLabel(kind)} · chỉ đọc',
        icon: Icons.lock_outline,
        children: [
          WorkflowResource(
              request: AdminRequest('/admin/resources/$id', {'kind': kind}),
              builder: (response) {
                final row = workflowData(response);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final key in [
                        'id',
                        'name',
                        'fullName',
                        'status',
                        'tenantId',
                        'invoiceId',
                        'amount',
                        'totalAmount',
                        'paidAmount',
                        'paidAt',
                        'startDate',
                        'endDate'
                      ])
                        if (row[key] != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SelectableText(
                                  '${workflowLabel(key)}: ${row[key]}')),
                      TextButton.icon(
                          icon: const Icon(Icons.link),
                          label: const Text('Sao chép liên kết tra cứu'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: Uri(
                                    path: '/admin/search',
                                    queryParameters: {
                                  'q': id,
                                  'kind': kind,
                                  'resourceId': id
                                }).toString()));
                          }),
                    ]);
              }),
        ]);
  }
}
