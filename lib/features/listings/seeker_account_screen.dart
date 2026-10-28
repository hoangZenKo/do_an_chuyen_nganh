import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import 'listing_widgets.dart';

class SeekerAccountScreen extends ConsumerWidget {
  const SeekerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    return ListingTheme(
      child: Scaffold(
        backgroundColor: kAirbnbSurface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Tài khoản',
            style: TextStyle(fontWeight: FontWeight.w800, color: kAirbnbInk),
          ),
        ),
        bottomNavigationBar: const ListingNavigation(selectedIndex: 2),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, liquidTaskbarBottomPadding(context)),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kAirbnbLine),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: kAirbnbRose.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 38,
                      color: kAirbnbRose,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    session?.user.fullName ?? 'Chào bạn!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kAirbnbInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session?.user.email ??
                        'Khám phá phòng ngay. Đăng nhập để quản lý thông tin của bạn.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kAirbnbMuted,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (session == null) ...[
              FilledButton(
                onPressed: () => context.push(loginRoute),
                style: FilledButton.styleFrom(
                  backgroundColor: kAirbnbRose,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.push(registerRoute),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAirbnbInk,
                  side: const BorderSide(color: kAirbnbLine),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tạo tài khoản',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kAirbnbLine),
                ),
                child: Column(
                  children: [
                    ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: const Text('Trung tâm hỗ trợ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(supportCenterRoute)),
                    if (session.user.role == 'tenant')
                      ListTile(
                          leading: const Icon(Icons.favorite_border),
                          title: const Text('Phòng yêu thích'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(housingFavoritesRoute)),
                    if (session.user.role == 'tenant' ||
                        session.user.role == 'landlord') ...[
                      ListTile(
                          leading: const Icon(Icons.event_available_outlined),
                          title: const Text('Lịch xem phòng'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(housingViewingsRoute)),
                      ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Thông báo xem phòng'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(housingNoticesRoute)),
                      ListTile(
                          leading: const Icon(Icons.science_outlined),
                          title: const Text('Thử nghiệm khu vực nhỏ'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(rentalPilotRoute)),
                    ],
                    if (session.user.role == 'admin')
                      ListTile(
                          leading: const Icon(Icons.feedback_outlined),
                          title: const Text('Phản hồi thử nghiệm'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(pilotFeedbackRoute)),
                    if (session.user.role == 'tenant') ...[
                      ListTile(
                        leading:
                            const Icon(Icons.lock_reset, color: kAirbnbInk),
                        title: const Text(
                          'Đổi mật khẩu',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: kAirbnbInk),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: kAirbnbMuted),
                        onTap: () => context.push(tenantPasswordRoute),
                      ),
                      const Divider(height: 1, color: kAirbnbLine),
                    ],
                    if (session.user.role != 'tenant') ...[
                      ListTile(
                        leading: const Icon(Icons.dashboard_customize_outlined,
                            color: kAirbnbInk),
                        title: const Text(
                          'Về trang quản lý',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: kAirbnbInk),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: kAirbnbMuted),
                        onTap: () => context.go(homeRouteForSession(session)),
                      ),
                      const Divider(height: 1, color: kAirbnbLine),
                    ],
                    ListTile(
                      leading: const Icon(Icons.logout, color: kAirbnbRose),
                      title: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kAirbnbRose,
                        ),
                      ),
                      onTap: () async {
                        await ref
                            .read(sessionControllerProvider.notifier)
                            .logout();
                        if (context.mounted) context.go(exploreRoute);
                      },
                    ),
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
