import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/audit_log.dart';
import 'audit_providers.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(title: const Text('Lịch sử hoạt động')),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => ref.invalidate(auditLogsProvider),
        child: logsAsync.when(
          loading: () => const _AuditLoading(),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [_AuditCard(child: Text('$error'))],
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _AuditCard(child: Text('Chưa có lịch sử hoạt động.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _AuditTile(log: logs[index]),
            );
          },
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final actor = log.actor;
    final actorName = actor?.fullName.trim().isNotEmpty == true
        ? actor!.fullName
        : _roleLabel(log.actorRole);
    final actorEmail = actor?.email ?? '';

    return _AuditCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _actionColor(log.action).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _actionIcon(log.action),
              color: _actionColor(log.action),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _actionLabel(log.action),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF0F2FF),
                        ),
                      ),
                    ),
                    Text(
                      _formatDateTime(log.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8891A8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.summary,
                  style: const TextStyle(color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Tag(Icons.person_rounded, actorName),
                    if (actorEmail.isNotEmpty)
                      _Tag(Icons.mail_outline_rounded, actorEmail),
                    _Tag(Icons.category_rounded, _resourceLabel(log.resourceType)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLoading extends StatelessWidget {
  const _AuditLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _AuditCard(
        child: SizedBox(height: 72),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22263A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8891A8)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm ${formatDate(local)}';
}

String _roleLabel(String role) => switch (role.toLowerCase()) {
      'staff' => 'Nhân viên',
      'admin' => 'Admin',
      'tenant' => 'Tenant',
      _ => 'Chủ trọ',
    };

String _resourceLabel(String value) => switch (value) {
      'property' => 'Khu trọ',
      'room' => 'Phòng',
      'tenant' => 'Tenant',
      'lease' => 'Hợp đồng',
      'invoice' => 'Hóa đơn',
      'meter_reading' => 'Chỉ số',
      'payment_proof' => 'Bằng chứng TT',
      'expense' => 'Chi phí',
      'maintenance_ticket' => 'Bảo trì',
      'staff_invite' => 'Mời nhân viên',
      'staff_profile' => 'Nhân viên',
      _ => value,
    };

String _actionLabel(String action) {
  final parts = action.split('.');
  final verb = parts.isNotEmpty ? parts.last : action;
  return switch (verb) {
    'create' => 'Tạo mới',
    'update' => 'Cập nhật',
    'delete' => 'Xóa',
    'end' => 'Kết thúc',
    'renew' => 'Gia hạn',
    'status_update' => 'Đổi trạng thái',
    'account_create' => 'Tạo tài khoản',
    'invite_create' => 'Tạo lời mời',
    'invoice_create' => 'Tạo hóa đơn',
    'invoice_bulk_create' => 'Tạo hóa đơn hàng loạt',
    'invoice_cancel' => 'Hủy hóa đơn',
    'payment_record' => 'Ghi nhận thanh toán',
    'payment_reverse' => 'Đảo thanh toán',
    'payment_proof_review' => 'Duyệt thanh toán',
    'complete' => 'Hoàn tất',
    'comment_create' => 'Thêm bình luận',
    _ => action,
  };
}

IconData _actionIcon(String action) {
  if (action.contains('delete') || action.contains('cancel')) {
    return Icons.delete_outline_rounded;
  }
  if (action.contains('payment') || action.contains('invoice')) {
    return Icons.payments_rounded;
  }
  if (action.contains('staff')) return Icons.groups_rounded;
  if (action.contains('maintenance')) return Icons.construction_rounded;
  return Icons.history_rounded;
}

Color _actionColor(String action) {
  if (action.contains('delete') || action.contains('cancel')) {
    return const Color(0xFFDC2626);
  }
  if (action.contains('payment') || action.contains('invoice')) {
    return const Color(0xFF059669);
  }
  if (action.contains('staff')) return const Color(0xFF7C3AED);
  if (action.contains('maintenance')) return const Color(0xFF2563EB);
  return AppTheme.primary;
}
