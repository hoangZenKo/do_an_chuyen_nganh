import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room_listing.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'listing_widgets.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import 'listings_providers.dart';
import 'listing_comparison_screen.dart';
import 'discovery_tools.dart';
import 'saved_searches_screen.dart';
import '../../core/utils/format.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  ListingQuery _query = const ListingQuery();
  int _selectedCategory = 0;
  bool _savingSearch = false;

  static const _categories = <({
    String emoji,
    String label,
    bool isNew,
    String? keyword,
  })>[
    (emoji: '🏠', label: 'Phòng trọ', isNew: false, keyword: null),
    (emoji: '🏢', label: 'Studio', isNew: true, keyword: 'Studio'),
    (emoji: '🛋️', label: 'Đủ nội thất', isNew: true, keyword: 'Điều hòa'),
    (emoji: '✨', label: 'Dịch vụ trọ', isNew: true, keyword: null),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch([String? value]) {
    final text = (value ?? _search.text).trim();
    setState(() {
      _query = ListingQuery(
        maxBudget: _query.maxBudget,
        electricityKwh: _query.electricityKwh,
        waterM3: _query.waterM3,
        freshOnly: _query.freshOnly,
        campusId: _query.campusId,
        radiusKm: _query.radiusKm,
        search: text,
        city: _query.city,
        district: _query.district,
        minPrice: _query.minPrice,
        maxPrice: _query.maxPrice,
        minArea: _query.minArea,
        amenity: _query.amenity,
        sort: _query.sort,
      );
    });
  }

  Future<void> _filter() async {
    final value = await showDialog<ListingQuery>(
        context: context,
        builder: (_) => ListingTheme(child: _FilterDialog(query: _query)));
    if (value != null && mounted) {
      if (value.campusId != _query.campusId) {
        ref.read(listingComparisonProvider.notifier).clear();
      }
      setState(() => _query = value);
    }
  }

  Future<void> _saveSearch() async {
    if (_savingSearch) return;
    setState(() => _savingSearch = true);
    try {
      final name = await showDialog<String>(
          context: context,
          builder: (_) => _SavedSearchNameDialog(
              initialName: _query.search.isEmpty
                  ? 'Phòng phù hợp với tôi'
                  : _query.search));
      if (name == null || !mounted) return;
      await ref.read(discoveryToolsProvider).save(name, _query);
      ref.invalidate(savedSearchesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Đã lưu. Tin mới phù hợp sẽ xuất hiện trong “Tìm kiếm đã lưu”.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Không lưu được. Kiểm tra kết nối và giới hạn 10 tìm kiếm.')));
      }
    } finally {
      if (mounted) setState(() => _savingSearch = false);
    }
  }

  Future<void> _savedSearches() async {
    final query = await Navigator.push<ListingQuery>(context,
        MaterialPageRoute(builder: (_) => const SavedSearchesScreen()));
    if (query != null && mounted) {
      ref.read(listingComparisonProvider.notifier).clear();
      setState(() {
        _query = query;
        _search.text = query.search;
        _selectedCategory = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(publicListingsProvider(_query));
    final comparison = ref.watch(listingComparisonProvider);
    final role = ref.watch(sessionControllerProvider).session?.user.role;
    final unread = role == 'tenant'
        ? (ref.watch(searchAlertsProvider(1)).valueOrNull?['meta']?['unread']
                as int? ??
            0)
        : 0;
    final manager = role == 'landlord' || role == 'admin' || role == 'staff';
    return ListingTheme(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: manager
            ? AppBar(
                title: const Text('Atrium Living',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  TextButton(
                      onPressed: () => context.go(homeRouteForSession(
                          ref.read(sessionControllerProvider).session!)),
                      child: const Text('Quản lý')),
                ],
              )
            : null,
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          if (comparison.isNotEmpty)
            SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    8 + liquidTaskbarBottomPadding(context, extra: 0),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text('Đã chọn ${comparison.length}/3 phòng')),
                    TextButton(
                        onPressed: () => ref
                            .read(listingComparisonProvider.notifier)
                            .clear(),
                        child: const Text('Xóa')),
                    FilledButton(
                        onPressed: comparison.length < 2
                            ? null
                            : () {
                                for (final listing in comparison) {
                                  ref.invalidate(
                                      publicListingDetailProvider(listing.id));
                                }
                                Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const ListingComparisonScreen()));
                              },
                        child: const Text('So sánh')),
                  ]),
                )),
          if (!manager) const ListingNavigation(selectedIndex: 0),
        ]),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: kAirbnbRose,
            onRefresh: () async {
              if (role == 'tenant') ref.invalidate(searchAlertsProvider);
              await ref
                  .refresh(publicListingsProvider(_query).future)
                  .catchError((Object _) => const ListingPage(
                      items: [], total: 0, page: 1, limit: 12));
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, liquidTaskbarBottomPadding(context)),
              children: [
                _AirbnbSearchBar(
                  controller: _search,
                  onSearch: () => _applySearch(),
                  onSubmitted: _applySearch,
                  onFilter: _filter,
                  hasActiveFilter: _query != const ListingQuery(),
                  onClearFilter: () => setState(() {
                    if (_query.campusId != null) {
                      ref.read(listingComparisonProvider.notifier).clear();
                    }
                    _search.clear();
                    _selectedCategory = 0;
                    _query = const ListingQuery();
                  }),
                ),
                const SizedBox(height: 14),
                if (role == 'tenant')
                  Wrap(spacing: 8, children: [
                    TextButton.icon(
                        onPressed: _savingSearch ? null : _saveSearch,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Lưu tìm kiếm')),
                    TextButton.icon(
                        onPressed: _savedSearches,
                        icon: const Icon(Icons.notifications_none),
                        label: Text(unread > 0
                            ? 'Tìm kiếm đã lưu ($unread)'
                            : 'Tìm kiếm đã lưu')),
                  ]),
                if (_query.maxBudget != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          'Tổng dự kiến ≤ ${formatCurrencyVnd(_query.maxBudget!)} / tháng · ${_query.electricityKwh} kWh, ${_query.waterM3} m³. Chưa gồm tiền cọc và phát sinh.',
                          style: const TextStyle(
                              color: kAirbnbMuted, fontSize: 12))),
                _AirbnbCategoryBar(
                  categories: _categories,
                  selectedIndex: _selectedCategory,
                  onSelect: (index) {
                    setState(() {
                      _selectedCategory = index;
                      final keyword = _categories[index].keyword;
                      if (keyword != null) {
                        _query = ListingQuery(
                          maxBudget: _query.maxBudget,
                          electricityKwh: _query.electricityKwh,
                          waterM3: _query.waterM3,
                          freshOnly: _query.freshOnly,
                          campusId: _query.campusId,
                          radiusKm: _query.radiusKm,
                          search: _search.text,
                          city: _query.city,
                          district: _query.district,
                          minPrice: _query.minPrice,
                          maxPrice: _query.maxPrice,
                          minArea: _query.minArea,
                          amenity: keyword,
                          sort: _query.sort,
                        );
                      } else if (_query.amenity.isNotEmpty) {
                        _query = ListingQuery(
                          maxBudget: _query.maxBudget,
                          electricityKwh: _query.electricityKwh,
                          waterM3: _query.waterM3,
                          freshOnly: _query.freshOnly,
                          campusId: _query.campusId,
                          radiusKm: _query.radiusKm,
                          search: _search.text,
                          city: _query.city,
                          district: _query.district,
                          minPrice: _query.minPrice,
                          maxPrice: _query.maxPrice,
                          minArea: _query.minArea,
                          sort: _query.sort,
                        );
                      }
                    });
                  },
                ),
                const Divider(height: 1, color: kAirbnbLine),
                const SizedBox(height: 18),
                listings.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: kAirbnbRose))),
                  error: (error, _) => ListingMessage(
                      title: 'Chưa tải được phòng',
                      message: listingError(error),
                      onRetry: () =>
                          ref.invalidate(publicListingsProvider(_query))),
                  data: (page) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Phòng trọ dành cho bạn',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 19,
                                          color: kAirbnbInk,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: kAirbnbSurface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: kAirbnbInk,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${page.total} phòng phù hợp · Nội dung đã duyệt',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: kAirbnbMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_query.campusId != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                              'Khoảng cách ước tính theo đường chim bay, không phải quãng đường hoặc thời gian di chuyển.',
                              style:
                                  TextStyle(fontSize: 12, color: kAirbnbMuted)),
                        ),
                      if (page.items.isEmpty)
                        const ListingMessage(
                            title: 'Chưa có phòng phù hợp',
                            message:
                                'Thử thay đổi bộ lọc hoặc quay lại sau. Chỉ tin đã duyệt của phòng còn trống được hiển thị.'),
                      if (page.items.isNotEmpty)
                        LayoutBuilder(builder: (context, constraints) {
                          final largeText =
                              MediaQuery.textScalerOf(context).scale(14) > 21;
                          final columns =
                              largeText || constraints.maxWidth < 280
                                  ? 1
                                  : constraints.maxWidth >= 1000
                                      ? 3
                                      : 2;
                          final spacing =
                              constraints.maxWidth < 640 ? 12.0 : 18.0;
                          final width =
                              (constraints.maxWidth - (columns - 1) * spacing) /
                                  columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: 24,
                            children: [
                              for (var i = 0; i < page.items.length; i++)
                                SizedBox(
                                  width: width,
                                  child: ListingCard(
                                    key: ValueKey(page.items[i].id),
                                    listing: page.items[i],
                                    badgeText: page.items[i].isDemo
                                        ? 'Tin mẫu'
                                        : 'Đã duyệt',
                                    onTap: () => context.push(
                                        publicListingPath(page.items[i].id)),
                                  ),
                                ),
                            ],
                          );
                        }),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: kAirbnbLine),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_offer_rounded,
                                  size: 16, color: kAirbnbRose),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Giá niêm yết minh bạch · Không phí ẩn',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: kAirbnbInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                              onPressed: _query.page > 1
                                  ? () => setState(() =>
                                      _query = _query.atPage(_query.page - 1))
                                  : null,
                              child: const Text('Trang trước')),
                          Text(
                            'Trang ${page.page}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kAirbnbInk,
                            ),
                          ),
                          OutlinedButton(
                              onPressed: page.hasNext
                                  ? () => setState(() =>
                                      _query = _query.atPage(_query.page + 1))
                                  : null,
                              child: const Text('Trang sau')),
                        ],
                      ),
                    ],
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

class _AirbnbSearchBar extends StatelessWidget {
  const _AirbnbSearchBar({
    required this.controller,
    required this.onSearch,
    required this.onSubmitted,
    required this.onFilter,
    required this.hasActiveFilter,
    required this.onClearFilter,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilter;
  final bool hasActiveFilter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kAirbnbLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kAirbnbRose.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: 'Tìm phòng',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.search_rounded,
                      color: kAirbnbRose, size: 20),
                  onPressed: onSearch,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kAirbnbInk,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Bắt đầu tìm phòng',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kAirbnbInk,
                    ),
                    labelText: 'Khu vực · Mức giá · Tiện nghi',
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      color: kAirbnbMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: onFilter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAirbnbInk,
                  side: const BorderSide(color: kAirbnbLine),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text(
                  'Bộ lọc',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (hasActiveFilter) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Xóa bộ lọc'),
            ),
          ),
        ],
      ],
    );
  }
}

class _AirbnbCategoryBar extends StatelessWidget {
  const _AirbnbCategoryBar({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<({String emoji, String label, bool isNew, String? keyword})>
      categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            categories[i].emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        if (categories[i].isNew)
                          Positioned(
                            top: -2,
                            right: -14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Text(
                                'MỚI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categories[i].label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedIndex == i
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selectedIndex == i ? kAirbnbInk : kAirbnbMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: selectedIndex == i ? 44 : 0,
                      decoration: BoxDecoration(
                        color: kAirbnbInk,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedSearchNameDialog extends StatefulWidget {
  const _SavedSearchNameDialog({required this.initialName});
  final String initialName;
  @override
  State<_SavedSearchNameDialog> createState() => _SavedSearchNameDialogState();
}

class _SavedSearchNameDialogState extends State<_SavedSearchNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Lưu tìm kiếm'),
        content: Form(
            key: _form,
            child: TextFormField(
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(
                    labelText: 'Tên bộ lọc',
                    helperText: 'Nhận thông báo tin mới trong app.'),
                validator: (value) => (value?.trim().length ?? 0) < 2 ||
                        value!.trim().length > 100
                    ? 'Nhập tên từ 2 đến 100 ký tự'
                    : null)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _name.text.trim());
                }
              },
              child: const Text('Lưu'))
        ],
      );
}

class _FilterDialog extends ConsumerStatefulWidget {
  const _FilterDialog({required this.query});
  final ListingQuery query;
  @override
  ConsumerState<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<_FilterDialog> {
  final _form = GlobalKey<FormState>();
  late final _city = TextEditingController(text: widget.query.city);
  late final _district = TextEditingController(text: widget.query.district);
  late final _min =
      TextEditingController(text: widget.query.minPrice?.toString());
  late final _max =
      TextEditingController(text: widget.query.maxPrice?.toString());
  late final _area =
      TextEditingController(text: widget.query.minArea?.toString());
  late final _amenity = TextEditingController(text: widget.query.amenity);
  late final _budget =
      TextEditingController(text: widget.query.maxBudget?.toString());
  late final _electricity =
      TextEditingController(text: widget.query.electricityKwh.toString());
  late final _water =
      TextEditingController(text: widget.query.waterM3.toString());
  late bool _freshOnly = widget.query.freshOnly;
  late String _sort = widget.query.sort;
  late String? _campusId = widget.query.campusId;
  late double _radiusKm = widget.query.radiusKm ?? 5;
  @override
  void dispose() {
    for (final control in [
      _city,
      _district,
      _min,
      _max,
      _area,
      _amenity,
      _budget,
      _electricity,
      _water
    ]) {
      control.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
          {bool number = false, bool integer = false, int? max}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(labelText: label),
              validator: (value) {
                if (!number || value!.trim().isEmpty) return null;
                if (integer && int.tryParse(value) == null) {
                  return 'Nhập số nguyên';
                }
                final parsed = num.tryParse(value);
                if (parsed == null ||
                    !parsed.isFinite ||
                    parsed < 0 ||
                    parsed > (max ?? 2147483647)) {
                  return 'Nhập số hợp lệ không âm';
                }
                if (controller != _area && int.tryParse(value) == null) {
                  return 'Giá tiền phải là số nguyên';
                }
                if (controller == _max &&
                    int.tryParse(_min.text) != null &&
                    parsed < int.parse(_min.text)) {
                  return 'Giá tối đa nhỏ hơn giá tối thiểu';
                }
                return null;
              }));

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Tìm phòng phù hợp'),
          content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _field(_city, 'Tỉnh / Thành phố'),
                        _field(_district, 'Quận / Huyện'),
                        _field(_min, 'Giá tối thiểu (đ/tháng)', number: true),
                        _field(_max, 'Giá tối đa (đ/tháng)', number: true),
                        _field(_budget, 'Tổng ngân sách tối đa (đ/tháng)',
                            number: true, integer: true),
                        _field(_electricity, 'Điện dự kiến (kWh/tháng)',
                            number: true, integer: true, max: 10000),
                        _field(_water, 'Nước dự kiến (m³/tháng)',
                            number: true, integer: true, max: 10000),
                        const Text(
                            'Tổng = tiền thuê + điện + nước + dịch vụ + gửi xe. Chỉ là dự toán; chưa gồm tiền cọc và chi phí phát sinh.',
                            style:
                                TextStyle(fontSize: 12, color: kAirbnbMuted)),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mới xác nhận còn phòng'),
                            subtitle:
                                const Text('Chủ trọ đã xác nhận trong 14 ngày'),
                            value: _freshOnly,
                            onChanged: (value) =>
                                setState(() => _freshOnly = value)),
                        _field(_area, 'Diện tích tối thiểu (m²)', number: true),
                        _field(_amenity, 'Tiện ích (đúng tên trên tin)'),
                        ref.watch(schoolCampusesProvider).when(
                              loading: () => const LinearProgressIndicator(),
                              error: (error, _) => TextButton.icon(
                                  onPressed: () =>
                                      ref.invalidate(schoolCampusesProvider),
                                  icon: const Icon(Icons.refresh),
                                  label:
                                      const Text('Thử tải danh sách trường')),
                              data: (campuses) =>
                                  DropdownButtonFormField<String>(
                                value: campuses
                                        .any((campus) => campus.id == _campusId)
                                    ? _campusId
                                    : '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Trường / Cơ sở học'),
                                items: [
                                  const DropdownMenuItem(
                                      value: '',
                                      child: Text('Không lọc theo trường')),
                                  for (final campus in campuses)
                                    DropdownMenuItem(
                                        value: campus.id,
                                        child: Text(campus.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis))
                                ],
                                onChanged: (value) => setState(() =>
                                    _campusId = value == '' ? null : value),
                              ),
                            ),
                        if (_campusId != null) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<double>(
                            value: _radiusKm,
                            decoration: const InputDecoration(
                                labelText: 'Bán kính đường chim bay'),
                            items: [
                              for (final radius in {
                                1.0,
                                3.0,
                                5.0,
                                10.0,
                                _radiusKm
                              })
                                DropdownMenuItem(
                                    value: radius,
                                    child:
                                        Text('${radius.toStringAsFixed(0)} km'))
                            ],
                            onChanged: (value) =>
                                setState(() => _radiusKm = value!),
                          ),
                          const Text(
                              'Tin thiếu tọa độ sẽ không xuất hiện trong bộ lọc này. Trường có nhãn mẫu dùng vị trí mô phỏng.',
                              style:
                                  TextStyle(fontSize: 12, color: kAirbnbMuted)),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                            value: _sort,
                            decoration:
                                const InputDecoration(labelText: 'Sắp xếp'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'newest', child: Text('Mới nhất')),
                              DropdownMenuItem(
                                  value: 'price_asc',
                                  child: Text('Giá tăng dần')),
                              DropdownMenuItem(
                                  value: 'price_desc',
                                  child: Text('Giá giảm dần'))
                            ],
                            onChanged: (value) =>
                                setState(() => _sort = value!)),
                      ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(
                      context,
                      ListingQuery(
                          maxBudget: int.tryParse(_budget.text),
                          electricityKwh: int.tryParse(_electricity.text) ?? 50,
                          waterM3: int.tryParse(_water.text) ?? 3,
                          freshOnly: _freshOnly,
                          campusId: _campusId,
                          radiusKm: _campusId == null ? null : _radiusKm,
                          search: widget.query.search,
                          city: _city.text.trim(),
                          district: _district.text.trim(),
                          minPrice: int.tryParse(_min.text),
                          maxPrice: int.tryParse(_max.text),
                          minArea: double.tryParse(_area.text),
                          amenity: _amenity.text.trim(),
                          sort: _sort));
                },
                child: const Text('Áp dụng'))
          ]);
}
