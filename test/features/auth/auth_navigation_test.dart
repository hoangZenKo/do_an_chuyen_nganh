import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';

AuthSession sessionFor(String role) => AuthSession(
      user: LandlordUser(
        id: 'user-1',
        fullName: 'Test User',
        email: 'test@example.com',
        role: role,
        permissions: role == 'admin'
            ? const [
                'admin.dashboard.view',
                'admin.accounts.manage',
                'admin.properties.view',
                'admin.properties.manage'
              ]
            : const [],
      ),
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );

AuthSession sessionForStaff(List<String> permissions) => AuthSession(
      user: LandlordUser(
        id: 'user-1',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'staff',
        permissions: permissions,
      ),
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );

void main() {
  test('overview reporting uses dashboard rights, not report scheduling rights',
      () {
    final admin = sessionFor('admin');
    expect(
        authRedirect(
            state: SessionState.authenticated(admin),
            location: adminOverviewReportsRoute),
        isNull);
    expect(
        authRedirect(
            state: SessionState.authenticated(admin),
            location: adminReportsRoute),
        adminRoute);
    expect(
        authRedirect(
            state: const SessionState.unauthenticated(),
            location: adminOverviewReportsRoute),
        loginRoute);
    expect(
        authRedirect(
            state: SessionState.authenticated(sessionFor('landlord')),
            location: adminOverviewReportsRoute),
        dashboardRoute);
  });

  test(
      'new sprint routes enforce capabilities and protect support from anonymous access',
      () {
    const permissions = {
      adminSupportCenterRoute: 'admin.support.read',
      adminTicketsRoute: 'admin.support.read',
      adminModerationV2Route: 'admin.moderation.reports',
      adminGovernanceRoute: 'admin.flags.manage',
      adminFinanceReconciliationRoute: 'admin.finance.read',
      adminReportSchedulesRoute: 'admin.reports.manage',
      adminTeamsRoute: 'admin.teams.manage',
      adminPermissionSimulatorRoute: 'admin.permissions.simulate',
      adminReportsRoute: 'admin.reports.manage',
      adminNotificationsRoute: 'admin.notifications.view',
    };
    for (final entry in permissions.entries) {
      final user = AuthSession(
          user: LandlordUser(
              id: 'admin-1',
              fullName: 'Admin',
              email: 'test@example.com',
              role: 'admin',
              permissions: ['admin.dashboard.view', entry.value]),
          accessToken: 'access',
          refreshToken: 'refresh');
      expect(
          authRedirect(
              state: SessionState.authenticated(user), location: entry.key),
          isNull,
          reason: entry.key);
      expect(
          authRedirect(
              state: SessionState.authenticated(sessionFor('admin')),
              location: entry.key),
          adminRoute,
          reason: entry.key);
    }
    expect(
        authRedirect(
            state: const SessionState.unauthenticated(),
            location: supportCenterRoute),
        loginRoute);
    for (final role in ['landlord', 'tenant', 'staff']) {
      expect(
          authRedirect(
              state: SessionState.authenticated(sessionFor(role)),
              location: supportCenterRoute),
          isNull);
    }
  });
  test('operations route is capability-gated and still requires admin MFA', () {
    final restricted = sessionFor('admin');
    expect(
        authRedirect(
            state: SessionState.authenticated(restricted),
            location: adminOperationsRoute),
        adminRoute);
    const allowed = AuthSession(
        user: LandlordUser(
            id: 'admin-1',
            fullName: 'Admin',
            email: 'admin@example.com',
            role: 'admin',
            permissions: ['admin.dashboard.view', 'admin.operations.view']),
        accessToken: 'access',
        refreshToken: 'refresh');
    expect(
        authRedirect(
            state: const SessionState.authenticated(allowed),
            location: adminOperationsRoute),
        isNull);
    expect(
        authRedirect(
            state: SessionState.authenticated(sessionFor('landlord')),
            location: adminOperationsRoute),
        dashboardRoute);
    expect(
        authRedirect(
            state: const SessionState.unauthenticated(),
            location: adminOperationsRoute),
        loginRoute);
  });

  test('keeps splash visible while session is checking', () {
    expect(
      authRedirect(
        state: const SessionState.checking(),
        location: splashRoute,
      ),
      isNull,
    );
    expect(
      authRedirect(
        state: const SessionState.checking(),
        location: dashboardRoute,
      ),
      splashRoute,
    );
  });

  test('redirects unauthenticated protected routes to login', () {
    const state = SessionState.unauthenticated();
    for (final route in [
      dashboardRoute,
      adminRoute,
      adminLandlordsRoute,
      adminLandlordFormRoute,
      '/admin/landlords/user-1',
      adminPropertiesRoute,
      adminRoomsRoute,
      adminPropertyFormRoute,
      '$adminPropertyFormRoute?propertyId=property-1',
      '/admin/properties/property-1',
      propertiesRoute,
      propertyFormRoute,
      '/rooms/r1',
      roomFormRoute,
      tenantsRoute,
      '/tenants/t1',
      leaseFormRoute,
      billingFormRoute,
      tenantInvoicesRoute,
      '/tenant/invoices/i1',
      tenantMaintenanceRoute,
      tenantNotificationsRoute,
      tenantLeasesRoute,
    ]) {
      expect(authRedirect(state: state, location: route), loginRoute);
    }
    expect(authRedirect(state: state, location: loginRoute), isNull);
  });

  test('routes landlord away from admin and auth screens', () {
    final state = SessionState.authenticated(sessionFor('landlord'));

    for (final route in [
      adminRoute,
      adminLandlordsRoute,
      adminLandlordFormRoute,
      '/admin/landlords/user-1',
      adminPropertiesRoute,
      adminPropertyFormRoute,
      '/admin/properties/property-1',
    ]) {
      expect(authRedirect(state: state, location: route), dashboardRoute);
    }
    expect(authRedirect(state: state, location: loginRoute), dashboardRoute);
    expect(authRedirect(state: state, location: propertiesRoute), isNull);
    expect(authRedirect(state: state, location: propertyFormRoute), isNull);
    expect(authRedirect(state: state, location: '/rooms/r1'), isNull);
    expect(authRedirect(state: state, location: roomFormRoute), isNull);
    expect(authRedirect(state: state, location: tenantInvoicesRoute),
        dashboardRoute);
    expect(authRedirect(state: state, location: tenantMaintenanceRoute),
        dashboardRoute);
    expect(authRedirect(state: state, location: tenantNotificationsRoute),
        dashboardRoute);
    expect(authRedirect(state: state, location: tenantLeasesRoute),
        dashboardRoute);
  });

  test('routes admin away from landlord routes and auth screens', () {
    final state = SessionState.authenticated(sessionFor('admin'));

    for (final route in [
      dashboardRoute,
      propertiesRoute,
      propertyFormRoute,
      '/rooms/r1',
      roomFormRoute,
      tenantsRoute,
      '/tenants/t1',
      leaseFormRoute,
      billingFormRoute,
      tenantInvoicesRoute,
      '/tenant/invoices/i1',
      tenantMaintenanceRoute,
      tenantNotificationsRoute,
      tenantLeasesRoute,
    ]) {
      expect(authRedirect(state: state, location: route), adminRoute);
    }
    expect(authRedirect(state: state, location: loginRoute), adminRoute);
    for (final route in [
      adminRoute,
      adminLandlordsRoute,
      adminLandlordFormRoute,
      '/admin/landlords/user-1',
      adminPropertiesRoute,
      adminPropertyFormRoute,
      '/admin/properties/property-1',
    ]) {
      expect(authRedirect(state: state, location: route), isNull);
    }
  });

  test('routes login register and onboarding to home by role', () {
    expect(
      authRedirect(
        state: SessionState.authenticated(sessionFor('landlord')),
        location: loginRoute,
      ),
      dashboardRoute,
    );
    expect(
      authRedirect(
        state: SessionState.authenticated(sessionFor('admin')),
        location: registerRoute,
      ),
      adminRoute,
    );
    expect(
      authRedirect(
        state: SessionState.authenticated(sessionFor('landlord')),
        location: onboardingRoute,
      ),
      dashboardRoute,
    );
  });

  test('allows tenants to use their portal invoice routes', () {
    final state = SessionState.authenticated(sessionFor('tenant'));

    expect(authRedirect(state: state, location: tenantPortalRoute), isNull);
    expect(authRedirect(state: state, location: tenantInvoicesRoute), isNull);
    expect(authRedirect(state: state, location: '/tenant/invoices/i1'), isNull);
    expect(
        authRedirect(state: state, location: tenantMaintenanceRoute), isNull);
    expect(
        authRedirect(state: state, location: tenantNotificationsRoute), isNull);
    expect(authRedirect(state: state, location: tenantLeasesRoute), isNull);
    expect(authRedirect(state: state, location: billingRoute), exploreRoute);
  });

  test('routes staff to the first route they can actually use', () {
    expect(
      homeRouteForSession(sessionForStaff(const ['staff.view'])),
      staffRoute,
    );
    expect(
      homeRouteForSession(
        sessionForStaff(const ['property.view', 'room.view']),
      ),
      propertiesRoute,
    );
    expect(
      homeRouteForSession(sessionForStaff(const ['report.view'])),
      dashboardRoute,
    );
    expect(
      homeRouteForSession(sessionForStaff(const ['billing.view'])),
      billingRoute,
    );
    expect(
      homeRouteForSession(sessionForStaff(const <String>[])),
      settingsRoute,
    );
  });

  test('keeps staff away from routes they do not have permission for', () {
    final state = SessionState.authenticated(
      sessionForStaff(const ['staff.view']),
    );

    expect(authRedirect(state: state, location: billingRoute), staffRoute);
    expect(authRedirect(state: state, location: fakeZaloRoute), staffRoute);
    expect(authRedirect(state: state, location: adminRoute), staffRoute);
  });

  test('keeps view-only staff away from management forms', () {
    final propertyViewer = SessionState.authenticated(
      sessionForStaff(const ['property.view', 'room.view']),
    );
    expect(
      authRedirect(state: propertyViewer, location: propertyFormRoute),
      propertiesRoute,
    );
    expect(
      authRedirect(state: propertyViewer, location: roomFormRoute),
      propertiesRoute,
    );

    final billingViewer = SessionState.authenticated(
      sessionForStaff(const ['billing.view']),
    );
    expect(
      authRedirect(state: billingViewer, location: billingFormRoute),
      billingRoute,
    );
    expect(
      authRedirect(state: billingViewer, location: bulkBillingRoute),
      billingRoute,
    );

    final maintenanceViewer = SessionState.authenticated(
      sessionForStaff(const ['maintenance.view']),
    );
    expect(
      authRedirect(state: maintenanceViewer, location: maintenanceFormRoute),
      maintenanceRoute,
    );
  });

  test('blocks fake zalo for non-landlord roles', () {
    expect(
      authRedirect(
        state: SessionState.authenticated(sessionFor('tenant')),
        location: fakeZaloRoute,
      ),
      exploreRoute,
    );
    expect(
      authRedirect(
        state: SessionState.authenticated(sessionFor('admin')),
        location: fakeZaloRoute,
      ),
      adminRoute,
    );
  });
}
