import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_failure.dart';
import '../auth/auth_navigation.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import '../tenant_portal/tenant_portal_providers.dart';
import '../tenant_portal/tenant_portal_screen.dart';
import 'listing_widgets.dart';

class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(tenantPortalProfileProvider);
    return profile.when(
      data: (_) => const TenantPortalScreen(),
      loading: () => ListingTheme(
          child: Scaffold(
              backgroundColor: kAirbnbSurface,
              appBar: AppBar(
                backgroundColor: Colors.white,
                title: const Text('Phòng đang thuê của tôi',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: kAirbnbInk)),
              ),
              bottomNavigationBar: const ListingNavigation(selectedIndex: 1),
              body: const Center(
                  child: CircularProgressIndicator(color: kAirbnbRose)))),
      error: (error, _) {
        final missing =
            error is ApiFailure && error.code == 'TENANT_PROFILE_NOT_FOUND';
        return ListingTheme(
          child: Scaffold(
            backgroundColor: kAirbnbSurface,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: const Text('Phòng đang thuê của tôi',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: kAirbnbInk)),
            ),
            bottomNavigationBar: const ListingNavigation(selectedIndex: 1),
            body: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, liquidTaskbarBottomPadding(context)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: missing
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: kAirbnbLine),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: kAirbnbRose.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.home_work_rounded,
                                  size: 36,
                                  color: kAirbnbRose,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Bạn chưa liên kết phòng thuê',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: kAirbnbInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sau khi chốt thuê, chủ trọ sẽ liên kết hồ sơ và hợp đồng với tài khoản của bạn. Không gian này dùng để theo dõi điện nước, hóa đơn và bảo trì.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: kAirbnbMuted,
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: kAirbnbSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kAirbnbLine),
                                ),
                                child: const Column(
                                  children: [
                                    _OnboardingStepRow(
                                      step: '1',
                                      title: 'Khám phá & Chọn phòng ưng ý',
                                      subtitle:
                                          'Xem giá thuê, tiền điện nước minh bạch trên tab Khám phá.',
                                    ),
                                    SizedBox(height: 12),
                                    _OnboardingStepRow(
                                      step: '2',
                                      title: 'Chủ trọ kích hoạt hợp đồng',
                                      subtitle:
                                          'Tài khoản tự động gắn với phòng ngay khi ký hợp đồng.',
                                    ),
                                    SizedBox(height: 12),
                                    _OnboardingStepRow(
                                      step: '3',
                                      title: 'Quản lý hóa đơn & Báo sửa chữa',
                                      subtitle:
                                          'Theo dõi chỉ số điện nước, gửi ảnh UNC & gọi thợ 1 chạm.',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => context.go(exploreRoute),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kAirbnbRose,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.search_rounded),
                                  label: const Text(
                                    'Khám phá phòng',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                  onPressed: () => ref
                                      .invalidate(tenantPortalProfileProvider),
                                  icon: const Icon(Icons.refresh),
                                  label:
                                      const Text('Kiểm tra liên kết hợp đồng')),
                            ],
                          ),
                        )
                      : ListingMessage(
                          title: 'Chưa tải được phòng của bạn',
                          message: listingError(error),
                          onRetry: () =>
                              ref.invalidate(tenantPortalProfileProvider),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingStepRow extends StatelessWidget {
  const _OnboardingStepRow({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kAirbnbInk,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: kAirbnbInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: kAirbnbMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
