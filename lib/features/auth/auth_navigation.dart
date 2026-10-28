import 'package:go_router/go_router.dart';

import '../../models/auth_models.dart';
import 'auth_providers.dart';

const splashRoute = '/splash';
const exploreRoute = '/explore';
const publicListingRoute = '/explore/listings/:id';
const seekerAccountRoute = '/explore/account';
const housingFavoritesRoute = '/housing/favorites';
const housingViewingsRoute = '/housing/viewings';
const housingNoticesRoute = '/housing/notifications';
const rentalPilotRoute = '/housing/pilot';
const pilotFeedbackRoute = '/admin/pilot-feedback';
const landlordListingsRoute = '/listings';
const adminListingsRoute = '/admin/listings';
const landlordReviewsRoute = '/listings/reviews';
const adminReviewsRoute = '/admin/room-reviews';
String publicListingPath(String id) =>
    '/explore/listings/${Uri.encodeComponent(id)}';
bool isPublicDiscoveryLocation(String location) =>
    location == exploreRoute ||
    location == seekerAccountRoute ||
    RegExp(r'^/explore/listings/[^/]+$').hasMatch(location);
const onboardingRoute = '/onboarding';
const loginRoute = '/auth/login';
const registerRoute = '/auth/register';
const tenantInviteRoute = '/tenant/activate';
const staffInviteRoute = '/staff/activate';
const dashboardRoute = '/dashboard';
const chatbotRoute = '/chatbot';
const settingsRoute = '/settings';
const settingsPasswordRoute = '/settings/password';
const fakeZaloRoute = '/settings/fake-zalo';
const tenantPortalRoute = '/tenant';
const tenantPasswordRoute = '/tenant/password';
const tenantZaloRoute = '/tenant/zalo';
const tenantNotificationsRoute = '/tenant/notifications';
const tenantLeasesRoute = '/tenant/leases';
const tenantInvoicesRoute = '/tenant/invoices';
const tenantInvoiceDetailRoute = '/tenant/invoices/:id';
const tenantMaintenanceRoute = '/tenant/maintenance';
const adminRoute = '/admin';
const adminSecurityRoute = '/admin/security';
const adminSessionsRoute = '/admin/sessions';
const adminSearchRoute = '/admin/search';
const adminPoliciesRoute = '/admin/moderation-policies';
const adminAccountsRoute = '/admin/accounts';
const adminAuditLogsRoute = '/admin/audit-logs';
const adminOperationsRoute = '/admin/operations';
const adminModerationRoute = '/admin/moderation';
const adminSupportRoute = '/admin/support';
const adminSupportCenterRoute = '/admin/support-center';
const adminTicketsRoute = '/admin/tickets';
const adminModerationV2Route = '/admin/moderation-v2';
const adminGovernanceRoute = '/admin/governance';
const adminFinanceReconciliationRoute = '/admin/finance-reconciliation';
const adminReportSchedulesRoute = '/admin/report-schedules';
const adminTeamsRoute = '/admin/teams';
const adminPermissionSimulatorRoute = '/admin/permission-simulator';
const adminReportsRoute = '/admin/reports';
const adminOverviewReportsRoute = '/admin/reports/overview';
const adminNotificationsRoute = '/admin/notifications';
const supportCenterRoute = '/support-center';
const adminAdminsRoute = '/admin/admins';
const accountAccessRoute = '/account/activate';
const adminLandlordsRoute = '/admin/landlords';
const adminLandlordFormRoute = '/admin/landlords/form';
const adminLandlordDetailRoute = '/admin/landlords/:id';
const adminPropertiesRoute = '/admin/properties';
const adminRoomsRoute = '/admin/rooms';
const adminVerificationsRoute = '/admin/landlord-verifications';
const adminPropertyReviewsRoute = '/admin/property-reviews';
const adminPlansRoute = '/admin/service-plans';
const adminSubscriptionsRoute = '/admin/subscriptions';
String adminRoomsPath({String? propertyId}) => Uri(
        path: adminRoomsRoute,
        queryParameters: propertyId == null ? null : {'propertyId': propertyId})
    .toString();
String adminListingModerationPath(String listingId) => Uri(
    path: adminModerationRoute,
    queryParameters: {'kind': 'LISTING', 'search': listingId}).toString();
const adminPropertyFormRoute = '/admin/properties/form';
const adminPropertyDetailRoute = '/admin/properties/:id';
const propertiesRoute = '/properties';
const propertyFormRoute = '/properties/form';

String propertyFormPath({String? propertyId}) => propertyId == null
    ? propertyFormRoute
    : '$propertyFormRoute?propertyId=$propertyId';

// Rooms feature. `roomFormRoute` handles both create (no id) and edit (?roomId=).
const roomDetailRoute = '/rooms/:id';
const roomFormRoute = '/rooms/form';

String roomDetailPath(String id) => '/rooms/$id';

String roomFormPath({String? roomId}) =>
    roomId == null ? roomFormRoute : '$roomFormRoute?roomId=$roomId';

// Tenants & leases. `tenantFormRoute` handles create (no id) and edit (?tenantId=).
const tenantsRoute = '/tenants';
const tenantDetailRoute = '/tenants/:id';
const tenantFormRoute = '/tenants/form';
const leaseFormRoute = '/leases/form';
const billingRoute = '/billing';
const billingTariffsRoute = '/billing/tariffs';
const billingDetailRoute = '/billing/:id';
const billingFormRoute = '/billing/form';
const bulkBillingRoute = '/billing/bulk';
const expensesRoute = '/expenses';
const expenseFormRoute = '/expenses/form';
const maintenanceRoute = '/maintenance';
const maintenanceFormRoute = '/maintenance/form';
const reportsRoute = '/reports';
const staffRoute = '/staff';
const auditRoute = '/audit';
const notificationsRoute = '/notifications';
const actionItemsRoute = '/actions';
const p1OperationsRoute = '/operations/p1';
const leaseExpiryRoute = '/lease-expiry';

String tenantDetailPath(String id) => '/tenants/$id';

String tenantFormPath({String? tenantId}) =>
    tenantId == null ? tenantFormRoute : '$tenantFormRoute?tenantId=$tenantId';

/// Lease creation form for a specific tenant.
String leaseFormPath({required String tenantId}) =>
    '$leaseFormRoute?tenantId=$tenantId';

String billingDetailPath(String id) => '/billing/$id';

String tenantInvoiceDetailPath(String id) => '/tenant/invoices/$id';

String expenseFormPath({String? expenseId}) => expenseId == null
    ? expenseFormRoute
    : '$expenseFormRoute?expenseId=$expenseId';

String maintenanceFormPath({String? ticketId}) => ticketId == null
    ? maintenanceFormRoute
    : '$maintenanceFormRoute?ticketId=$ticketId';

String adminLandlordDetailPath(String id) => '/admin/landlords/$id';
String adminLandlordFormPath({String? landlordId}) => landlordId == null
    ? adminLandlordFormRoute
    : '$adminLandlordFormRoute?landlordId=$landlordId';
String adminPropertyDetailPath(String id) => '/admin/properties/$id';
String adminPropertyFormPath({String? propertyId, String? landlordId}) {
  final params = <String, String>{
    if (propertyId != null) 'propertyId': propertyId,
    if (landlordId != null) 'landlordId': landlordId,
  };
  if (params.isEmpty) return adminPropertyFormRoute;
  return '$adminPropertyFormRoute?${Uri(queryParameters: params).query}';
}

bool sessionHasPermission(AuthSession? session, String permission) {
  if (session == null) return false;
  if (session.user.role == 'landlord') return true;
  if (session.user.role != 'staff') return false;
  return session.user.permissions.contains(permission);
}

bool sessionHasAnyPermission(
    AuthSession? session, Iterable<String> permissions) {
  for (final permission in permissions) {
    if (sessionHasPermission(session, permission)) return true;
  }
  return false;
}

bool _staffCanAccessLocation(Set<String> permissions, String location) {
  bool has(String permission) => permissions.contains(permission);
  bool hasAny(Iterable<String> items) => items.any(permissions.contains);

  if (location == dashboardRoute) {
    return has('report.view');
  }
  if (location == propertyFormRoute) {
    return has('property.manage');
  }
  if (location == propertiesRoute || location.startsWith('/properties/')) {
    return hasAny(['property.view', 'property.manage']);
  }
  if (location == roomFormRoute) {
    return has('room.manage');
  }
  if (location.startsWith('/rooms/')) {
    return hasAny(['room.view', 'room.manage']);
  }
  if (location == tenantFormRoute) {
    return has('tenant.manage');
  }
  if (location == tenantsRoute || location.startsWith('/tenants/')) {
    return hasAny(['tenant.view', 'tenant.manage']);
  }
  if (location == leaseFormRoute) {
    return has('lease.manage');
  }
  if (location.startsWith('/leases/')) {
    return hasAny(['lease.view', 'lease.manage']);
  }
  if (location == billingFormRoute || location == bulkBillingRoute) {
    return has('billing.create');
  }
  if (location == billingTariffsRoute) {
    return has('billing.view');
  }
  if (location == billingRoute || location.startsWith('/billing/')) {
    return hasAny(['billing.view', 'billing.create']);
  }
  if (location == expenseFormRoute) {
    return has('expense.manage');
  }
  if (location == expensesRoute || location.startsWith('/expenses/')) {
    return hasAny(['expense.view', 'expense.manage']);
  }
  if (location == maintenanceFormRoute) {
    return has('maintenance.manage');
  }
  if (location == maintenanceRoute || location.startsWith('/maintenance/')) {
    return hasAny([
      'maintenance.view',
      'maintenance.manage',
      'maintenance.complete',
    ]);
  }
  if (location == reportsRoute) {
    return has('report.view');
  }
  if (location == staffRoute) {
    return hasAny(['staff.view', 'staff.manage']);
  }
  if (location == auditRoute) {
    return has('audit.view');
  }
  if (location == notificationsRoute) {
    return has('notification.view');
  }
  if (location == actionItemsRoute) {
    return has('operation.view');
  }
  if (location == p1OperationsRoute) {
    return hasAny([
      'room.view',
      'room.manage',
      'operation.view',
      'operation.manage',
      'notification.view',
      'notification.manage'
    ]);
  }
  if (location == leaseExpiryRoute) {
    return has('lease.view');
  }
  if (location == fakeZaloRoute) {
    return has('notification.view');
  }
  if (_isSettingsRoute(location)) return true;
  return false;
}

String homeRouteForSession(AuthSession session) {
  if (session.user.role == 'admin') {
    return session.user.adminMfaRequired && !session.user.adminMfaVerified
        ? adminSecurityRoute
        : adminRoute;
  }
  if (session.user.role == 'tenant') return exploreRoute;
  if (session.user.role == 'staff') {
    final permissions = session.user.permissions.toSet();
    if (permissions.contains('report.view')) {
      return dashboardRoute;
    }
    if (permissions.contains('property.view') ||
        permissions.contains('property.manage') ||
        permissions.contains('room.view') ||
        permissions.contains('room.manage')) {
      return propertiesRoute;
    }
    if (permissions.contains('tenant.view') ||
        permissions.contains('tenant.manage')) {
      return tenantsRoute;
    }
    if (permissions.contains('billing.view') ||
        permissions.contains('billing.create')) {
      return billingRoute;
    }
    if (permissions.contains('maintenance.view') ||
        permissions.contains('maintenance.manage') ||
        permissions.contains('maintenance.complete')) {
      return maintenanceRoute;
    }
    if (permissions.contains('expense.view') ||
        permissions.contains('expense.manage')) {
      return expensesRoute;
    }
    if (permissions.contains('audit.view')) return auditRoute;
    if (permissions.contains('notification.view')) return notificationsRoute;
    if (permissions.contains('operation.view')) return actionItemsRoute;
    if (permissions.contains('operation.manage') ||
        permissions.contains('notification.manage')) {
      return p1OperationsRoute;
    }
    if (permissions.contains('staff.view') ||
        permissions.contains('staff.manage')) {
      return staffRoute;
    }
    return settingsRoute;
  }
  return dashboardRoute;
}

void goToHomeForSession(GoRouter router, AuthSession session) {
  router.go(homeRouteForSession(session));
}

bool _isLandlordRoute(String location) {
  return location == landlordListingsRoute ||
      location.startsWith('/listings/') ||
      location == dashboardRoute ||
      location == chatbotRoute ||
      location.startsWith('/chatbot/') ||
      location.startsWith('/properties') ||
      location.startsWith('/rooms') ||
      location.startsWith('/tenants') ||
      location.startsWith('/leases') ||
      location.startsWith('/billing') ||
      location.startsWith('/expenses') ||
      location.startsWith('/maintenance') ||
      location.startsWith('/reports') ||
      location.startsWith('/audit') ||
      location.startsWith('/notifications') ||
      location.startsWith('/actions') ||
      location.startsWith('/operations/p1') ||
      location.startsWith('/lease-expiry') ||
      location.startsWith('/staff');
}

bool _isAdminRoute(String location) {
  return location == adminRoute || location.startsWith('/admin/');
}

bool _isTenantRoute(String location) {
  return location == tenantPortalRoute || location.startsWith('/tenant/');
}

bool _isSettingsRoute(String location) {
  return location == settingsRoute || location.startsWith('/settings/');
}

bool _isSupportRoute(String location) =>
    location == supportCenterRoute ||
    location.startsWith('$supportCenterRoute/');

String? authRedirect({
  required SessionState state,
  required String location,
  String? next,
}) {
  final isSplash = location == splashRoute;
  final isOnboarding = location == onboardingRoute;
  final isLogin = location == loginRoute;
  final isRegister = location == registerRoute;
  final isTenantInvite = location == tenantInviteRoute;
  final isStaffInvite = location == staffInviteRoute;
  final isAdmin = _isAdminRoute(location);
  final isLandlordRoute = _isLandlordRoute(location);
  final isTenantRoute = _isTenantRoute(location);
  final isSettingsRoute = _isSettingsRoute(location);
  final isSupport = _isSupportRoute(location);

  if (state.status == SessionStatus.checking) {
    if (isPublicDiscoveryLocation(location)) {
      return '$splashRoute?next=${Uri.encodeComponent(location)}';
    }
    return isSplash ? null : splashRoute;
  }

  final session = state.session;
  if (location.startsWith('/housing/')) {
    if (session == null) return loginRoute;
    final role = session.user.role;
    if (role != 'tenant' && role != 'landlord') {
      return homeRouteForSession(session);
    }
    if (location == housingFavoritesRoute && role != 'tenant') {
      return homeRouteForSession(session);
    }
  }
  if (state.status == SessionStatus.unauthenticated || session == null) {
    if (isTenantInvite || isStaffInvite) return null;
    return isLandlordRoute ||
            isAdmin ||
            isTenantRoute ||
            isSettingsRoute ||
            isSupport
        ? loginRoute
        : null;
  }

  final home = homeRouteForSession(session);
  if (session.user.role == 'admin' && isAdmin) {
    if (location.startsWith(adminVerificationsRoute) &&
        !session.user.permissions.contains('admin.support.read')) {
      return adminRoute;
    }
    if (session.user.adminMfaRequired &&
        !session.user.adminMfaVerified &&
        location != adminSecurityRoute) {
      return adminSecurityRoute;
    }
    final extraPermission = {
      adminVerificationsRoute: 'admin.verifications.view',
      adminPropertyReviewsRoute: 'admin.properties.view',
      adminPlansRoute: 'admin.plans.view',
      adminSubscriptionsRoute: 'admin.plans.view',
      adminPoliciesRoute: 'admin.moderation.reports',
      adminOverviewReportsRoute: 'admin.dashboard.view',
      adminReportsRoute: 'admin.reports.manage',
      adminNotificationsRoute: 'admin.notifications.view'
    }[location];
    if (extraPermission != null &&
        !session.user.permissions.contains(extraPermission)) {
      return adminRoute;
    }
    final permission = location.startsWith(adminOverviewReportsRoute)
        ? 'admin.dashboard.view'
        : location.startsWith(adminAccountsRoute)
            ? 'admin.accounts.view'
            : location.startsWith(adminAuditLogsRoute)
                ? 'admin.audit.view'
                : location.startsWith(adminOperationsRoute)
                    ? 'admin.operations.view'
                    : location.startsWith(adminSupportRoute)
                        ? 'admin.support.read'
                        : location.startsWith(adminSupportCenterRoute)
                            ? 'admin.support.read'
                            : location.startsWith(adminTicketsRoute)
                                ? 'admin.support.read'
                                : location.startsWith(adminModerationV2Route)
                                    ? 'admin.moderation.reports'
                                    : location.startsWith(adminGovernanceRoute)
                                        ? 'admin.flags.manage'
                                        : location.startsWith(
                                                adminFinanceReconciliationRoute)
                                            ? 'admin.finance.read'
                                            : location.startsWith(
                                                    adminReportSchedulesRoute)
                                                ? 'admin.reports.manage'
                                                : location.startsWith(
                                                        adminTeamsRoute)
                                                    ? 'admin.teams.manage'
                                                    : location.startsWith(
                                                            adminPermissionSimulatorRoute)
                                                        ? 'admin.permissions.simulate'
                                                        : location.startsWith(
                                                                adminAdminsRoute)
                                                            ? 'admin.admins.manage'
                                                            : location.startsWith(
                                                                    adminLandlordsRoute)
                                                                ? 'admin.accounts.manage'
                                                                : location.startsWith(
                                                                        adminPropertyFormRoute)
                                                                    ? 'admin.properties.manage'
                                                                    : location.startsWith(adminPropertiesRoute) ||
                                                                            location.startsWith(
                                                                                adminRoomsRoute)
                                                                        ? 'admin.properties.view'
                                                                        : location.startsWith(adminListingsRoute) ||
                                                                                location == pilotFeedbackRoute
                                                                            ? 'admin.listings.moderate'
                                                                            : location.startsWith(adminReviewsRoute)
                                                                                ? 'admin.reviews.moderate'
                                                                                : null;
    if (permission != null && !session.user.permissions.contains(permission)) {
      return adminRoute;
    }
    if (location == adminModerationRoute &&
        !session.user.permissions.any((permission) =>
            permission == 'admin.listings.moderate' ||
            permission == 'admin.reviews.moderate')) {
      return adminRoute;
    }
  }
  if (isLogin ||
      isRegister ||
      isOnboarding ||
      isTenantInvite ||
      isStaffInvite) {
    if (isLogin && next != null && isPublicDiscoveryLocation(next)) return next;
    return home;
  }
  if (session.user.role == 'admin' && (isLandlordRoute || isTenantRoute)) {
    return adminRoute;
  }
  if (session.user.role == 'tenant' && (isLandlordRoute || isAdmin)) {
    return exploreRoute;
  }
  if (session.user.role == 'landlord' && (isAdmin || isTenantRoute)) {
    return dashboardRoute;
  }
  if (location == fakeZaloRoute && session.user.role != 'landlord') {
    return home;
  }
  if (session.user.role == 'staff') {
    final permissions = session.user.permissions.toSet();
    if (isAdmin || isTenantRoute) {
      return home;
    }
    if (location == fakeZaloRoute &&
        !permissions.contains('notification.view')) {
      return home;
    }
    if ((isLandlordRoute || isSettingsRoute) &&
        !_staffCanAccessLocation(permissions, location)) {
      return home;
    }
  }
  return null;
}
