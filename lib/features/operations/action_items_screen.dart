import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/landlord_notification.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../rooms/room_providers.dart';
import 'operations_providers.dart';

class ActionItemsScreen extends ConsumerStatefulWidget {
  const ActionItemsScreen({
    super.key,
    this.propertyId,
    this.initialCategory,
  });

  final String? propertyId;
  final String? initialCategory;

  @override
  ConsumerState<ActionItemsScreen> createState() => _ActionItemsScreenState();
}

class _ActionItemsScreenState extends ConsumerState<ActionItemsScreen> {
  static const _pageSize = 12;
  String _category = 'all';
  int _page = 1;
  String? _propertyId;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _propertyId = widget.propertyId;
    final initial = widget.initialCategory?.trim();
    if (initial != null && initial.isNotEmpty) {
      _category = initial;
    }
  }

  ActionItemsQuery get _query => ActionItemsQuery(
        page: _page,
        limit: _pageSize,
        category: _category,
        propertyId: _propertyId,
      );

  void _setCategory(String category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _page = 1;
    });
  }

  Future<void> _openItem(LandlordNotification item) async {
    if (_openingId != null || item.actionRoute.isEmpty) return;
    setState(() => _openingId = item.id);
    try {
      await markActionRead(ref, item);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Chưa lưu được trạng thái đã đọc. Bạn vẫn có thể xử lý công việc.'),
        ));
      }
    }
    if (!mounted) return;
    await context.push(item.actionRoute);
    if (mounted) {
      setState(() => _openingId = null);
      ref.invalidate(actionItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(actionItemsProvider(_query));
    final session = ref.watch(sessionControllerProvider).session;
    final properties = sessionHasAnyPermission(
            session, const ['property.view', 'property.manage'])
        ? ref.watch(propertiesProvider).valueOrNull
        : null;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF4F6FB),
        title: const Text(
          'Việc cần xử lý',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
              tooltip: 'Checklist và lịch định kỳ',
              onPressed: () => context.push('$p1OperationsRoute?section=tasks'),
              icon: const Icon(Icons.checklist_rounded)),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => ref.invalidate(actionItemsProvider(_query)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF19D3B0),
        backgroundColor: const Color(0xFF151D30),
        onRefresh: () => ref.refresh(actionItemsProvider(_query).future),
        child: itemsAsync.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(actionItemsProvider(_query)),
          ),
          data: (data) => _ActionItemsContent(
            data: data,
            category: _category,
            page: _page,
            onCategoryChanged: _setCategory,
            onItemTap: _openItem,
            openingId: _openingId,
            propertyFilter: properties == null
                ? null
                : DropdownButtonFormField<String>(
                    value:
                        properties.any((property) => property.id == _propertyId)
                            ? _propertyId
                            : '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Khu trọ'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Tất cả khu trọ')),
                      ...properties.map((property) => DropdownMenuItem(
                          value: property.id,
                          child: Text(property.name,
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (value) => setState(() {
                      _propertyId =
                          value == null || value.isEmpty ? null : value;
                      _page = 1;
                    }),
                  ),
            onPreviousPage:
                _page == 1 ? null : () => setState(() => _page -= 1),
            onNextPage:
                data.meta.hasNext ? () => setState(() => _page += 1) : null,
          ),
        ),
      ),
    );
  }
}

class _ActionItemsContent extends StatelessWidget {
  const _ActionItemsContent({
    required this.data,
    required this.category,
    required this.page,
    required this.onCategoryChanged,
    required this.onItemTap,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.openingId,
    this.propertyFilter,
  });

  final ActionItems data;
  final String category;
  final int page;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<LandlordNotification> onItemTap;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final String? openingId;
  final Widget? propertyFilter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (propertyFilter != null) ...[
          propertyFilter!,
          const SizedBox(height: 16)
        ],
        _SummaryGrid(
          summary: data.summary,
          onSelectCategory: onCategoryChanged,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B1A),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'DANH SÁCH CÔNG VIỆC',
                style: TextStyle(
                  color: Color(0xFF0B1220),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Text(
              '${data.items.length} mục trang này',
              style: const TextStyle(
                color: Color(0xFF9AA6C2),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CategoryFilter(
          selected: category,
          summary: data.summary,
          onChanged: onCategoryChanged,
          categories: data.categories,
        ),
        const SizedBox(height: 14),
        if (data.items.isEmpty)
          const _EmptyState()
        else
          ...data.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActionRow(
                  item: item,
                  onTap: openingId == null ? () => onItemTap(item) : null),
            ),
          ),
        if (data.meta.total > 0 || page > 1) ...[
          const SizedBox(height: 4),
          _Pagination(
            page: page,
            total: data.meta.total,
            limit: data.meta.limit,
            onPrevious: onPreviousPage,
            onNext: onNextPage,
          ),
        ],
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.onSelectCategory,
  });

  final ActionItemsSummary summary;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final urgentCount = summary.overdueInvoices + summary.urgentMaintenance;
    final bentoTiles = <_BentoTileSpec>[
      _BentoTileSpec(
        category: 'invoice',
        label: 'Hóa đơn quá hạn',
        count: summary.overdueInvoices,
        bgColor: const Color(0xFFFF5C4D),
        fgColor: const Color(0xFF0B1220),
        icon: Icons.access_time_rounded,
      ),
      _BentoTileSpec(
        category: 'payment',
        label: 'Chứng từ chờ duyệt',
        count: summary.pendingPaymentProofs,
        bgColor: const Color(0xFF4F6BFF),
        fgColor: Colors.white,
        icon: Icons.description_outlined,
      ),
      _BentoTileSpec(
        category: 'viewing',
        label: 'Lịch xem',
        count: summary.pendingViewings,
        bgColor: const Color(0xFF19D3B0),
        fgColor: const Color(0xFF0B1220),
        icon: Icons.calendar_today_rounded,
      ),
      _BentoTileSpec(
        category: 'maintenance',
        label: 'Sửa chữa đang mở',
        count: summary.openMaintenance,
        bgColor: const Color(0xFFFFC22E),
        fgColor: const Color(0xFF0B1220),
        icon: Icons.handyman_outlined,
      ),
      _BentoTileSpec(
        category: 'lease',
        label: 'HĐ sắp hết hạn',
        count: summary.expiringLeases,
        bgColor: const Color(0xFFA66BFF),
        fgColor: const Color(0xFF0B1220),
        icon: Icons.bookmark_border_rounded,
        fullWidth: true,
      ),
    ];

    final extraMetrics = [
      _Metric('Tổng việc', summary.total, const Color(0xFF19D3B0)),
      _Metric('Chưa đọc', summary.unread, const Color(0xFFFF6B1A)),
      _Metric('Hóa đơn sắp đến hạn', summary.dueSoonInvoices,
          const Color(0xFFFFC22E)),
      _Metric('Sửa chữa khẩn cấp', summary.urgentMaintenance,
          const Color(0xFFFF5C4D)),
      _Metric(
          'Kiểm tra phòng', summary.dueInspections, const Color(0xFF19D3B0)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - 10) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Tile (Demo v3 `.tile.hero`) ────────────────────────────
            Material(
              color: const Color(0xFFFF6B1A),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelectCategory('all'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Khẩn · xử lý trước',
                              style: TextStyle(
                                color: Color(0xFF0B1220),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1220)
                                  .withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.north_east_rounded,
                              size: 16,
                              color: Color(0xFF0B1220),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        children: [
                          Text(
                            '$urgentCount',
                            style: const TextStyle(
                              color: Color(0xFF0B1220),
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.8,
                              height: 0.95,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '/ ${summary.total} việc đang chờ · ${summary.unread} chưa đọc',
                              style: const TextStyle(
                                color: Color(0xFF0B1220),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── 5 Solid Color Bento Tiles (Demo v3 `.grid2 .tile`) ──────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: bentoTiles.map((tile) {
                return SizedBox(
                  width: tile.fullWidth ? constraints.maxWidth : halfWidth,
                  child: _SolidBentoTile(
                    spec: tile,
                    onTap: () => onSelectCategory(tile.category),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // ── Secondary Summary Strip ────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: extraMetrics
                  .map((metric) => SizedBox(
                        width: halfWidth,
                        child: metric,
                      ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _BentoTileSpec {
  const _BentoTileSpec({
    required this.category,
    required this.label,
    required this.count,
    required this.bgColor,
    required this.fgColor,
    required this.icon,
    this.fullWidth = false,
  });

  final String category;
  final String label;
  final int count;
  final Color bgColor;
  final Color fgColor;
  final IconData icon;
  final bool fullWidth;
}

class _SolidBentoTile extends StatelessWidget {
  const _SolidBentoTile({
    required this.spec,
    required this.onTap,
  });

  final _BentoTileSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isZero = spec.count == 0;
    return Opacity(
      opacity: isZero ? 0.45 : 1.0,
      child: Material(
        color: spec.bgColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: spec.fullWidth ? 76 : 104,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: spec.fullWidth
                  ? Row(
                      children: [
                        Text(
                          '${spec.count}',
                          style: TextStyle(
                            color: spec.fgColor,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            spec.label,
                            style: TextStyle(
                              color: spec.fgColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0B1220).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            spec.icon,
                            size: 15,
                            color: spec.fgColor,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${spec.count}',
                                  style: TextStyle(
                                    color: spec.fgColor,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                    height: 0.95,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B1220)
                                    .withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                spec.icon,
                                size: 15,
                                color: spec.fgColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 34,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              spec.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: spec.fgColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFFF4F6FB),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9AA6C2),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.summary,
    required this.onChanged,
    required this.categories,
  });

  final String selected;
  final ActionItemsSummary summary;
  final ValueChanged<String> onChanged;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final filters = <String, String>{
      'all': 'Tất cả',
      'viewing': 'Lịch xem',
      'payment': 'Chứng từ',
      'invoice': 'Hóa đơn',
      'maintenance': 'Sửa chữa',
      'lease': 'Hợp đồng',
      'inspection': 'Kiểm tra',
    }..removeWhere((key, _) => key != 'all' && !categories.contains(key));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.keys.map((key) {
        final count = switch (key) {
          'all' => summary.total,
          'viewing' => summary.pendingViewings,
          'payment' => summary.pendingPaymentProofs,
          'invoice' => summary.overdueInvoices + summary.dueSoonInvoices,
          'maintenance' => summary.openMaintenance,
          'lease' => summary.expiringLeases,
          'inspection' => summary.dueInspections,
          _ => 0,
        };
        final palette = _chipPaletteFor(key);
        final isSelected = selected == key;
        return ChoiceChip(
          label: Text('${filters[key]}  $count'),
          selected: isSelected,
          onSelected: (_) => onChanged(key),
          labelStyle: TextStyle(
            color: isSelected ? palette.fg : palette.bg,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          selectedColor: palette.bg,
          backgroundColor: const Color(0xFF0B1220),
          side: BorderSide(color: palette.bg, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  ({Color bg, Color fg}) _chipPaletteFor(String key) => switch (key) {
        'all' => (bg: const Color(0xFFF4F6FB), fg: const Color(0xFF0B1220)),
        'invoice' => (bg: const Color(0xFFFF5C4D), fg: const Color(0xFF0B1220)),
        'payment' => (bg: const Color(0xFF4F6BFF), fg: Colors.white),
        'viewing' => (bg: const Color(0xFF19D3B0), fg: const Color(0xFF0B1220)),
        'maintenance' => (
            bg: const Color(0xFFFFC22E),
            fg: const Color(0xFF0B1220)
          ),
        'lease' => (bg: const Color(0xFFA66BFF), fg: const Color(0xFF0B1220)),
        _ => (bg: const Color(0xFF19D3B0), fg: const Color(0xFF0B1220)),
      };
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.onTap});

  final LandlordNotification item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _stubPaletteFor(item.category);
    final roomCode = _extractRoomFromNotification(item);
    final isHot = item.severity == 'danger';

    return Semantics(
      button: true,
      label: '${item.title}. ${item.body}',
      child: Material(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // ── Left Solid Color Ticket Stub Background (Demo v3 `.stub`) ─
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 78,
                child: ColoredBox(
                  color: palette.bg,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            roomCode,
                            style: TextStyle(
                              color: palette.fg,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          palette.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.fg.withValues(alpha: 0.88),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Perforated Divider Line ───────────────────────────────────
              const Positioned(
                left: 78,
                top: 0,
                bottom: 0,
                width: 2,
                child: ColoredBox(color: Color(0xFF0B1220)),
              ),

              // ── Ticket Body + Circular Go Button (Demo v3 `.body` + `.go`)
              Padding(
                padding: const EdgeInsets.only(left: 80),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: const Color(0xFFF4F6FB),
                                      fontSize: 15,
                                      fontWeight: item.isRead
                                          ? FontWeight.w700
                                          : FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (!item.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF6B1A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.body,
                              style: const TextStyle(
                                color: Color(0xFF9AA6C2),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            if (item.propertyName != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                item.propertyName!,
                                style: TextStyle(
                                  color: palette.bg,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isHot
                                        ? const Color(0xFFFF6B1A)
                                        : const Color(0xFF1D2740),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '${switch (item.severity) {
                                      'danger' => 'Khẩn cấp',
                                      'warning' => 'Cần chú ý',
                                      _ => 'Theo dõi'
                                    }}${item.dueAt == null ? '' : ' · ${formatDate(item.dueAt!)}'}',
                                    style: TextStyle(
                                      color: isHot
                                          ? const Color(0xFF0B1220)
                                          : const Color(0xFFF4F6FB),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: palette.bg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.north_east_rounded,
                          color: palette.fg,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({Color bg, Color fg, String label}) _stubPaletteFor(String category) =>
      switch (category) {
        'invoice' => (
            bg: const Color(0xFFFF5C4D),
            fg: const Color(0xFF0B1220),
            label: 'QUÁ HẠN',
          ),
        'payment' => (
            bg: const Color(0xFF4F6BFF),
            fg: Colors.white,
            label: 'CHỨNG TỪ',
          ),
        'viewing' => (
            bg: const Color(0xFF19D3B0),
            fg: const Color(0xFF0B1220),
            label: 'LỊCH XEM',
          ),
        'maintenance' => (
            bg: const Color(0xFFFFC22E),
            fg: const Color(0xFF0B1220),
            label: 'SỬA CHỮA',
          ),
        'lease' => (
            bg: const Color(0xFFA66BFF),
            fg: const Color(0xFF0B1220),
            label: 'HỢP ĐỒNG',
          ),
        'inspection' => (
            bg: const Color(0xFF19D3B0),
            fg: const Color(0xFF0B1220),
            label: 'KIỂM TRA',
          ),
        _ => (
            bg: const Color(0xFFFF6B1A),
            fg: const Color(0xFF0B1220),
            label: 'CẦN LÀM',
          ),
      };

  String _extractRoomFromNotification(LandlordNotification item) {
    final combined = '${item.title} ${item.body}';
    final match = RegExp(
      r'(?:Phòng|P\.?|Room)\s*([A-Za-z]?\d{2,4})',
      caseSensitive: false,
    ).firstMatch(combined);
    if (match != null) return match.group(1)!.toUpperCase();
    final codeMatch =
        RegExp(r'\b([A-Za-z]\d{2,3}|\d{3})\b').firstMatch(combined);
    if (codeMatch != null) return codeMatch.group(1)!.toUpperCase();
    return switch (item.category) {
      'invoice' => 'HĐ',
      'payment' => 'CT',
      'viewing' => 'LX',
      'maintenance' => 'SC',
      'lease' => 'HĐ',
      _ => 'P--',
    };
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.total,
    required this.limit,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int total;
  final int limit;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final first = total == 0 ? 0 : (((page - 1) * limit) + 1).clamp(1, total);
    final last = (page * limit).clamp(0, total);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text('$first–$last / $total',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Trang trước',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('$page',
                style: const TextStyle(
                    color: AppTheme.ink, fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: 'Trang sau',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27324F)),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFF19D3B0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF0B1220),
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'Không có việc cần xử lý',
            style: TextStyle(
              color: Color(0xFF0B1220),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Mọi thứ đang được theo dõi ổn định. Kéo xuống để tải lại khi có việc mới.',
            style: TextStyle(
              color: Color(0xFF0B1220),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppTheme.teal));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppTheme.red, size: 34),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
