import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/staff.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../tenants/widgets/form_widgets.dart';
import 'staff_providers.dart';
import 'staff_scope_screen.dart';
import '../rooms/room_providers.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final canManageStaff = session?.user.role == 'landlord' &&
        sessionHasPermission(session, 'staff.manage');
    final staffAsync = ref.watch(staffMembersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text('Nhân viên'),
        actions: [
          if (canManageStaff)
            IconButton(
              tooltip: 'Mời nhân viên',
              onPressed: () => _showStaffInviteDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => ref.invalidate(staffMembersProvider),
        child: staffAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [FormErrorBanner(message: '$error')],
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (items.isEmpty)
                const _EmptyStaffCard()
              else
                ...items.map((item) => _StaffCard(
                      staff: item,
                      canManageStaff: canManageStaff,
                    )),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: canManageStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showStaffInviteDialog(context, ref),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Mời nhân viên'),
            )
          : null,
    );
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.staff, required this.canManageStaff});

  final StaffMember staff;
  final bool canManageStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3348)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
                foregroundColor: AppTheme.primary,
                child: const Icon(Icons.badge_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF0F2FF),
                      ),
                    ),
                    Text(
                      staff.email ?? 'Chưa có email',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8891A8),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: staff.isActive,
                activeColor: AppTheme.primary,
                onChanged: canManageStaff
                    ? (value) async {
                        try {
                          await ref
                              .read(staffControllerProvider.notifier)
                              .setActive(staff.id, value);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$error')),
                            );
                          }
                        }
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                text: _presetLabel(staff.preset),
                color: const Color(0xFF2563EB),
              ),
              _Chip(
                text: staff.isActive ? 'Đang hoạt động' : 'Đã khóa',
                color: staff.isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
              _Chip(
                text: '${staff.permissions.length} quyền',
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${staff.propertyIds.length} khu trọ được cấp quyền'),
          if (canManageStaff)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => StaffScopeScreen(staff: staff),
              )),
              icon: const Icon(Icons.policy_outlined),
              label: const Text('Phạm vi / Kiểm tra quyền'),
            ),
          Text(
            'Tạo: ${formatDate(staff.createdAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyStaffCard extends StatelessWidget {
  const _EmptyStaffCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3348)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.group_add_rounded, color: AppTheme.primary),
          SizedBox(height: 10),
          Text(
            'Chưa có nhân viên',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Tạo mã mời để nhân viên tự kích hoạt tài khoản.',
            style: TextStyle(color: Color(0xFF8891A8)),
          ),
        ],
      ),
    );
  }
}

Future<void> _showStaffInviteDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final email = TextEditingController();
  final fullName = TextEditingController();
  final phone = TextEditingController();
  var preset = 'viewer';
  StaffInvite? invite;
  String? error;
  var loading = false;
  final propertyIds = <String>{};
  final properties = ref.read(propertiesProvider.future);

  final presets = await ref.read(staffPresetsProvider.future).catchError(
        (_) => const <StaffPreset>[],
      );
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(invite == null ? 'Mời nhân viên' : 'Mã kích hoạt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (invite == null) ...[
                TextField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Số điện thoại'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: preset,
                  items: (presets.isEmpty
                          ? const [
                              StaffPreset(
                                preset: 'viewer',
                                permissions: [],
                              ),
                              StaffPreset(
                                preset: 'accountant',
                                permissions: [],
                              ),
                              StaffPreset(
                                preset: 'maintenance',
                                permissions: [],
                              ),
                              StaffPreset(
                                preset: 'operator',
                                permissions: [],
                              ),
                            ]
                          : presets)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.preset,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: loading
                      ? null
                      : (value) => setState(() => preset = value ?? preset),
                  decoration: const InputDecoration(labelText: 'Nhóm quyền'),
                ),
                const SizedBox(height: 16),
                const Text('Khu trọ được cấp quyền'),
                FutureBuilder(
                  future: properties,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Không tải được khu trọ. Đóng và mở lại để thử lại.');
                    }
                    if (!snapshot.hasData) {
                      return const Padding(padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator());
                    }
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      if (snapshot.data!.isEmpty) const Text('Tạo khu trọ trước khi mời nhân viên.'),
                      for (final property in snapshot.data!)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(property.name),
                          value: propertyIds.contains(property.id),
                          onChanged: loading ? null : (value) => setState(() {
                            if (value == true) { propertyIds.add(property.id); }
                            else { propertyIds.remove(property.id); }
                          }),
                        ),
                    ]);
                  },
                ),
              ] else ...[
                _CopyRow(label: 'Mã kích hoạt', value: invite!.inviteCode ?? ''),
                const SizedBox(height: 10),
                _CopyRow(
                  label: 'Link kích hoạt',
                  value: invite!.activationPath ?? '',
                ),
                const SizedBox(height: 10),
                Text(
                  'Hết hạn: ${formatDate(invite!.expiresAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8891A8),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : () => Navigator.pop(dialogContext),
            child: Text(invite == null ? 'Hủy' : 'Đóng'),
          ),
          if (invite == null)
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (fullName.text.trim().isEmpty ||
                          email.text.trim().isEmpty) {
                        setState(() => error = 'Nhập họ tên và email.');
                        return;
                      }
                      if (propertyIds.isEmpty) {
                        setState(() => error = 'Chọn ít nhất một khu trọ cho nhân viên.');
                        return;
                      }
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        final created = await ref
                            .read(staffControllerProvider.notifier)
                            .createInvite(
                              email: email.text,
                              fullName: fullName.text,
                              phone: phone.text,
                              preset: preset,
                              propertyIds: propertyIds.toList(),
                            );
                        setState(() {
                          invite = created;
                          loading = false;
                        });
                      } catch (err) {
                        setState(() {
                          loading = false;
                          error = err is ApiFailure
                              ? err.message
                              : 'Không tạo được mã mời.';
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tạo mã'),
            ),
        ],
      ),
    ),
  );

  email.dispose();
  fullName.dispose();
  phone.dispose();
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF22263A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3348)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8891A8)),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: value.isEmpty
                ? null
                : () => Clipboard.setData(ClipboardData(text: value)),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

String _presetLabel(String? preset) {
  return switch (preset) {
    'operator' => 'Vận hành',
    'accountant' => 'Kế toán',
    'maintenance' => 'Bảo trì',
    'viewer' => 'Chỉ xem',
    'custom' => 'Tùy chỉnh',
    _ => 'Chưa đặt nhóm',
  };
}
