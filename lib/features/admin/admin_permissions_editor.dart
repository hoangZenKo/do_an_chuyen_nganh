import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminPermissionsEditor extends ConsumerStatefulWidget {
  const AdminPermissionsEditor(
      {super.key, required this.userId, required this.fullName});

  final String userId;
  final String fullName;

  @override
  ConsumerState<AdminPermissionsEditor> createState() =>
      _AdminPermissionsEditorState();
}

class _AdminPermissionsEditorState
    extends ConsumerState<AdminPermissionsEditor> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _mfa = TextEditingController();
  late final String? _owner;
  String? _preset;
  Map<String, dynamic>? _snapshot;
  Set<String> _permissions = {};
  bool _isActive = true;
  bool _invalidated = false;

  static const _presets = {
    'super_admin': 'Super admin',
    'support': 'Hỗ trợ',
    'moderator': 'Kiểm duyệt',
    'analyst': 'Phân tích',
  };

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  @override
  void dispose() {
    _reason.dispose();
    _mfa.dispose();
    super.dispose();
  }

  List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionIdentityProvider);
    final capabilities = ref.watch(adminCapabilitiesProvider);
    final rights = capabilities.valueOrNull;
    if (identity != _owner ||
        (capabilities.hasValue && rights?.has('admin.admins.manage') != true)) {
      _invalidated = true;
    }
    final allowed = !_invalidated &&
        _owner != null &&
        identity == _owner &&
        widget.userId != _owner &&
        rights?.has('admin.admins.manage') == true;
    if (!allowed) {
      return AlertDialog(
        title: const Text('Không thể chỉnh sửa quyền'),
        content: const Text(
            'Phiên hoặc quyền quản trị đã thay đổi. Đóng và tải lại danh sách.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng')),
        ],
      );
    }
    final request = AdminRequest('/admin/admins/${widget.userId}/access');
    final access = ref.watch(adminResourceProvider(request));
    const catalogRequest = AdminRequest('/admin/permission-catalog');
    final catalog = ref.watch(adminResourceProvider(catalogRequest));
    final failure = access.error ?? catalog.error;
    final received = workflowData(access.valueOrNull ?? const {});
    final definitions = workflowData(catalog.valueOrNull ?? const {});
    final ready = !access.isLoading &&
        !catalog.isLoading &&
        failure == null &&
        received.isNotEmpty &&
        definitions.isNotEmpty;
    if (ready && _snapshot == null) _snapshot = received;
    final data = _snapshot ?? received;
    final oldDelegable = _strings(data['delegablePermissions']).toSet();
    final currentDelegable = _strings(received['delegablePermissions']).toSet();
    final conflict = ready &&
        (data['version'] != received['version'] ||
            data['canCustomizePermissions'] !=
                received['canCustomizePermissions'] ||
            oldDelegable.length != currentDelegable.length ||
            !oldDelegable.every(currentDelegable.contains));
    final customizable = data['canCustomizePermissions'] == true;
    final presets = definitions['presets'] as Map? ?? const {};
    final permissions = _strings(definitions['permissions']);
    final delegable = _strings(data['delegablePermissions']).toSet();
    if (ready && _preset == null) {
      _preset = data['preset'] as String;
      _permissions = _strings(data['permissions']).toSet();
      _isActive = data['isActive'] == true;
    }
    final presetPermissions = _strings(presets[_preset]).toSet();
    final added = _permissions.difference(presetPermissions).length;
    final removed = presetPermissions.difference(_permissions).length;
    final canSave = ready &&
        !conflict &&
        _permissions.every((permission) => rights!.has(permission)) &&
        (!customizable ||
            (_permissions.contains('admin.dashboard.view') &&
                _permissions.every(delegable.contains)));

    return AlertDialog(
      title: Text('Quyền của ${widget.fullName}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: !ready
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  if (failure == null) const CircularProgressIndicator(),
                  if (failure != null) ...[
                    const Text(
                        'Không tải được quyền hiện tại. Chưa thay đổi dữ liệu.'),
                    TextButton(
                        onPressed: () {
                          ref.invalidate(adminResourceProvider(request));
                          ref.invalidate(adminResourceProvider(catalogRequest));
                        },
                        child: const Text('Thử lại')),
                  ],
                ])
              : Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          'Lưu thay đổi sẽ thu hồi phiên của tài khoản này và yêu cầu rà soát quyền lại. Không tự động cấp các quyền mới.'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _preset,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Vai trò'),
                        items: _presets.entries
                            .map((entry) => DropdownMenuItem(
                                value: entry.key, child: Text(entry.value)))
                            .toList(),
                        onChanged: (value) => setState(() {
                          _preset = value;
                          _permissions = _strings(presets[value]).toSet();
                        }),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tài khoản hoạt động'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      Text('Quyền hiệu lực: ${_permissions.length}'),
                      Text('So với vai trò: thêm $added, bỏ $removed quyền.'),
                      if (conflict) ...[
                        const Text(
                            'Quyền đã thay đổi trong lúc chỉnh sửa. Tải bản mới trước khi lưu.'),
                        TextButton(
                            onPressed: () => setState(() {
                                  _snapshot = null;
                                  _preset = null;
                                  _mfa.clear();
                                  _reason.clear();
                                }),
                            child: const Text('Tải bản mới')),
                      ],
                      if (!customizable)
                        const Text(
                            'Chỉ super admin được tùy chỉnh từng quyền. Đổi vai trò sẽ áp dụng bộ quyền mặc định của vai trò.'),
                      for (final permission in permissions)
                        CheckboxListTile.adaptive(
                          key: ValueKey('grant:$permission'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(permission),
                          value: _permissions.contains(permission),
                          onChanged: !customizable ||
                                  _preset == 'super_admin' ||
                                  permission == 'admin.dashboard.view' ||
                                  (!delegable.contains(permission) &&
                                      !_permissions.contains(permission))
                              ? null
                              : (value) => setState(() {
                                    if (value == true) {
                                      _permissions.add(permission);
                                    } else {
                                      _permissions.remove(permission);
                                    }
                                  }),
                        ),
                      if (!canSave)
                        const Text(
                            'Bạn không có đủ quyền để cấp bộ quyền đã chọn. Chọn vai trò phù hợp hoặc tải lại sau khi được cấp quyền.'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mfa,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 64,
                        decoration: const InputDecoration(
                            labelText: 'Mã MFA mới hoặc mã khôi phục'),
                        validator: (value) => (value?.trim().length ?? 0) < 6
                            ? 'Nhập mã MFA hợp lệ.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reason,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration:
                            const InputDecoration(labelText: 'Lý do thay đổi'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Nhập lý do ít nhất 10 ký tự.'
                            : null,
                      ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: !canSave
              ? null
              : () {
                  if (ref.read(sessionIdentityProvider) != _owner ||
                      ref
                              .read(adminCapabilitiesProvider)
                              .valueOrNull
                              ?.has('admin.admins.manage') !=
                          true ||
                      !_form.currentState!.validate()) {
                    return;
                  }
                  Navigator.pop(context, <String, dynamic>{
                    'preset': _preset,
                    'isActive': _isActive,
                    'version': data['version'],
                    if (customizable) 'permissions': _permissions.toList(),
                    'mfaCode': _mfa.text.trim(),
                    'reason': _reason.text.trim(),
                  });
                },
          child: const Text('Lưu thay đổi'),
        ),
      ],
    );
  }
}
