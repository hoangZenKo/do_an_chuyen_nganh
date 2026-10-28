import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import 'admin_overview_theme.dart';
import '../../models/admin_account_detail.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_step_up.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_states.dart';

class AdminAccountDetailPanel extends ConsumerStatefulWidget {
  const AdminAccountDetailPanel({super.key, required this.accountId});
  final String accountId;
  @override
  ConsumerState<AdminAccountDetailPanel> createState() =>
      _AdminAccountDetailPanelState();
}

class _AdminAccountDetailPanelState
    extends ConsumerState<AdminAccountDetailPanel> {
  late final String? _owner;
  bool _busy = false;
  Object? _failure;
  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  bool _can(String permission) {
    if (!_active) return false;
    final rights = ref.read(adminCapabilitiesProvider);
    return !rights.isLoading &&
        !rights.hasError &&
        rights.valueOrNull?.has('admin.accounts.view') == true &&
        rights.valueOrNull?.has(permission) == true;
  }

  bool get _conflict =>
      _failure is ApiFailure && (_failure as ApiFailure).statusCode == 409;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  void _reload() {
    setState(() => _failure = null);
    ref.invalidate(adminAccountDetailProvider(widget.accountId));
  }

  Future<String?> _reason(
      String permission, String title, String description) async {
    var input = '';
    var invalidated = false;
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Consumer(builder: (context, ref, child) {
              ref.watch(sessionIdentityProvider);
              ref.watch(adminCapabilitiesProvider);
              if (!_can(permission)) invalidated = true;
              if (invalidated) return _expiredDialog(dialogContext);
              return AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(description),
                            const SizedBox(height: 16),
                            TextFormField(
                                onChanged: (value) => input = value,
                                maxLength: 1000,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Lý do / mã hồ sơ hỗ trợ'),
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 10
                                        ? 'Nhập ít nhất 10 ký tự.'
                                        : null),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Hủy')),
                    FilledButton(
                        onPressed: () {
                          if (_can(permission) &&
                              form.currentState!.validate()) {
                            Navigator.pop(dialogContext, input.trim());
                          }
                        },
                        child: const Text('Xác nhận')),
                  ]);
            }));
    return !invalidated && _can(permission) ? result : null;
  }

  Widget _expiredDialog(BuildContext context) => AlertDialog(
          title: const Text('Phiên hoặc quyền truy cập đã thay đổi.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'))
          ]);

  Future<T?> _run<T>(String permission, String title, String description,
      Future<T> Function(String reason) operation,
      {bool refresh = true}) async {
    if (!_can(permission) || _busy || _conflict) return null;
    final reason = await _reason(permission, title, description);
    if (reason == null || !_can(permission) || _busy) return null;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = await operation(reason);
      if (!mounted || !_can(permission)) return null;
      if (refresh) {
        ref.invalidate(adminAccountsProvider);
        ref.invalidate(adminAccountDetailProvider(widget.accountId));
        ref.invalidate(adminResourceProvider);
        ref.invalidate(adminWorkspaceResourceProvider);
        ref.invalidate(adminOverviewProvider);
        ref.invalidate(adminLandlordsProvider);
        ref.invalidate(adminLandlordDetailProvider(widget.accountId));
        ref.invalidate(adminAuditLogsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã ghi nhận thao tác.')));
      }
      return result;
    } catch (error) {
      if (_can(permission)) setState(() => _failure = error);
      return null;
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<String?> _stepUp(String permission) =>
      promptAdminStepUp(context, () => _can(permission));

  Future<void> _reveal() async {
    final contacts = await _run<AdminAccountContacts>(
        'admin.pii.reveal',
        'Xem thông tin liên hệ?',
        'Chỉ xem khi cần hỗ trợ. Thao tác này được ghi vào nhật ký.',
        (reason) => ref.read(adminApiProvider).revealAccountContacts(
            widget.accountId,
            reason: reason,
            prompt: () => _stepUp('admin.pii.reveal')),
        refresh: false);
    if (!mounted || !_can('admin.pii.reveal') || contacts == null) return;
    ref.invalidate(adminAuditLogsProvider);
    var invalidated = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => Consumer(builder: (context, ref, child) {
              ref.watch(sessionIdentityProvider);
              ref.watch(adminCapabilitiesProvider);
              if (!_can('admin.pii.reveal')) invalidated = true;
              if (invalidated) return _expiredDialog(dialogContext);
              return AlertDialog(
                  title: const Text('Thông tin liên hệ'),
                  content: _PrivateContacts(contacts: contacts),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Đóng'))
                  ]);
            }));
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    if (owner == null || owner != _owner) return const SizedBox.shrink();
    if (rights.isLoading) return const AdminLoadingState();
    if (rights.hasError) {
      return AdminFailureState(
          error: rights.error!,
          retry: () => ref.invalidate(adminCapabilitiesProvider));
    }
    if (!rights.requireValue.has('admin.accounts.view')) {
      return const WorkflowEmpty('Bạn không có quyền xem tài khoản.');
    }
    return ref.watch(adminAccountDetailProvider(widget.accountId)).when(
        skipLoadingOnRefresh: false,
        loading: () => const AdminLoadingState(),
        error: (error, stack) => error is ApiFailure && error.statusCode == 404
            ? const WorkflowEmpty('Không tìm thấy tài khoản.')
            : AdminFailureState(error: error, retry: _reload),
        data: _content);
  }

  Widget _content(AdminAccountDetail detail) {
    final account = detail.account;
    final enabled = !_busy && !_conflict;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_busy) const LinearProgressIndicator(),
      if (_failure != null) ...[
        AdminFailureState(error: _failure!, retry: _reload),
        if (_conflict)
          TextButton(
              onPressed: _reload, child: const Text('Tải lại tài khoản')),
      ],
      AdminSectionPanel(
          icon: account.isActive
              ? Icons.verified_user_outlined
              : Icons.person_off_outlined,
          title: account.fullName,
          subtitle: '${const {
                'LANDLORD': 'Chủ trọ',
                'TENANT': 'Người thuê / người tìm phòng',
                'STAFF': 'Nhân viên'
              }[account.role] ?? account.role} · ${account.isActive ? 'Hoạt động' : 'Đã khóa'}',
          children: [
            SelectableText('ID: ${account.id}'),
            const SizedBox(height: 12),
            Text('Email: ${account.email}'),
            Text('Điện thoại: ${account.phone ?? 'Chưa cập nhật'}'),
            Text('Ngày tạo: ${workflowDate(account.createdAt)}'),
            Text(
                '${detail.properties} khu trọ · ${detail.tenants} hồ sơ người thuê'),
            if (detail.staffLandlordId != null)
              SelectableText('Chủ trọ quản lý: ${detail.staffLandlordId}'),
            if (detail.tenantProfileId != null)
              SelectableText('Hồ sơ người thuê: ${detail.tenantProfileId}'),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              if (_can('admin.accounts.suspend'))
                OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _run(
                            'admin.accounts.suspend',
                            account.isActive
                                ? 'Khóa tài khoản?'
                                : 'Mở lại tài khoản?',
                            account.isActive
                                ? 'Tài khoản sẽ bị đăng xuất. Nếu là chủ trọ, nhân viên phụ thuộc cũng mất quyền truy cập; hợp đồng và dữ liệu tài chính được giữ nguyên.'
                                : 'Tài khoản có thể đăng nhập lại. Các phiên đăng nhập cũ không được khôi phục.',
                            (reason) => ref
                                .read(adminApiProvider)
                                .updateAccountStatus(account.id,
                                    isActive: !account.isActive,
                                    version: account.version,
                                    reason: reason,
                                    prompt: () =>
                                        _stepUp('admin.accounts.suspend')))
                        : null,
                    icon: Icon(account.isActive
                        ? Icons.lock_outline
                        : Icons.lock_open),
                    label: Text(account.isActive
                        ? 'Khóa tài khoản'
                        : 'Mở lại tài khoản')),
              if (_can('admin.sessions.revoke'))
                OutlinedButton(
                    onPressed: enabled
                        ? () => _run(
                            'admin.sessions.revoke',
                            'Thu hồi tất cả phiên?',
                            'Người dùng cần đăng nhập lại trên mọi thiết bị.',
                            (reason) => ref
                                .read(adminApiProvider)
                                .revokeAccountSessions(account.id,
                                    reason: reason,
                                    prompt: () =>
                                        _stepUp('admin.sessions.revoke')))
                        : null,
                    child: const Text('Thu hồi phiên')),
              if (_can('admin.accounts.manage'))
                OutlinedButton(
                    onPressed: enabled && account.isActive
                        ? () => _run(
                                'admin.accounts.manage',
                                'Gửi hướng dẫn đặt lại mật khẩu?',
                                'Yêu cầu sẽ được đưa vào hàng đợi gửi. Không tạo hoặc hiển thị mật khẩu tại đây.',
                                (reason) async {
                              await ref
                                  .read(adminApiProvider)
                                  .resetAccountPassword(account.id,
                                      reason: reason,
                                      prompt: () =>
                                          _stepUp('admin.accounts.manage'));
                              return true;
                            })
                        : null,
                    child: const Text('Gửi reset mật khẩu')),
              if (_can('admin.pii.reveal'))
                OutlinedButton(
                    onPressed: enabled ? _reveal : null,
                    child: const Text('Xem liên hệ có ghi log')),
              if (_can('admin.support.read'))
                OutlinedButton(
                    onPressed: enabled
                        ? () => GoRouter.maybeOf(context)?.go(adminSupportRoute)
                        : null,
                    child: const Text('Tra cứu nghiệp vụ chỉ đọc')),
            ]),
          ]),
      const SizedBox(height: 20),
      AdminSectionPanel(
          icon: Icons.history_outlined,
          title: 'Lịch sử xử lý gần đây',
          children: [
            if (detail.history.isEmpty)
              const WorkflowEmpty('Chưa có lịch sử thao tác.'),
            for (final entry in detail.history)
              Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AdminOverviewTheme.background,
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.summary),
                        Text(
                            '${entry.action} · ${workflowDate(entry.createdAt)}'),
                      ])),
          ]),
    ]);
  }
}

class _PrivateContacts extends StatefulWidget {
  const _PrivateContacts({required this.contacts});
  final AdminAccountContacts contacts;
  @override
  State<_PrivateContacts> createState() => _PrivateContactsState();
}

class _PrivateContactsState extends State<_PrivateContacts>
    with WidgetsBindingObserver {
  bool _hidden = false;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _hidden = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      child: _hidden
          ? const Text('Thông tin đã được ẩn. Đóng và xác thực lại khi cần.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(widget.contacts.email),
                  Text(widget.contacts.phone ?? 'Chưa có số điện thoại')
                ]));
}
