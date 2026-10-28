import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';

class AdminSecurityScreen extends ConsumerStatefulWidget {
  const AdminSecurityScreen({super.key});
  @override
  ConsumerState<AdminSecurityScreen> createState() =>
      _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends ConsumerState<AdminSecurityScreen> {
  final _code = TextEditingController();
  String? _owner, _secret, _uri, _error;
  List<String> _recovery = const [];
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  Future<void> _enroll() async {
    if (!_active || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref.read(adminApiProvider).enrollMfa();
      if (!_active) return;
      final data = response['data'] as Map;
      setState(() {
        _secret = data['secret'] as String;
        _uri = data['uri'] as String;
      });
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_active || _busy || _code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(adminApiProvider).confirmMfa(_code.text.trim());
      if (!_active) return;
      setState(() {
        _recovery =
            ((response['data'] as Map)['recoveryCodes'] as List).cast<String>();
        _secret = null;
        _uri = null;
        _code.clear();
      });
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionIdentityProvider) != _owner || _owner == null) {
      return const Scaffold(
          body: Center(child: Text('Phiên đăng nhập đã thay đổi.')));
    }
    final status = _recovery.isEmpty
        ? ref.watch(
            adminResourceProvider(const AdminRequest('/admin/me/security')))
        : null;
    return AdminWorkspaceScaffold(
        title: 'Bảo mật admin',
        location: '/admin/security',
        busy: _busy,
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminSectionPanel(
                            title: 'Xác thực hai lớp',
                            subtitle:
                                'Sử dụng ứng dụng xác thực TOTP. Không chia sẻ mã QR, khóa thiết lập hoặc mã khôi phục.',
                            icon: Icons.security_outlined,
                            trailing: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => context.push(adminSessionsRoute),
                                icon: const Icon(Icons.devices_outlined),
                                label: const Text('Thiết bị đăng nhập')),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_busy) ...[
                                  const LinearProgressIndicator(),
                                  const SizedBox(height: 16),
                                ],
                                if (_error != null)
                                  Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            AdminOverviewTheme.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AdminOverviewTheme.red
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                                if (_recovery.isNotEmpty) ...[
                                  const Text(
                                      'MFA đã bật. Mọi phiên cũ đã được thu hồi. Lưu 8 mã khôi phục dưới đây trước khi đăng nhập lại; mỗi mã chỉ dùng một lần.'),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AdminOverviewTheme.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AdminOverviewTheme.line),
                                    ),
                                    child: SelectableText(
                                      _recovery.join('\n'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.6,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                      onPressed: () async {
                                        await ref
                                            .read(sessionControllerProvider
                                                .notifier)
                                            .logout();
                                      },
                                      child: const Text(
                                          'Đã lưu mã — đăng nhập lại')),
                                ] else if (status != null)
                                  status.when(
                                      loading: () =>
                                          const CircularProgressIndicator(),
                                      error: (error, _) => Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('$error'),
                                                TextButton(
                                                    onPressed: () => ref.invalidate(
                                                        adminResourceProvider(
                                                            const AdminRequest(
                                                                '/admin/me/security'))),
                                                    child:
                                                        const Text('Thử lại'))
                                              ]),
                                      data: (response) {
                                        final data = response['data'] as Map;
                                        if (data['mfaEnabled'] == true) {
                                          return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    AdminStatusBadge.fromStatus(
                                                        'ACTIVE'),
                                                    const SizedBox(width: 10),
                                                    const Expanded(
                                                      child: Text(
                                                          'MFA đang bật. Mã khôi phục không được hiển thị lại.'),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                if (data['verified'] == true)
                                                  OutlinedButton(
                                                      onPressed: () => context
                                                          .go(adminRoute),
                                                      child: const Text(
                                                          'Về trang quản trị'))
                                                else
                                                  OutlinedButton(
                                                      onPressed: () => ref
                                                          .read(
                                                              sessionControllerProvider
                                                                  .notifier)
                                                          .logout(),
                                                      child: const Text(
                                                          'Đăng nhập lại với MFA'))
                                              ]);
                                        }
                                        return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(data['mfaRequired'] == true
                                                  ? 'Cần bật MFA trước khi dùng Admin Console.'
                                                  : 'Môi trường local chưa bắt buộc MFA. Sau khi bật, mọi lần đăng nhập đều cần mã xác thực.'),
                                              const SizedBox(height: 16),
                                              if (_secret == null)
                                                FilledButton(
                                                    onPressed:
                                                        _busy ? null : _enroll,
                                                    child: const Text(
                                                        'Thiết lập MFA'))
                                              else ...[
                                                if (_uri != null)
                                                  Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      child: QrImageView(
                                                          data: _uri!,
                                                          size: 220)),
                                                const SizedBox(height: 16),
                                                const Text(
                                                    'Hoặc nhập khóa thủ công trong ứng dụng xác thực:'),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: AdminOverviewTheme
                                                        .background,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color:
                                                            AdminOverviewTheme
                                                                .line),
                                                  ),
                                                  child:
                                                      SelectableText(_secret!),
                                                ),
                                                const SizedBox(height: 20),
                                                TextField(
                                                    controller: _code,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    maxLength: 6,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Mã xác thực 6 chữ số'),
                                                    onChanged: (_) =>
                                                        setState(() {})),
                                                const SizedBox(height: 8),
                                                FilledButton(
                                                    onPressed: _busy ||
                                                            _code.text
                                                                    .trim()
                                                                    .length !=
                                                                6
                                                        ? null
                                                        : _confirm,
                                                    child: const Text(
                                                        'Xác nhận và bật MFA')),
                                              ],
                                            ]);
                                      }),
                              ],
                            ),
                          ),
                        ])))));
  }
}
