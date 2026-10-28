import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_landlord_detail_screen.dart';
import '../features/admin/admin_landlord_form_screen.dart';
import '../features/admin/admin_landlords_screen.dart';
import '../features/admin/admin_property_detail_screen.dart';
import '../features/admin/admin_property_form_screen.dart';
import '../features/admin/admin_properties_screen.dart';
import '../features/audit/audit_screen.dart';
import '../features/auth/auth_navigation.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/staff_invite_screen.dart';
import '../features/auth/tenant_invite_screen.dart';
import '../features/billing/billing_form_screen.dart';
import '../features/billing/billing_screen.dart';
import '../features/billing/bulk_invoice_screen.dart';
import '../features/billing/invoice_detail_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/expense_form_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/maintenance/maintenance_form_screen.dart';
import '../features/maintenance/maintenance_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/operations/action_items_screen.dart';
import '../features/properties/properties_list_screen.dart';
import '../features/properties/property_form_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/rooms/room_detail_screen.dart';
import '../features/rooms/room_form_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/staff/staff_screen.dart';
import '../features/tenants/lease_expiry_screen.dart';
import '../features/tenants/lease_form_screen.dart';
import '../features/tenants/tenant_detail_screen.dart';
import '../features/tenants/tenant_form_screen.dart';
import '../features/tenants/tenants_list_screen.dart';
import '../features/tenant_portal/tenant_portal_screen.dart';
import '../features/tenant_portal/tenant_change_password_screen.dart';
import '../features/tenant_portal/tenant_invoice_detail_screen.dart';
import '../features/tenant_portal/tenant_zalo_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  late final GoRouter router;

  ref.listen<SessionState>(sessionControllerProvider, (_, __) {
    refresh.value++;
  });

  router = GoRouter(
    initialLocation: splashRoute,
    refreshListenable: refresh,
    redirect: (_, state) => authRedirect(
      state: ref.read(sessionControllerProvider),
      location: state.uri.path,
    ),
    routes: [
      GoRoute(path: splashRoute, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: onboardingRoute,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: loginRoute, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: registerRoute,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: tenantInviteRoute,
        builder: (_, state) => TenantInviteScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: staffInviteRoute,
        builder: (_, state) => StaffInviteScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
          path: dashboardRoute, builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: settingsRoute,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: settingsPasswordRoute,
        builder: (_, __) => const TenantChangePasswordScreen(),
      ),
      GoRoute(
        path: fakeZaloRoute,
        pageBuilder: (_, __) => CustomTransitionPage<void>(
          child: const FakeZaloSimulatorScreen(),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: tenantPortalRoute,
        builder: (_, __) => const TenantPortalScreen(),
      ),
      GoRoute(
        path: tenantPasswordRoute,
        builder: (_, __) => const TenantChangePasswordScreen(),
      ),
      GoRoute(
        path: tenantZaloRoute,
        pageBuilder: (_, __) => CustomTransitionPage<void>(
          child: const TenantZaloScreen(),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: tenantInvoiceDetailRoute,
        builder: (_, state) => TenantInvoiceDetailScreen(
          invoiceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
          path: adminRoute, builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
          path: adminLandlordsRoute,
          builder: (_, __) => const AdminLandlordsScreen()),
      GoRoute(
        path: adminLandlordFormRoute,
        builder: (_, state) => AdminLandlordFormScreen(
          landlordId: state.uri.queryParameters['landlordId'],
        ),
      ),
      GoRoute(
        path: adminLandlordDetailRoute,
        builder: (_, state) => AdminLandlordDetailScreen(
          landlordId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: adminPropertiesRoute,
        builder: (_, __) => const AdminPropertiesScreen(),
      ),
      GoRoute(
        path: adminPropertyFormRoute,
        builder: (_, state) => AdminPropertyFormScreen(
          propertyId: state.uri.queryParameters['propertyId'],
          landlordId: state.uri.queryParameters['landlordId'],
        ),
      ),
      GoRoute(
        path: adminPropertyDetailRoute,
        builder: (_, state) => AdminPropertyDetailScreen(
          propertyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: propertiesRoute,
        builder: (_, __) => const PropertiesListScreen(),
      ),
      GoRoute(
        path: propertyFormRoute,
        builder: (_, state) => PropertyFormScreen(
          propertyId: state.uri.queryParameters['propertyId'],
        ),
      ),
      // `/rooms/form` must precede `/rooms/:id` so it is not captured as an id.
      GoRoute(
        path: roomFormRoute,
        builder: (_, state) =>
            RoomFormScreen(roomId: state.uri.queryParameters['roomId']),
      ),
      GoRoute(
        path: roomDetailRoute,
        builder: (_, state) =>
            RoomDetailScreen(roomId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: tenantsRoute,
        builder: (_, __) => const TenantsListScreen(),
      ),
      // `/tenants/form` must precede `/tenants/:id` so it is not captured as id.
      GoRoute(
        path: tenantFormRoute,
        builder: (_, state) =>
            TenantFormScreen(tenantId: state.uri.queryParameters['tenantId']),
      ),
      GoRoute(
        path: tenantDetailRoute,
        builder: (_, state) =>
            TenantDetailScreen(tenantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: leaseFormRoute,
        builder: (_, state) => LeaseFormScreen(
          tenantId: state.uri.queryParameters['tenantId']!,
        ),
      ),
      GoRoute(
        path: billingRoute,
        builder: (_, __) => const BillingScreen(),
      ),
      GoRoute(
        path: bulkBillingRoute,
        builder: (_, __) => const BulkInvoiceScreen(),
      ),
      GoRoute(
        path: billingFormRoute,
        builder: (_, __) => const BillingFormScreen(),
      ),
      GoRoute(
        path: billingDetailRoute,
        builder: (_, state) => InvoiceDetailScreen(
          invoiceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: expensesRoute,
        builder: (_, __) => const ExpensesScreen(),
      ),
      GoRoute(
        path: expenseFormRoute,
        builder: (_, state) => ExpenseFormScreen(
          expenseId: state.uri.queryParameters['expenseId'],
        ),
      ),
      GoRoute(
        path: maintenanceRoute,
        builder: (_, __) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: maintenanceFormRoute,
        builder: (_, state) => MaintenanceFormScreen(
          ticketId: state.uri.queryParameters['ticketId'],
        ),
      ),
      GoRoute(
        path: reportsRoute,
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: staffRoute,
        builder: (_, __) => const StaffScreen(),
      ),
      GoRoute(
        path: auditRoute,
        builder: (_, __) => const AuditScreen(),
      ),
      GoRoute(
        path: notificationsRoute,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: actionItemsRoute,
        builder: (_, __) => const ActionItemsScreen(),
      ),
      GoRoute(
        path: leaseExpiryRoute,
        builder: (_, __) => const LeaseExpiryScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class RentalRoomApp extends ConsumerWidget {
  const RentalRoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Atrium Living',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

extension AuthNavigation on BuildContext {
  void openLogin() => go(loginRoute);
  void openRegister() => go(registerRoute);
}

GoRouter get appRouter => throw StateError(
      'Use appRouterProvider inside a ProviderScope.',
    );
