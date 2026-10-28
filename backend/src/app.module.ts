import { Module } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { AuthorizationModule } from './common/authorization.module';
import { HealthModule } from './health/health.module';
import { PrismaModule } from './prisma/prisma.module';
import { PropertiesModule } from './properties/properties.module';
import { RoomsModule } from './rooms/rooms.module';
import { TenantsModule } from './tenants/tenants.module';
import { LeasesModule } from './leases/leases.module';
import { BillingModule } from './billing/billing.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { AdminModule } from './admin/admin.module';
import { ExpensesModule } from './expenses/expenses.module';
import { MaintenanceModule } from './maintenance/maintenance.module';
import { TenantPortalModule } from './tenant-portal/tenant-portal.module';
import { UploadsModule } from './uploads/uploads.module';
import { ReportsModule } from './reports/reports.module';
import { StaffModule } from './staff/staff.module';
import { AuditModule } from './audit/audit.module';
import { NotificationsModule } from './notifications/notifications.module';
import { OperationsModule } from './operations/operations.module';
import { ChatbotModule } from './chatbot/chatbot.module';
import { ListingsModule } from './listings/listings.module';
import { HousingModule } from './housing/housing.module';
import { ReviewsModule } from './reviews/reviews.module';
import { OnlinePaymentsModule } from './billing/online-payments.module';
import { DeliveryModule } from './delivery/delivery.module';
import { SupportModule } from './support/support.module';
import { FeatureFlagsModule } from './platform/feature-flags.service';
import { PlatformModule } from './platform/platform.module';
import { TenantLifecycleModule } from './tenant-lifecycle/tenant-lifecycle.module';
import { PropertyScopeInterceptor } from './common/property-scope';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ChatbotModule,
    ListingsModule,
    HousingModule,
    ReviewsModule,
    OnlinePaymentsModule,
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 60 }]),
    PrismaModule,
    DeliveryModule,
    FeatureFlagsModule,
    PlatformModule,
    TenantLifecycleModule,
    SupportModule,
    AuthorizationModule,
    AuthModule,
    HealthModule,
    PropertiesModule,
    RoomsModule,
    TenantsModule,
    LeasesModule,
    BillingModule,
    ExpensesModule,
    MaintenanceModule,
    TenantPortalModule,
    UploadsModule,
    ReportsModule,
    StaffModule,
    AuditModule,
    NotificationsModule,
    OperationsModule,
    DashboardModule,
    AdminModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }, { provide: APP_INTERCEPTOR, useClass: PropertyScopeInterceptor }],
})
export class AppModule {}
