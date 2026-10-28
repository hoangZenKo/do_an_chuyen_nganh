import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'listings_providers.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import '../../models/room_listing.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';

const kAirbnbRose = Color(0xFFFF385C);
const kAirbnbInk = Color(0xFF222222);
const kAirbnbMuted = Color(0xFF717171);
const kAirbnbLine = Color(0xFFEBEBEB);
const kAirbnbSurface = Color(0xFFF7F7F7);

class ListingTheme extends StatelessWidget {
  const ListingTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData(
          useMaterial3: true,
          fontFamily: AppTheme.fontFamily,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
              seedColor: kAirbnbRose,
              primary: kAirbnbInk,
              secondary: kAirbnbRose,
              surface: Colors.white,
              brightness: Brightness.light),
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: kAirbnbInk,
              elevation: 0,
              surfaceTintColor: Colors.transparent),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: kAirbnbRose.withValues(alpha: 0.12),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: kAirbnbRose, size: 24);
              }
              return const IconThemeData(color: kAirbnbMuted, size: 24);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: kAirbnbRose,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                );
              }
              return const TextStyle(
                color: kAirbnbMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kAirbnbLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kAirbnbLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kAirbnbInk, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white),
        ),
        child: child,
      );
}

class ListingNavigationShell extends ConsumerWidget {
  const ListingNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.child,
  });

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider).session?.user.role;
    final manager = role == 'landlord' || role == 'staff' || role == 'admin';
    return ListingTheme(
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: selectedIndex == 0 && manager
            ? null
            : ListingNavigation(selectedIndex: selectedIndex),
        body: LiquidTaskbarScrollScope(
          child: _ListingNavigationScope(child: child),
        ),
      ),
    );
  }
}

class _ListingNavigationScope extends InheritedWidget {
  const _ListingNavigationScope({required super.child});

  @override
  bool updateShouldNotify(_ListingNavigationScope oldWidget) => false;
}

class ListingNavigation extends StatelessWidget {
  const ListingNavigation({super.key, required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<_ListingNavigationScope>() !=
        null) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kAirbnbLine)),
      ),
      child: SafeArea(
        top: false,
        child: LiquidBubbleNavigation(
          selectedIndex: selectedIndex,
          bubbleColor: Colors.white,
          activeColor: kAirbnbRose,
          inactiveColor: kAirbnbMuted,
          items: const [
            LiquidNavigationItem(
              icon: Icons.search_rounded,
              selectedIcon: Icons.search_rounded,
              label: 'Khám phá',
            ),
            LiquidNavigationItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Phòng của tôi',
            ),
            LiquidNavigationItem(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Tài khoản',
            ),
          ],
          onSelected: (index) => context.go(
            [exploreRoute, tenantPortalRoute, seekerAccountRoute][index],
          ),
        ),
      ),
    );
  }
}

class ListingImage extends StatelessWidget {
  const ListingImage({super.key, required this.source});
  final String? source;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
        color: const Color(0xFFF1F3F5),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.home_work_outlined, size: 36, color: kAirbnbMuted),
          const SizedBox(height: 4),
          Text(source == null ? 'Chưa có ảnh' : 'Không tải được ảnh',
              style: const TextStyle(
                  color: kAirbnbMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ])));
    return source == null
        ? placeholder
        : Image.network(ApiConfig.resolveUrl(source!),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (_, child, loading) =>
                loading == null ? child : placeholder);
  }
}

class ListingCard extends ConsumerStatefulWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.badgeText = 'Đã duyệt nội dung',
  });
  final RoomListing listing;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  ConsumerState<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends ConsumerState<ListingCard> {
  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final selected = ref
        .watch(listingComparisonProvider)
        .any((item) => item.id == listing.id);
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 260;
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: compact ? 1.03 : 1.18,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ListingImage(source: listing.imageUrls.firstOrNull),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [
                              Color(0x38000000),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      if (widget.badgeText != null)
                        Positioned(
                          top: compact ? 8 : 12,
                          left: compact ? 8 : 12,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth - 68,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.badgeText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kAirbnbInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: compact ? 0 : 8,
                        right: compact ? 0 : 8,
                        child: IconButton(
                          tooltip: selected ? 'Bỏ so sánh' : 'Chọn so sánh',
                          onPressed: () {
                            if (!ref
                                .read(listingComparisonProvider.notifier)
                                .toggle(listing)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Chỉ so sánh tối đa 3 phòng. Hãy bỏ chọn một phòng trước.')));
                            }
                          },
                          icon: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.compare_arrows_rounded,
                            color: selected ? kAirbnbRose : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 13 : 15.5,
                              fontWeight: FontWeight.w800,
                              color: kAirbnbInk,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                        listing.availabilityFresh
                            ? 'Mới xác nhận còn phòng'
                            : 'Cần xác nhận phòng trống',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: listing.availabilityFresh
                                ? kAirbnbMuted
                                : kAirbnbRose)),
                    if (listing.distanceKm != null)
                      Text(
                          '≈ ${listing.distanceKm!.toStringAsFixed(1)} km tới trường',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: kAirbnbMuted)),
                    Text(
                      compact
                          ? '${formatArea(listing.areaSqm)} · ${listing.district}'
                          : '${listing.district}, ${listing.city} · ${formatArea(listing.areaSqm)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 13,
                        color: kAirbnbMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (listing.amenities.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        listing.amenities.take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11.5 : 12.5,
                          color: kAirbnbMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (listing.estimatedMonthlyCost != null)
                      Text(
                          'Dự kiến ${formatCurrencyVnd(listing.estimatedMonthlyCost!)}/tháng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: kAirbnbMuted)),
                    if (compact)
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: formatCurrencyVnd(listing.monthlyRent),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(
                            text: ' / tháng',
                            style: TextStyle(color: kAirbnbMuted),
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12.5, color: kAirbnbInk),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${formatCurrencyVnd(listing.monthlyRent)}/tháng',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: kAirbnbInk,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          Text(
                            '· Cọc ${formatCurrencyVnd(listing.deposit)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: kAirbnbMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class ListingMessage extends StatelessWidget {
  const ListingMessage(
      {super.key, required this.title, required this.message, this.onRetry});
  final String title, message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại'))
          ],
        ]),
      ));
}

String listingError(Object error) => error is ApiFailure
    ? error.message
    : 'Không thể tải dữ liệu. Vui lòng thử lại.';
