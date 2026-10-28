import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { AdvanceTurnoverDto, CheckTaskDto, CreateRecurringDto, CreateTurnoverDto, OperationsQuery, TaskQuery, ToggleRecurringDto } from './p1.dto';
import { RecurringService } from './recurring.service';
import { TurnoversService } from './turnovers.service';
import { PrismaService } from '../prisma/prisma.service';
import { landlordScopeId } from '../common/current-user.decorator';

@Controller('operations')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class P1OperationsController {
  constructor(private readonly turnovers: TurnoversService, private readonly recurring: RecurringService, private readonly prisma: PrismaService) {}
  @Get('options') @RequirePermissions('room.manage', 'operation.manage', 'notification.manage')
  async options(@CurrentUser() user: AuthUser) {
    const landlordId = landlordScopeId(user);
    const [properties, tenants] = await Promise.all([
      this.prisma.property.findMany({ where: { landlordId, isArchived: false }, select: { id: true, name: true, rooms: { where: { isActive: true }, select: { id: true, name: true, status: true }, orderBy: { name: 'asc' } } }, orderBy: { name: 'asc' } }),
      user.role === AuthRole.LANDLORD || user.permissions?.includes('notification.manage') ? this.prisma.tenant.findMany({ where: { landlordId, isActive: true }, select: { id: true, fullName: true }, orderBy: { fullName: 'asc' } }) : Promise.resolve([]),
    ]);
    return { data: { properties, tenants } };
  }
  @Get('turnovers') @RequirePermissions('room.view', 'room.manage') list(@CurrentUser() user: AuthUser, @Query() query: OperationsQuery) { return this.turnovers.list(user, query); }
  @Post('turnovers') @RequirePermissions('room.manage') create(@CurrentUser() user: AuthUser, @Body() input: CreateTurnoverDto) { return this.turnovers.create(user, input); }
  @Post('turnovers/:id/advance') @RequirePermissions('room.manage') advance(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: AdvanceTurnoverDto) { return this.turnovers.advance(user, id, input); }
  @Get('recurring') @RequirePermissions('operation.view', 'operation.manage') templates(@CurrentUser() user: AuthUser, @Query() query: OperationsQuery) { return this.recurring.templates(user, query); }
  @Post('recurring') @RequirePermissions('operation.manage') createRecurring(@CurrentUser() user: AuthUser, @Body() input: CreateRecurringDto) { return this.recurring.create(user, input); }
  @Patch('recurring/:id') @RequirePermissions('operation.manage') toggle(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: ToggleRecurringDto) { return this.recurring.toggle(user, id, input.isEnabled); }
  @Get('tasks') @RequirePermissions('operation.view', 'operation.manage') tasks(@CurrentUser() user: AuthUser, @Query() query: TaskQuery) { return this.recurring.tasks(user, query); }
  @Patch('tasks/:id/checklist') @RequirePermissions('operation.manage') check(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: CheckTaskDto) { return this.recurring.check(user, id, input); }
}
