import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { AcceptHandoverDto, CreateViewingDto, HandoverDto, HousingPageQuery, PilotFeedbackDto, RescheduleViewingDto, UpdateViewingDto, ViewingLeaseDto, ViewingSlotDto } from './housing.dto';
import { HousingService } from './housing.service';
import { HandoverService } from './handover.service';

@Controller('housing')
export class HousingController {
  constructor(private readonly housing: HousingService, private readonly handovers: HandoverService) {}

  @Get('listings/:id/slots') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  slots(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.housing.slots(user, id); }

  @Post('listings/:id/slots') @Roles(AuthRole.LANDLORD)
  addSlot(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ViewingSlotDto) {
    return this.housing.addSlot(user, id, input);
  }

  @Delete('slots/:id') @Roles(AuthRole.LANDLORD)
  removeSlot(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.housing.removeSlot(user, id); }

  @Patch('viewings/:id/reschedule') @Roles(AuthRole.TENANT)
  reschedule(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: RescheduleViewingDto) {
    return this.housing.reschedule(user, id, input);
  }

  @Get('leases/:id/handover') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  handover(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.handovers.get(user, id); }

  @Put('leases/:id/handover') @Roles(AuthRole.LANDLORD)
  saveHandover(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: HandoverDto) {
    return this.handovers.save(user, id, input);
  }

  @Post('leases/:id/handover/accept') @Roles(AuthRole.TENANT)
  acceptHandover(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AcceptHandoverDto) {
    return this.handovers.accept(user, id, input.version);
  }

  @Get('favorites') @Roles(AuthRole.TENANT)
  favorites(@CurrentUser() user: AuthUser, @Query() query: HousingPageQuery) {
    return this.housing.favorites(user.userId, query.page);
  }

  @Get('favorites/:id') @Roles(AuthRole.TENANT)
  favorite(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.housing.favorite(user.userId, id);
  }

  @Put('favorites/:id') @Roles(AuthRole.TENANT)
  save(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.housing.saveFavorite(user.userId, id);
  }

  @Delete('favorites/:id') @Roles(AuthRole.TENANT)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.housing.removeFavorite(user.userId, id);
  }

  @Get('viewings') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  viewings(@CurrentUser() user: AuthUser, @Query() query: HousingPageQuery) {
    return this.housing.viewings(user, query.page);
  }

  @Post('viewings') @Roles(AuthRole.TENANT)
  book(@CurrentUser() user: AuthUser, @Body() input: CreateViewingDto) { return this.housing.book(user, input); }

  @Get('viewings/:id') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  viewing(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.housing.viewing(user, id); }

  @Patch('viewings/:id') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: UpdateViewingDto) {
    return this.housing.update(user, id, input);
  }

  @Post('viewings/:id/lease') @Roles(AuthRole.LANDLORD)
  lease(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ViewingLeaseDto) {
    return this.housing.createLease(user, id, input);
  }

  @Get('notifications') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  notifications(@CurrentUser() user: AuthUser, @Query() query: HousingPageQuery) {
    return this.housing.notifications(user.userId, query.page);
  }

  @Post('notifications/:id/read') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  read(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.housing.readNotification(user.userId, id); }

  @Get('pilot') @Roles(AuthRole.TENANT, AuthRole.LANDLORD, AuthRole.ADMIN) @AdminPermissions('admin.dashboard.view')
  pilot() { return this.housing.pilot(); }

  @Post('feedback') @Roles(AuthRole.TENANT, AuthRole.LANDLORD)
  feedback(@CurrentUser() user: AuthUser, @Body() input: PilotFeedbackDto) { return this.housing.feedback(user.userId, input); }

  @Get('feedback') @Roles(AuthRole.ADMIN) @AdminPermissions('admin.listings.moderate')
  feedbackList(@Query() query: HousingPageQuery) { return this.housing.feedbackList(query.page); }
}
