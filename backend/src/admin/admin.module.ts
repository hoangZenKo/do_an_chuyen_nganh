import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';

import { AuthModule } from '../auth/auth.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AuditModule } from '../audit/audit.module';
import { AdminConsoleController } from './admin-console.controller';
import { AdminConsoleService } from './admin-console.service';
import { AccountAccessService } from '../auth/account-access.service';
import { HealthModule } from '../health/health.module';
import { AdminAuditQueryService } from './admin-audit-query.service';
import { AdminSearchController } from './admin-search.controller';
import { AdminSearchService } from './admin-search.service';
import { AdminStepUpController } from '../auth/admin-step-up.controller';
import { AdminAccessReviewController } from './admin-access-review.controller';
import { AdminAccessReviewService } from './admin-access-review.service';
import { AdminWorkspaceController } from './admin-workspace.controller';
import { AdminWorkspaceService } from './admin-workspace.service';
import { AdminLifecycleController } from './admin-lifecycle.controller';
import { AdminLifecycleService } from './admin-lifecycle.service';
import { AdminOverviewAnalyticsController } from './admin-overview-analytics.controller';
import { AdminOverviewAnalyticsService } from './admin-overview-analytics.service';
import { AdminRegistryController, LandlordVerificationController } from './admin-registry.controller';
import { AdminVerificationService } from './admin-verification.service';
import { AdminPropertyReviewService } from './admin-property-review.service';
import { AdminPlansService } from './admin-plans.service';
import { AdminTransactionsService } from './admin-transactions.service';

@Module({
  imports: [PassportModule, AuthModule, AuditModule, HealthModule],
  controllers: [AdminController, AdminConsoleController, AdminSearchController, AdminStepUpController, AdminAccessReviewController, AdminWorkspaceController, AdminLifecycleController, AdminOverviewAnalyticsController, AdminRegistryController, LandlordVerificationController],
  providers: [AdminService, AdminConsoleService, AdminAuditQueryService, AccountAccessService, AdminSearchService, AdminAccessReviewService, AdminWorkspaceService, AdminLifecycleService, AdminOverviewAnalyticsService, AdminVerificationService, AdminPropertyReviewService, AdminPlansService, AdminTransactionsService],
})
export class AdminModule {}
