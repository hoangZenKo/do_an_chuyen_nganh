import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_overview_theme.dart';
import 'admin_console_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_workspace_states.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_search_results.dart';

class AdminSearchScreen extends ConsumerStatefulWidget {
  const AdminSearchScreen(
      {super.key, this.initialQuery, this.initialKind, this.initialResourceId});
  final String? initialQuery;
  final String? initialKind;
  final String? initialResourceId;

  @override
  ConsumerState<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

class _AdminSearchScreenState extends ConsumerState<AdminSearchScreen> {
  final _controller = TextEditingController();
  String? _owner;
  String _query = '';
  String? _validation;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    final initial = widget.initialQuery?.trim() ?? '';
    _query = initial.length >= 2 && initial.length <= 100 ? initial : '';
    _controller.text = _query;
  }

  @override
  void didUpdateWidget(covariant AdminSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _controller.text = widget.initialQuery?.trim() ?? '';
      final query = _controller.text;
      _query = query.length >= 2 && query.length <= 100 ? query : '';
      _validation = query.isNotEmpty && _query.isEmpty
          ? 'Nhập từ 2 đến 100 ký tự.'
          : null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.length < 2 || value.length > 100) {
      setState(() => _validation = 'Nhập từ 2 đến 100 ký tự.');
      return;
    }
    setState(() {
      _query = value;
      _validation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionIdentityProvider);
    if (identity == null || identity != _owner) {
      return const Scaffold(
          body: Center(child: Text('Phiên đăng nhập đã thay đổi.')));
    }
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    if (rights?.has('admin.dashboard.view') != true) {
      return const Scaffold(
          body: Center(child: Text('Bạn không có quyền tra cứu.')));
    }
    final kind = adminSearchPermissions.containsKey(widget.initialKind)
        ? widget.initialKind
        : null;
    final request = AdminRequest(
        '/admin/search', {'search': _query, if (kind != null) 'kind': kind});
    final result = _query.isEmpty
        ? null
        : ref.watch(adminWorkspaceResourceProvider(request));
    return AdminWorkspaceScaffold(
      title: 'Tra cứu toàn hệ thống',
      location: '/admin/search',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.initialResourceId != null &&
              _query == widget.initialResourceId &&
              ['ROOM', 'TENANT', 'LEASE', 'INVOICE', 'PAYMENT'].contains(kind))
            AdminSearchResourceDetail(
                key: ValueKey('${kind}_${widget.initialResourceId}'),
                kind: kind!,
                id: widget.initialResourceId!),
          AdminSectionPanel(
            title: 'Tra cứu đa thực thể',
            subtitle:
                'Tìm tài khoản, khu trọ, phòng, người thuê, ticket, hợp đồng, hóa đơn và thanh toán. PII được che mặc định.',
            icon: Icons.manage_search_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Từ khóa',
                    errorText: _validation,
                    hintText: 'Nhập ít nhất 2 ký tự',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        onPressed: _submit,
                        icon: const Icon(Icons.arrow_forward)),
                  ),
                ),
                const SizedBox(height: 20),
                if (_query.isEmpty)
                  const Text(
                      'Chưa có truy vấn. Kết quả chỉ hiển thị theo quyền admin hiện tại.'),
                if (result != null)
                  result.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const AdminLoadingState(),
                    error: (error, _) => AdminFailureState(
                        error: error,
                        retry: () {
                          ref.invalidate(adminResourceProvider(request));
                          ref.invalidate(
                              adminWorkspaceResourceProvider(request));
                        }),
                    data: (response) {
                      final groups = (response['data'] as List? ?? const [])
                          .whereType<Map>()
                          .map((value) => Map<String, dynamic>.from(value))
                          .where((group) =>
                              (group['items'] as List? ?? const [])
                                  .isNotEmpty &&
                              rights?.has(
                                      adminSearchPermissions[group['kind']] ??
                                          '') ==
                                  true)
                          .toList();
                      if (groups.isEmpty) {
                        return const Text(
                            'Không tìm thấy dữ liệu phù hợp hoặc bạn không có quyền xem.');
                      }
                      return Column(
                        children: [
                          for (final group in groups)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AdminOverviewTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AdminOverviewTheme.line),
                              ),
                              child: AdminSearchResultGroup(
                                  key: ValueKey('$_query:${group['kind']}'),
                                  query: _query,
                                  group: group),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
