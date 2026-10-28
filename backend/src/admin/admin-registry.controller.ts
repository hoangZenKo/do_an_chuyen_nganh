import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AssignSubscriptionDto, CancelSubscriptionDto, RegistryPageDto, ReviewRegistryDto, SaveServicePlanDto, SubmitOwnVerificationDto, SubmitPropertyReviewDto, SubmitVerificationDto } from './admin-registry.dto';
import { AdminVerificationService } from './admin-verification.service';
import { AdminPropertyReviewService } from './admin-property-review.service';
import { AdminPlansService } from './admin-plans.service';
import { AdminTransactionsQuery, AdminTransactionsService } from './admin-transactions.service';

@Controller('admin')
@Roles(AuthRole.ADMIN)
export class AdminRegistryController {
  constructor(private readonly verification: AdminVerificationService, private readonly properties: AdminPropertyReviewService,
    private readonly plans: AdminPlansService, private readonly transactions: AdminTransactionsService) {}

  @Get('finance/transactions') @Header('Cache-Control', 'private, no-store') @AdminPermissions('admin.finance.read')
  transactionList(@CurrentUser() actor: AuthUser, @Query() query: AdminTransactionsQuery) { return this.transactions.list(actor, query); }

  @Get('landlord-verifications') @Header('Cache-Control', 'private, no-store') @AdminPermissions('admin.verifications.view', 'admin.support.read')
  verifications(@Query() query: RegistryPageDto) { return this.verification.list(query); }

  @Post('landlord-verifications') @AdminPermissions('admin.verifications.manage', 'admin.support.read')
  submitVerification(@CurrentUser() actor: AuthUser, @Body() input: SubmitVerificationDto) { return this.verification.submit(actor, input); }

  @Post('landlord-verifications/:id/review') @AdminPermissions('admin.verifications.manage', 'admin.support.read')
  reviewVerification(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewRegistryDto) { return this.verification.review(actor, id, input); }

  @Get('property-reviews') @Header('Cache-Control', 'private, no-store') @AdminPermissions('admin.properties.view')
  propertyReviews(@Query() query: RegistryPageDto) { return this.properties.list(query); }

  @Post('properties/:id/submit-review') @AdminPermissions('admin.properties.manage')
  submitProperty(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SubmitPropertyReviewDto) { return this.properties.submit(actor, id, input); }

  @Post('property-reviews/:id/review') @AdminPermissions('admin.properties.manage')
  reviewProperty(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewRegistryDto) { return this.properties.review(actor, id, input); }

  @Get('service-plans') @Header('Cache-Control', 'private, no-store') @AdminPermissions('admin.plans.view')
  servicePlans(@Query() query: RegistryPageDto) { return this.plans.plans(query); }

  @Post('service-plans') @AdminPermissions('admin.plans.manage')
  savePlan(@CurrentUser() actor: AuthUser, @Body() input: SaveServicePlanDto) { return this.plans.save(actor, input); }

  @Get('subscriptions') @Header('Cache-Control', 'private, no-store') @AdminPermissions('admin.plans.view')
  subscriptions(@Query() query: RegistryPageDto) { return this.plans.subscriptions(query); }

  @Get('subscriptions/:id/events') @Header('Cache-Control', 'private, no-store') @AdminPermissions('admin.plans.view')
  subscriptionEvents(@Param('id', ParseUUIDPipe) id: string, @Query() query: RegistryPageDto) { return this.plans.history(id, query); }

  @Post('landlords/:id/subscription') @AdminPermissions('admin.plans.manage')
  assignSubscription(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) landlordId: string, @Body() input: AssignSubscriptionDto) { return this.plans.assign(actor, landlordId, input); }

  @Post('subscriptions/:id/cancel') @AdminPermissions('admin.plans.manage')
  cancelSubscription(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: CancelSubscriptionDto) { return this.plans.cancel(actor, id, input); }
}

@Controller('landlord-verification')
@Roles(AuthRole.LANDLORD)
export class LandlordVerificationController {
  constructor(private readonly verification: AdminVerificationService) {}
  @Get() @Header('Cache-Control', 'private, no-store')
  own(@CurrentUser() actor: AuthUser) { return this.verification.own(actor.userId); }
  @Post()
  submit(@CurrentUser() actor: AuthUser, @Body() input: SubmitOwnVerificationDto) {
    return this.verification.submit(actor, { ...input, landlordId: actor.userId });
  }
}
