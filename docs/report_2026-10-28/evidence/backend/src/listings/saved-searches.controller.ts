import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { PublicListingsQuery, SavedSearchDto, SavedSearchStatusDto } from './listings.dto';
import { SavedSearchesService } from './saved-searches.service';

@Controller('student/searches')
@Roles(AuthRole.TENANT)
export class SavedSearchesController {
  constructor(private readonly searches: SavedSearchesService) {}
  @Get() list(@CurrentUser() user: AuthUser) { return this.searches.list(user.userId); }
  @Post() create(@CurrentUser() user: AuthUser, @Body() body: SavedSearchDto) { return this.searches.create(user.userId, body); }
  @Get('alerts') alerts(@CurrentUser() user: AuthUser, @Query() query: PublicListingsQuery) { return this.searches.alerts(user.userId, query.page); }
  @Post('alerts/:id/read') read(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.searches.read(user.userId, id); }
  @Patch(':id') status(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() body: SavedSearchStatusDto) { return this.searches.status(user.userId, id, body.enabled); }
  @Delete(':id') remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.searches.remove(user.userId, id); }
}
