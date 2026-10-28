import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/landlord_notification.dart';
import '../auth/auth_navigation.dart';
import 'operations_providers.dart';

class ActionItemsDashboardCard extends ConsumerWidget {
  const ActionItemsDashboardCard({super.key, this.propertyId});

  final String? propertyId;

  Future<void> _open(BuildContext context, WidgetRef ref, String route,
      [LandlordNotification? item]) async {
    if (item != null) {
      try {
        await markActionRead(ref, item);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa lưu được trạng thái đã đọc.'),
          ));
        }
      }
    }
    if (!context.mounted) return;
    await context.push(route);
    if (context.mounted) ref.invalidate(actionItemsProvider);
  }

  String _routeFor({String? category}) {
    final params = <String, String>{
      if (propertyId != null) 'propertyId': propertyId!,
      if (category != null && category != 'all') 'category': category,
    };
    return Uri(
      path: actionItemsRoute,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ActionItemsQuery(limit: 3, propertyId: propertyId);
    final items = ref.watch(actionItemsProvider(query));
    final route = _routeFor();

    final totalCount = items.valueOrNull?.summary.total;
    final subtitleText = items.when(
      data: (data) =>
          '${data.summary.total} việc · ${data.summary.unread} chưa đọc',
      loading: () => 'Đang tổng hợp công việc…',
      error: (_, __) => 'Chưa tải được danh sách',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section Header (matching Demo v3 `.sec`) ────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context, ref, route),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Text(
                  'Việc cần xử lý',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (totalCount != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$totalCount',
                    style: const TextStyle(
                      color: Color(0xFFFF6B1A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Xem hết',
                  style: TextStyle(
                    color: Color(0xFFFF6B1A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Tasks Strip & Live Preview ──────────────────────────────────────
        items.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.invalidate(actionItemsProvider(query)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
          data: (data) {
            final s = data.summary;
            final tiles = <_ActionCategorySpec>[
              _ActionCategorySpec(
                category: 'invoice',
                count: s.overdueInvoices,
                label: 'Hóa đơn quá hạn',
                icon: Icons.access_time_rounded,
                isHot: s.overdueInvoices > 0,
              ),
              _ActionCategorySpec(
                category: 'payment',
                count: s.pendingPaymentProofs,
                label: 'Chứng từ chờ duyệt',
                icon: Icons.description_outlined,
                isHot: false,
              ),
              _ActionCategorySpec(
                category: 'viewing',
                count: s.pendingViewings,
                label: 'Lịch xem chờ xác nhận',
                icon: Icons.calendar_today_rounded,
                isHot: false,
              ),
              _ActionCategorySpec(
                category: 'maintenance',
                count: s.openMaintenance,
                label: 'Yêu cầu sửa chữa',
                icon: Icons.handyman_outlined,
                isHot: s.urgentMaintenance > 0 || s.openMaintenance > 0,
              ),
              _ActionCategorySpec(
                category: 'lease',
                count: s.expiringLeases,
                label: 'Hợp đồng sắp hết hạn',
                icon: Icons.bookmark_border_rounded,
                isHot: false,
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Demo v3 `.tasks` strip: 5 standalone cards
                    if (constraints.maxWidth >= 620) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < tiles.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _ActionSummaryTile(
                                spec: tiles[i],
                                onTap: () => _open(
                                  context,
                                  ref,
                                  _routeFor(category: tiles[i].category),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    // Balanced 2-row layout on mobile: 3 cards on top row, 2 wider cards on bottom row
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ActionSummaryTile(
                                spec: tiles[0],
                                onTap: () => _open(
                                  context,
                                  ref,
                                  _routeFor(category: tiles[0].category),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionSummaryTile(
                                spec: tiles[1],
                                onTap: () => _open(
                                  context,
                                  ref,
                                  _routeFor(category: tiles[1].category),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionSummaryTile(
                                spec: tiles[2],
                                onTap: () => _open(
                                  context,
                                  ref,
                                  _routeFor(category: tiles[2].category),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ActionSummaryTile(
                                spec: tiles[3],
                                onTap: () => _open(
                                  context,
                                  ref,
                                  _routeFor(category: tiles[3].category),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionSummaryTile(
                                spec: tiles[4],
                                onTap: () => _open(
                                  context,
                                  ref,
                                  _routeFor(category: tiles[4].category),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                if (data.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < data.items.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFE6EAF0)),
                          _DashboardActionItemRow(
                            item: data.items[i],
                            onTap: () => _open(
                              context,
                              ref,
                              data.items[i].actionRoute,
                              data.items[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardActionItemRow extends StatelessWidget {
  const _DashboardActionItemRow({
    required this.item,
    required this.onTap,
  });

  final LandlordNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _categoryPalette(item.category);
    final roomCode = _extractRoomCode(item.title, item.body);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: palette.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    roomCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    palette.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.foreground.withValues(alpha: 0.88),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: palette.color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.north_east_rounded,
                size: 15,
                color: palette.color == const Color(0xFFFFC22E)
                    ? const Color(0xFFB45309)
                    : palette.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({Color color, Color foreground, String shortLabel}) _categoryPalette(
    String category) {
  return switch (category) {
    'invoice' => (
        color: const Color(0xFFFF5C4D),
        foreground: const Color(0xFF0B1220),
        shortLabel: 'Quá hạn',
      ),
    'payment' => (
        color: const Color(0xFF4F6BFF),
        foreground: Colors.white,
        shortLabel: 'Chứng từ',
      ),
    'viewing' => (
        color: const Color(0xFF19D3B0),
        foreground: const Color(0xFF0B1220),
        shortLabel: 'Lịch xem',
      ),
    'maintenance' => (
        color: const Color(0xFFFFC22E),
        foreground: const Color(0xFF0B1220),
        shortLabel: 'Sửa chữa',
      ),
    'lease' => (
        color: const Color(0xFFA66BFF),
        foreground: const Color(0xFF0B1220),
        shortLabel: 'Hợp đồng',
      ),
    _ => (
        color: const Color(0xFFFF6B1A),
        foreground: const Color(0xFF0B1220),
        shortLabel: 'Cần làm',
      ),
  };
}

String _extractRoomCode(String title, String body) {
  final combined = '$title $body';
  final match =
      RegExp(r'(?:Phòng|P\.?|Room)\s*([A-Za-z]?\d{2,4})', caseSensitive: false)
          .firstMatch(combined);
  if (match != null) return match.group(1)!.toUpperCase();
  final codeMatch = RegExp(r'\b([A-Za-z]\d{2,3}|\d{3})\b').firstMatch(combined);
  if (codeMatch != null) return codeMatch.group(1)!.toUpperCase();
  return 'P--';
}

class _ActionCategorySpec {
  const _ActionCategorySpec({
    required this.category,
    required this.count,
    required this.label,
    required this.icon,
    required this.isHot,
  });

  final String category;
  final int count;
  final String label;
  final IconData icon;
  final bool isHot;
}

class _ActionSummaryTile extends StatelessWidget {
  const _ActionSummaryTile({
    required this.spec,
    required this.onTap,
  });

  final _ActionCategorySpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isHot = spec.isHot;
    return Material(
      color: isHot ? const Color(0xFFFFF7F2) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isHot ? const Color(0xFFFBD3C0) : const Color(0xFFE6EAF0),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isHot
                        ? const Color(0xFFFF6B1A)
                        : const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    spec.icon,
                    size: 17,
                    color: isHot ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${spec.count}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.7,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 30,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      spec.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
