import { Module } from '@nestjs/common';
import { ListingsModule } from '../listings/listings.module';
import { ReviewsModule } from '../reviews/reviews.module';
import { GovernanceController } from './governance.controller';
import { GovernanceService } from './governance.service';
import { ModerationV2Controller, MyModerationController } from './moderation-v2.controller';
import { ModerationV2Service } from './moderation-v2.service';
import { AdminReportWorkerService } from './admin-report-worker.service';
import { ModerationPolicyController } from './moderation-policy.controller';
import { ModerationPolicyService } from './moderation-policy.service';
import { FinanceReconciliationController } from './finance-reconciliation.controller';
import { FinanceReconciliationService } from './finance-reconciliation.service';
import { ReportObjectStorageService } from './report-object-storage.service';
import { ModerationQualityService } from './moderation-quality.service';

@Module({
  imports: [ListingsModule, ReviewsModule],
  controllers: [GovernanceController, ModerationV2Controller, MyModerationController, ModerationPolicyController, FinanceReconciliationController],
  providers: [GovernanceService, ModerationV2Service, AdminReportWorkerService, ModerationPolicyService, ModerationQualityService, FinanceReconciliationService, ReportObjectStorageService],
})
export class PlatformModule {}
