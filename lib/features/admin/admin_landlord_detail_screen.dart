import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_step_up.dart';
import 'admin_workspace_scaffold.dart';

class AdminLandlordDetailScreen extends ConsumerWidget {
  const AdminLandlordDetailScreen({super.key, required this.landlordId});

  final String landlordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rights = ref.watch(adminCapabilitiesProvider);
    if (rights.isLoading ||
        rights.hasError ||
        !rights.requireValue.has('admin.accounts.manage')) {
      return AdminWorkspaceScaffold(
          title: 'Chi tiết chủ trọ',
          location: adminLandlordDetailPath(landlordId),
          canOpen: false,
          body: const SizedBox.shrink());
    }
    final detailAsync = ref.watch(adminLandlordDetailProvider(landlordId));
    final statusAsync = ref.watch(adminLandlordStatusControllerProvider);

    return AdminWorkspaceScaffold(
      title: 'Chi tiết chủ trọ',
      location: adminLandlordDetailPath(landlordId),
      onRefresh: () => ref.invalidate(adminLandlordDetailProvider(landlordId)),
      body: detailAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AdminOverviewTheme.blue)),
        error: (error, _) => Center(child: Text('$error')),
        data: (landlord) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(landlord.fullName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(landlord.email),
                  Text(landlord.phone ?? '—'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (rights.requireValue.has('admin.verifications.view') &&
                          rights.requireValue.has('admin.support.read'))
                        OutlinedButton(
                            onPressed: () =>
                                context.go(adminVerificationsRoute),
                            child: const Text('Hồ sơ xác minh')),
                      _Tag('${landlord.propertyCount} khu trọ'),
                      _Tag('${landlord.roomCount} phòng'),
                      _Tag('${landlord.activeLeaseCount} hợp đồng đang thuê'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push(
                            adminLandlordFormPath(landlordId: landlord.id)),
                        child: const Text('Chỉnh sửa'),
                      ),
                      if (rights.requireValue.has('admin.properties.manage'))
                        OutlinedButton(
                          onPressed: () => context.push(
                              adminPropertyFormPath(landlordId: landlord.id)),
                          child: const Text('Thêm khu trọ'),
                        ),
                      if (rights.requireValue.has('admin.accounts.suspend'))
                        OutlinedButton(
                          onPressed: statusAsync.isLoading
                              ? null
                              : () => _confirmStatusChange(
                                  context,
                                  ref,
                                  landlord.id,
                                  landlord.isActive,
                                  landlord.version),
                          child: statusAsync.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(landlord.isActive
                                  ? 'Khóa tài khoản'
                                  : 'Mở khóa tài khoản'),
                        ),
                    ],
                  ),
                  if (statusAsync.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${statusAsync.error}',
                      style: const TextStyle(color: AdminOverviewTheme.red),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Khu trọ gần đây',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...landlord.recentProperties.map(
              (property) => Card(
                child: ListTile(
                  onTap: () =>
                      context.push(adminPropertyDetailPath(property.id)),
                  title: Text(property.name),
                  subtitle: Text(property.address),
                  trailing: Text('${property.roomCount} phòng'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref,
    String landlordId,
    bool isActive,
    int version,
  ) async {
    final nextActive = !isActive;
    final owner = ref.read(sessionIdentityProvider);
    final formKey = GlobalKey<FormState>();
    String reason = '';
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextActive ? 'Mở khóa chủ trọ?' : 'Khóa chủ trọ?'),
        content: SingleChildScrollView(
            child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nextActive
                        ? 'Chủ trọ sẽ có thể sử dụng lại các chức năng quản lý.'
                        : 'Chủ trọ sẽ không thể truy cập các chức năng quản lý.'),
                    const SizedBox(height: 16),
                    TextFormField(
                        maxLength: 1000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Lý do (ghi vào audit)'),
                        onChanged: (value) => reason = value.trim(),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Nhập lý do tối thiểu 10 ký tự.'
                            : null),
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, reason);
              }
            },
            child: Text(nextActive ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
          ),
        ],
      ),
    );
    if (!context.mounted ||
        confirmed == null ||
        owner == null ||
        ref.read(sessionIdentityProvider) != owner) {
      return;
    }
    try {
      await ref.read(adminLandlordStatusControllerProvider.notifier).submit(
          landlordId: landlordId,
          isActive: nextActive,
          reason: confirmed,
          version: version,
          prompt: () => promptAdminStepUp(
              context,
              () =>
                  context.mounted &&
                  ref.read(sessionIdentityProvider) == owner));
    } catch (_) {
      // Provider state renders the error message.
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
