import 'reflect-metadata';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { ADMIN_PERMISSIONS, ADMIN_PERMISSIONS_KEY } from '../common/admin-permissions';
import { ROLES_KEY } from '../common/roles.constants';
import { AuthRole } from '../common/auth-role';
import { AdminConsoleController } from './admin-console.controller';
import { AdminController } from './admin.controller';
import { AdminAccessReviewController } from './admin-access-review.controller';
import { AdminSearchController } from './admin-search.controller';
import { GovernanceController } from '../platform/governance.controller';
import { ModerationV2Controller } from '../platform/moderation-v2.controller';
import { SupportCaseController } from '../support/support-case.controller';
import { SupportSlaController } from '../support/support-sla.controller';
import { IncidentWorkflowController } from '../health/incident-workflow.controller';
import { AdminStepUpController } from '../auth/admin-step-up.controller';
import { SupportWorkflowController } from '../support/support-workflow.controller';
import { ModerationPolicyController } from '../platform/moderation-policy.controller';
import { FinanceReconciliationController } from '../platform/finance-reconciliation.controller';
import { NotificationDeliveryController } from '../support/notification-delivery.controller';
import { AdminWorkspaceController } from './admin-workspace.controller';
import { AdminOverviewAnalyticsController } from './admin-overview-analytics.controller';
import { AdminLifecycleController } from './admin-lifecycle.controller';
import { OperationsQueueController } from '../health/operations-queue.controller';
import { AdminRegistryController } from './admin-registry.controller';

describe('admin route capability catalog', () => {
  const controllers = [AdminRegistryController, AdminController, AdminConsoleController, AdminAccessReviewController, AdminSearchController, GovernanceController, ModerationV2Controller, SupportCaseController, SupportSlaController, IncidentWorkflowController, AdminStepUpController, SupportWorkflowController, ModerationPolicyController, FinanceReconciliationController, NotificationDeliveryController, AdminWorkspaceController, AdminLifecycleController, OperationsQueueController, AdminOverviewAnalyticsController];
  for (const controller of controllers) {
    const methods = Object.getOwnPropertyNames(controller.prototype).filter(name => name !== 'constructor' && Reflect.hasMetadata(METHOD_METADATA, Reflect.get(controller.prototype, name)));
    for (const name of methods) {
      it(`${controller.name}.${name} declares an admin role and known capabilities`, () => {
        const handler = Reflect.get(controller.prototype, name);
        expect(Reflect.getMetadata(PATH_METADATA, controller)).toBeTruthy();
        const roles = Reflect.getMetadata(ROLES_KEY, handler) ?? Reflect.getMetadata(ROLES_KEY, controller);
        expect(roles).toContain(AuthRole.ADMIN);
        const required = Reflect.getMetadata(ADMIN_PERMISSIONS_KEY, handler) ?? Reflect.getMetadata(ADMIN_PERMISSIONS_KEY, controller);
        expect(required?.length).toBeGreaterThan(0);
        for (const permission of required) expect(ADMIN_PERMISSIONS).toContain(permission);
      });
    }
  }
});
