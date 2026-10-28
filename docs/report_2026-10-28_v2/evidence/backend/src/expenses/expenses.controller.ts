import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { ListExpensesQueryDto } from './dto/list-expenses-query.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { ExpensesService } from './expenses.service';

@Controller('expenses')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class ExpensesController {
  constructor(
    private readonly expenses: ExpensesService,
    private readonly audit: AuditService,
  ) {}

  @Get()
  @RequirePermissions('expense.view')
  list(@CurrentUser() user: AuthUser, @Query() query: ListExpensesQueryDto) {
    return this.expenses.list(landlordScopeId(user), query);
  }

  @Post()
  @RequirePermissions('expense.manage')
  async create(@CurrentUser() user: AuthUser, @Body() input: CreateExpenseDto) {
    const landlordId = landlordScopeId(user);
    const result = await this.expenses.create(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'expense.create',
      resourceType: 'expense',
      resourceId: result.data.id,
      summary: `Tạo chi phí ${result.data.amount}`,
      metadata: { amount: result.data.amount, category: result.data.category },
    });
    return result;
  }

  @Get(':id')
  @RequirePermissions('expense.view')
  getById(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.expenses.getById(landlordScopeId(user), id);
  }

  @Patch(':id')
  @RequirePermissions('expense.manage')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateExpenseDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.expenses.update(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'expense.update',
      resourceType: 'expense',
      resourceId: id,
      summary: `Cập nhật chi phí ${result.data.amount}`,
      metadata: { changedFields: Object.keys(input) },
    });
    return result;
  }

  @Delete(':id')
  @RequirePermissions('expense.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.expenses.remove(landlordId, id);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'expense.delete',
      resourceType: 'expense',
      resourceId: id,
      summary: 'Xóa chi phí',
    });
  }
}
