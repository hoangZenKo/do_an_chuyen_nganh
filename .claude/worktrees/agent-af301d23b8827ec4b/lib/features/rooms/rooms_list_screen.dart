import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import 'room_providers.dart';
import 'widgets/room_image.dart';

/// Rooms tab: property header, lifecycle/status filters, and the room list for
/// the selected property. Operational lists hide inactive rooms by default.
class RoomsListScreen extends ConsumerStatefulWidget {
  const RoomsListScreen({super.key});

  @override
  ConsumerState<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends ConsumerState<RoomsListScreen> {
  RoomStatus? _filter;
  var _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final selectedId = ref.watch(selectedPropertyProvider);

    return SafeArea(
      bottom: false,
      child: propertiesAsync.when(
        loading: () => const _CenteredLoader(),
        error: (error, _) => _CenteredError(
          message: '$error',
          onRetry: () => ref.invalidate(propertiesProvider),
        ),
        data: (properties) {
          if (properties.isEmpty) {
            return _EmptyState(
              icon: Icons.apartment_rounded,
              title: 'Chưa có khu trọ',
              message: 'Tạo khu trọ để bắt đầu quản lý phòng.',
              actionLabel: 'Tạo khu trọ',
              onAction: () => context.push(propertyFormRoute),
            );
          }
          final property = properties.firstWhere(
            (p) => p.id == selectedId,
            orElse: () => properties.first,
          );
          return Column(
            children: [
              _PropertyHeader(
                property: property,
                properties: properties,
                onSelect: (id) {
                  ref.read(selectedPropertyProvider.notifier).state = id;
                  setState(() {
                    _filter = null;
                    _showInactive = false;
                  });
                },
              ),
              _LifecycleFilterBar(
                showInactive: _showInactive,
                onChanged: (value) => setState(() => _showInactive = value),
              ),
              if (!_showInactive)
                _StatusFilterBar(
                  selected: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
              Expanded(
                child: _RoomsList(
                  propertyId: property.id,
                  filter: _showInactive ? null : _filter,
                  showInactive: _showInactive,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoomsList extends ConsumerWidget {
  const _RoomsList({
    required this.propertyId,
    required this.filter,
    required this.showInactive,
  });

  final String propertyId;
  final RoomStatus? filter;
  final bool showInactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = showInactive
        ? inactiveRoomsProvider(propertyId)
        : roomsProvider(propertyId);
    final roomsAsync = ref.watch(provider);
    return roomsAsync.when(
      loading: () => const _CenteredLoader(),
      error: (error, _) => _CenteredError(
        message: '$error',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rooms) {
        final visible = filter == null
            ? rooms
            : rooms.where((r) => r.status == filter).toList(growable: false);
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(provider),
          child: visible.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    _EmptyState(
                      icon: showInactive
                          ? Icons.unpublished_outlined
                          : Icons.meeting_room_outlined,
                      title: showInactive
                          ? 'Không có phòng ngưng sử dụng'
                          : 'Không có phòng',
                      message: showInactive
                          ? 'Phòng đã ngưng sử dụng sẽ xuất hiện ở đây để khôi phục.'
                          : 'Chưa có phòng nào khớp bộ lọc này.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RoomCard(room: visible[i]),
                ),
        );
      },
    );
  }
}

// ── Property header ───────────────────────────────────────────────────────────

class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({
    required this.property,
    required this.properties,
    required this.onSelect,
  });

  final Property property;
  final List<Property> properties;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (properties.length > 1)
                  _PropertyPicker(
                    property: property,
                    properties: properties,
                    onSelect: onSelect,
                  )
                else
                  Text(
                    property.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${property.roomCount} phòng · ${property.occupiedCount} đang thuê · '
                  '${property.vacantCount} trống',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyPicker extends StatelessWidget {
  const _PropertyPicker({
    required this.property,
    required this.properties,
    required this.onSelect,
  });

  final Property property;
  final List<Property> properties;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      itemBuilder: (_) => properties
          .map((p) => PopupMenuItem(value: p.id, child: Text(p.name)))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              property.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }
}

// ── Filters ───────────────────────────────────────────────────────────────────

class _LifecycleFilterBar extends StatelessWidget {
  const _LifecycleFilterBar({
    required this.showInactive,
    required this.onChanged,
  });

  final bool showInactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _FilterChip(
            label: 'Đang sử dụng',
            color: AppTheme.primary,
            selected: !showInactive,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Ngưng sử dụng',
            color: const Color(0xFF6B7280),
            selected: showInactive,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onChanged});

  final RoomStatus? selected;
  final ValueChanged<RoomStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'Tất cả',
            color: AppTheme.primary,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          for (final status in RoomStatus.values) ...[
            _FilterChip(
              label: status.label,
              color: status.color,
              selected: selected == status,
              onTap: () => onChanged(status),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? color : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── Room card ─────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(roomDetailPath(room.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 84,
                height: 84,
                child: RoomImageView(
                  source: RoomImageCatalog.imageFor(room),
                  placeholder: _RoomThumbnailPlaceholder(room: room),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          room.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: room.status),
                      if (!room.isActive) ...[
                        const SizedBox(width: 6),
                        const _InactiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.tenantName != null
                        ? 'Khách: ${room.tenantName}'
                        : [
                            if (room.floor != null) 'Tầng ${room.floor}',
                            formatArea(room.areaSqm),
                          ].join(' · '),
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrencyVnd(room.basePrice),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }
}

class _RoomThumbnailPlaceholder extends StatelessWidget {
  const _RoomThumbnailPlaceholder({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: room.status.color.withValues(alpha: 0.12),
      child: Icon(
        Icons.meeting_room_rounded,
        color: room.status.color,
        size: 30,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RoomStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ── Shared state widgets ──────────────────────────────────────────────────────

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
}

class _CenteredError extends StatelessWidget {
  const _CenteredError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Thử lại',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64, color: AppTheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
