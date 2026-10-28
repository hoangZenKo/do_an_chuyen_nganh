import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/listings/housing_screen.dart';
import '../features/chatbot/chatbot_screen.dart';
import '../features/admin/admin_workspace_screen.dart';
import '../features/admin/admin_landlord_detail_screen.dart';
import '../features/admin/admin_landlord_form_screen.dart';
import '../features/admin/admin_landlords_screen.dart';
import '../features/admin/admin_property_detail_screen.dart';
import '../features/admin/admin_property_form_screen.dart';
import '../features/admin/admin_properties_screen.dart';
import '../features/admin/admin_rooms_screen.dart';
import '../features/admin/admin_accounts_screen.dart';
import '../features/admin/admin_audit_screen.dart';
import '../features/admin/admin_moderation_screen.dart';
import '../features/admin/admin_security_screen.dart';
import '../features/admin/admin_sessions_screen.dart';
import '../features/admin/admin_search_screen.dart';
import '../features/admin/admin_policies_screen.dart';
import '../features/admin/admin_support_center.dart';
import '../features/admin/admin_moderation_v2.dart';
import '../features/admin/admin_governance.dart';
import '../features/admin/admin_overview_page.dart';
import '../features/admin/admin_overview_theme.dart';
import '../features/admin/admin_registry_screen.dart';
import '../features/auth/account_access_screen.dart';
import '../features/auth/account_access_link.dart';
import '../features/audit/audit_screen.dart';
import '../features/auth/auth_navigation.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/staff_invite_screen.dart';
import '../features/auth/tenant_invite_screen.dart';
import '../features/billing/billing_form_screen.dart';
import '../features/billing/billing_screen.dart';
import '../features/billing/billing_tariffs_screen.dart';
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
import '../features/operations/p1_operations_screen.dart';
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
import '../features/listings/explore_screen.dart';
import '../features/listings/listing_detail_screen.dart';
import '../features/listings/manage_listings_screen.dart';
import '../features/listings/manage_reviews_screen.dart';
import '../features/listings/seeker_account_screen.dart';
import '../features/listings/tenant_home_screen.dart';
import '../features/listings/listing_widgets.dart';
import '../features/tenant_portal/tenant_change_password_screen.dart';
import '../features/tenant_portal/tenant_invoice_detail_screen.dart';
import '../features/tenant_portal/tenant_invoices_screen.dart';
import '../features/tenant_portal/tenant_leases_screen.dart';
import '../features/tenant_portal/tenant_maintenance_screen.dart';
import '../features/tenant_portal/tenant_notifications_screen.dart';
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
      next: state.uri.queryParameters['next'],
    ),
    routes: [
      GoRoute(
          path: housingFavoritesRoute,
          builder: (_, __) =>
              const HousingScreen(section: HousingSection.favorites)),
      GoRoute(
          path: housingViewingsRoute,
          builder: (_, state) => HousingScreen(
              section: HousingSection.viewings,
              viewingId: state.uri.queryParameters['viewingId'])),
      GoRoute(
          path: housingNoticesRoute,
          builder: (_, __) =>
              const HousingScreen(section: HousingSection.notifications)),
      GoRoute(
          path: rentalPilotRoute,
          builder: (_, __) => const RentalPilotScreen()),
      GoRoute(
          path: pilotFeedbackRoute,
          builder: (_, __) =>
              const HousingScreen(section: HousingSection.feedback)),
      ShellRoute(
        builder: (_, state, child) => ListingNavigationShell(
          selectedIndex: switch (state.uri.path) {
            tenantPortalRoute => 1,
            seekerAccountRoute => 2,
            _ => 0,
          },
          child: child,
        ),
        routes: [
          GoRoute(
            path: exploreRoute,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const ExploreScreen(),
            ),
          ),
          GoRoute(
            path: tenantPortalRoute,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const TenantHomeScreen(),
            ),
          ),
          GoRoute(
            path: seekerAccountRoute,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const SeekerAccountScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
          path: publicListingRoute,
          builder: (_, state) =>
              ListingDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(
          path: landlordListingsRoute,
          builder: (_, __) => const ManageListingsScreen()),
      GoRoute(
          path: adminListingsRoute,
          builder: (_, __) => const ManageListingsScreen(admin: true)),
      GoRoute(
          path: landlordReviewsRoute,
          builder: (_, __) => const ManageReviewsScreen()),
      GoRoute(
          path: adminReviewsRoute,
          builder: (_, __) => const ManageReviewsScreen(admin: true)),
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
      GoRoute(path: chatbotRoute, builder: (_, __) => const ChatbotScreen()),
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
        path: tenantNotificationsRoute,
        builder: (_, __) => const TenantNotificationsScreen(),
      ),
      GoRoute(
        path: tenantLeasesRoute,
        builder: (_, __) => const TenantLeasesScreen(),
      ),
      GoRoute(
        path: tenantInvoicesRoute,
        builder: (_, __) => const TenantInvoicesScreen(),
      ),
      GoRoute(
        path: tenantInvoiceDetailRoute,
        builder: (_, state) => TenantInvoiceDetailScreen(
          invoiceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: tenantMaintenanceRoute,
        builder: (_, __) => const TenantMaintenanceScreen(),
      ),
      GoRoute(
          path: accountAccessRoute,
          builder: (_, state) =>
              AccountAccessScreen(token: accountAccessTokenFromUri(state.uri))),
      GoRoute(
          path: supportCenterRoute,
          builder: (_, state) => AdminSupportCenterScreen(
              userMode: true,
              initialTicketId: state.uri.queryParameters['ticketId'],
              initialTab: state.uri.queryParameters['tab'] ?? 'tickets')),
      ShellRoute(
        builder: (_, __, child) =>
            Theme(data: AdminOverviewTheme.light, child: child),
        routes: [
          GoRoute(
              path: adminRoute, builder: (_, __) => const AdminOverviewPage()),
          GoRoute(
              path: adminVerificationsRoute,
              builder: (_, __) => const AdminRegistryScreen(
                  section: AdminRegistrySection.verifications)),
          GoRoute(
              path: adminPropertyReviewsRoute,
              builder: (_, __) => const AdminRegistryScreen(
                  section: AdminRegistrySection.propertyReviews)),
          GoRoute(
              path: adminPlansRoute,
              builder: (_, __) => const AdminRegistryScreen(
                  section: AdminRegistrySection.plans)),
          GoRoute(
              path: adminSubscriptionsRoute,
              builder: (_, __) => const AdminRegistryScreen(
                  section: AdminRegistrySection.subscriptions)),
          GoRoute(
              path: '/admin/reports/overview',
              builder: (_, __) => const AdminOverviewPage(reports: true)),
          GoRoute(
              path: adminAccountsRoute,
              builder: (_, __) => const AdminAccountsScreen()),
          GoRoute(
              path: adminAuditLogsRoute,
              builder: (_, state) =>
                  AdminAuditScreen(initialFilters: state.uri.queryParameters)),
          GoRoute(
              path: adminOperationsRoute,
              builder: (_, state) => AdminWorkspaceScreen(
                  section: 'operations',
                  initialFilters: state.uri.queryParameters)),
          GoRoute(
              path: adminModerationRoute,
              builder: (_, state) => AdminModerationScreen(
                  initialFilters: state.uri.queryParameters)),
          GoRoute(
              path: adminSecurityRoute,
              builder: (_, __) => const AdminSecurityScreen()),
          GoRoute(
              path: adminSessionsRoute,
              builder: (_, __) => const AdminSessionsScreen()),
          GoRoute(
              path: adminSearchRoute,
              builder: (_, state) => AdminSearchScreen(
                    initialQuery: state.uri.queryParameters['q'],
                    initialKind: state.uri.queryParameters['kind'],
                    initialResourceId: state.uri.queryParameters['resourceId'],
                  )),
          GoRoute(
              path: adminPoliciesRoute,
              builder: (_, __) => const AdminPoliciesScreen()),
          GoRoute(
              path: '$adminAccountsRoute/:id',
              builder: (_, state) => AdminWorkspaceScreen(
                  section: 'accounts', accountId: state.pathParameters['id'])),
          GoRoute(
              path: adminSupportRoute,
              builder: (_, __) =>
                  const AdminWorkspaceScreen(section: 'support')),
          GoRoute(
              path: adminSupportCenterRoute,
              builder: (_, state) => AdminSupportCenterScreen(
                  initialTicketId: state.uri.queryParameters['ticketId'],
                  initialFilters: state.uri.queryParameters,
                  initialTab: state.uri.queryParameters['tab'] ?? 'tickets')),
          GoRoute(
              path: adminTicketsRoute,
              builder: (_, state) => AdminSupportCenterScreen(
                  initialFilters: state.uri.queryParameters,
                  initialTicketId: state.uri.queryParameters['ticketId'])),
          GoRoute(
              path: adminModerationV2Route,
              builder: (_, __) => const AdminModerationV2Screen()),
          GoRoute(
              path: adminNotificationsRoute,
              builder: (_, __) =>
                  const AdminSupportCenterScreen(initialTab: 'notifications')),
          GoRoute(
              path: adminGovernanceRoute,
              builder: (_, __) => const AdminGovernanceScreen()),
          GoRoute(
              path: adminFinanceReconciliationRoute,
              builder: (_, __) =>
                  const AdminGovernanceScreen(section: 'finance')),
          GoRoute(
              path: adminReportSchedulesRoute,
              builder: (_, __) =>
                  const AdminGovernanceScreen(section: 'reports')),
          GoRoute(
              path: adminReportsRoute,
              builder: (_, __) =>
                  const AdminGovernanceScreen(section: 'reports')),
          GoRoute(
              path: adminTeamsRoute,
              builder: (_, __) =>
                  const AdminGovernanceScreen(section: 'teams')),
          GoRoute(
              path: adminPermissionSimulatorRoute,
              builder: (_, __) =>
                  const AdminGovernanceScreen(section: 'simulator')),
          GoRoute(
              path: adminAdminsRoute,
              builder: (_, __) =>
                  const AdminWorkspaceScreen(section: 'admins')),
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
              path: adminRoomsRoute,
              builder: (_, state) => AdminRoomsScreen(
                  propertyId: state.uri.queryParameters['propertyId'])),
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
        ],
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
        builder: (_, state) => RoomDetailScreen(
          roomId: state.pathParameters['id']!,
          initialTab: state.uri.queryParameters['tab'] == 'inspections' ? 2 : 0,
        ),
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
        builder: (_, state) => Scaffold(
          appBar: AppBar(title: const Text('Hóa đơn')),
          body:
              BillingScreen(initialFilter: state.uri.queryParameters['filter']),
        ),
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
        path: billingTariffsRoute,
        builder: (_, __) => const BillingTariffsScreen(),
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
        builder: (_, state) => MaintenanceScreen(
          ticketId: state.uri.queryParameters['ticketId'],
        ),
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
        builder: (_, state) => ActionItemsScreen(
          propertyId: state.uri.queryParameters['propertyId'],
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: p1OperationsRoute,
        builder: (_, state) => P1OperationsScreen(
            initialSection:
                state.uri.queryParameters['section'] ?? 'turnovers'),
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
      theme: AppTheme.dark,
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
