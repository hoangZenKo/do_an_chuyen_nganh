import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { CreateListingDto, ListingVersionDto, ManageListingsQuery, PublicListingsQuery, ReviewListingDto, UpdateListingDto, CreateListingReportDto, ReviewListingReportDto, SchoolCampusDto, UpdateSchoolCampusDto, ListingVerificationDto } from './listings.dto';
import { ListingsService } from './listings.service';

@Controller('public/campuses')
export class PublicCampusesController {
  constructor(private readonly listings: ListingsService) {}
  @Get()
  list() { return this.listings.campuses(); }
}

@Controller('admin/campuses')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.campuses.manage')
export class AdminCampusesController {
  constructor(private readonly listings: ListingsService) {}
  @Get()
  list() { return this.listings.campuses(true); }
  @Post()
  create(@Body() input: SchoolCampusDto) { return this.listings.createCampus(input); }
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() input: UpdateSchoolCampusDto) { return this.listings.updateCampus(id, input); }
}

@Controller('student/listings')
@Roles(AuthRole.TENANT)
export class StudentListingsController {
  constructor(private readonly listings: ListingsService) {}
  @Post(':id/reports')
  report(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: CreateListingReportDto) {
    return this.listings.report(user, id, input);
  }
}

@Controller('public/listings')
export class PublicListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get()
  list(@Query() query: PublicListingsQuery) { return this.listings.publicList(query); }

  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) { return this.listings.publicDetail(id); }
}

@Controller('listings')
@Roles(AuthRole.LANDLORD)
export class LandlordListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: ManageListingsQuery) {
    return this.listings.manageList(query, user.userId);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() input: CreateListingDto) {
    return this.listings.create(user, input);
  }

  @Patch(':id')
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: UpdateListingDto) {
    return this.listings.update(user, id, input);
  }

  @Post(':id/submit')
  submit(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ListingVersionDto) {
    return this.listings.submit(user, id, input);
  }

  @Post(':id/hide')
  hide(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ListingVersionDto) {
    return this.listings.hide(user, id, input);
  }

  @Post(':id/confirm-availability')
  confirm(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ListingVersionDto) {
    return this.listings.confirmAvailability(user, id, input);
  }
}

@Controller('admin/listings')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.listings.moderate')
export class AdminListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get('reports')
  reports(@Query() query: PublicListingsQuery) { return this.listings.reports(query); }

  @Post('reports/:id/review')
  reviewReport(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewListingReportDto) {
    return this.listings.reviewReport(user, id, input);
  }

  @Get()
  list(@Query() query: ManageListingsQuery) { return this.listings.manageList(query); }

  @Post(':id/review')
  review(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewListingDto) {
    return this.listings.review(user, id, input);
  }

  @Post(':id/verification')
  verify(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ListingVerificationDto) {
    return this.listings.verify(user, id, input);
  }
}
