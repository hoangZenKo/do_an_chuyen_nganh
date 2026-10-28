import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../models/property.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/dashboard_providers.dart';
import '../rooms/room_providers.dart';

class PropertiesListScreen extends ConsumerStatefulWidget {
  const PropertiesListScreen({super.key});

  @override
  ConsumerState<PropertiesListScreen> createState() =>
      _PropertiesListScreenState();
}

class _PropertiesListScreenState extends ConsumerState<PropertiesListScreen> {
  var _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(
      _showArchived ? archivedPropertiesProvider : propertiesProvider,
    );
    final selectedId = ref.watch(selectedPropertyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Khu trọ'),
        actions: [
          IconButton(
            onPressed: () => context.push(propertyFormRoute),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Thêm khu trọ',
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(propertyFormRoute),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm khu trọ'),
            ),
      body: Column(
        children: [
          _LifecycleFilterBar(
            showArchived: _showArchived,
            onChanged: (value) => setState(() => _showArchived = value),
          ),
          Expanded(
            child: propertiesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (error, _) => _PropertiesError(
                message: '$error',
                onRetry: () => ref.invalidate(
                  _showArchived
                      ? archivedPropertiesProvider
                      : propertiesProvider,
                ),
              ),
              data: (properties) {
                if (properties.isEmpty) {
                  return _EmptyProperties(
                    archived: _showArchived,
                    onCreate: () => context.push(propertyFormRoute),
                  );
                }
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async => ref.invalidate(
                    _showArchived
                        ? archivedPropertiesProvider
                        : propertiesProvider,
                  ),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: properties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final property = properties[index];
                      return _PropertyCard(
                        property: property,
                        selected: !_showArchived && property.id == selectedId,
                        onSelect: property.isArchived
                            ? null
                            : () {
                                ref
                                    .read(selectedPropertyProvider.notifier)
                                    .state = property.id;
                                ref.invalidate(dashboardMetricsProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã chọn ${property.name}'),
                                  ),
                                );
                              },
                        onEdit: property.isArchived
                            ? null
                            : () => context.push(
                                  propertyFormPath(propertyId: property.id),
                                ),
                        onArchive: () => _setArchived(property, true),
                        onRestore: () => _setArchived(property, false),
                        onDelete: () => _delete(property),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setArchived(Property property, bool isArchived) async {
    final confirmed = await _confirm(
      title: isArchived ? 'Archive khu trọ?' : 'Restore khu trọ?',
      message: isArchived
          ? 'Khu trọ sẽ bị ẩn khỏi danh sách vận hành. Bạn vẫn có thể xem và khôi phục từ mục Archived.'
          : 'Khu trọ sẽ quay lại danh sách vận hành.',
      confirmLabel: isArchived ? 'Archive' : 'Restore',
      destructive: isArchived,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(propertyFormControllerProvider.notifier).setArchived(
            propertyId: property.id,
            isArchived: isArchived,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArchived
                ? 'Đã archive ${property.name}'
                : 'Đã restore ${property.name}',
          ),
        ),
      );
    } catch (error) {
      _showError(error, 'Không thể cập nhật khu trọ.');
    }
  }

  Future<void> _delete(Property property) async {
    final confirmed = await _confirm(
      title: 'Xóa vĩnh viễn khu trọ?',
      message:
          'Chỉ xóa được khu trọ chưa có phòng. Nếu đã có dữ liệu liên quan, hãy dùng Archive để giữ lịch sử.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(propertyFormControllerProvider.notifier)
          .delete(property.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${property.name}')),
      );
    } catch (error) {
      _showError(error, 'Không thể xóa khu trọ.');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? const Color(0xFFEF4444) : AppTheme.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showError(Object error, String fallback) {
    if (!mounted) return;
    final message = error is ApiFailure ? error.message : fallback;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LifecycleFilterBar extends StatelessWidget {
  const _LifecycleFilterBar({
    required this.showArchived,
    required this.onChanged,
  });

  final bool showArchived;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _FilterPill(
            label: 'Đang quản lý',
            selected: !showArchived,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Archived',
            selected: showArchived,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.primary : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  final Property property;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: property.isArchived
                        ? const Color(0xFFF3F4F6)
                        : AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    property.isArchived
                        ? Icons.archive_outlined
                        : Icons.apartment_rounded,
                    color: property.isArchived
                        ? const Color(0xFF6B7280)
                        : AppTheme.primary,
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
                              property.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (property.isArchived) ...[
                            const SizedBox(width: 6),
                            const _ArchivedBadge(),
                          ] else if (selected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primary, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        property.address.trim().isEmpty
                            ? 'Chưa có địa chỉ'
                            : property.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'select') onSelect?.call();
                    if (value == 'archive') onArchive();
                    if (value == 'restore') onRestore();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (!property.isArchived) ...[
                      const PopupMenuItem(value: 'select', child: Text('Chọn')),
                      const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      const PopupMenuItem(
                          value: 'archive', child: Text('Archive')),
                    ] else
                      const PopupMenuItem(
                          value: 'restore', child: Text('Restore')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Xóa vĩnh viễn',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: '${property.roomCount} phòng'),
                _MetricChip(label: '${property.occupiedCount} đang thuê'),
                _MetricChip(label: '${property.vacantCount} trống'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Archived',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _EmptyProperties extends StatelessWidget {
  const _EmptyProperties({required this.archived, required this.onCreate});

  final bool archived;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived ? Icons.archive_outlined : Icons.apartment_rounded,
              size: 64,
              color: AppTheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              archived ? 'Chưa có khu trọ archived' : 'Chưa có khu trọ',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              archived
                  ? 'Khu trọ đã archive sẽ xuất hiện tại đây để bạn khôi phục khi cần.'
                  : 'Tạo khu trọ đầu tiên để bắt đầu quản lý phòng.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            if (!archived) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded),
                    SizedBox(width: 8),
                    Text('Tạo khu trọ'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertiesError extends StatelessWidget {
  const _PropertiesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
