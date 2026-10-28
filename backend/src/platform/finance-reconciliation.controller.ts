import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { FinanceLinesQueryDto, FinanceProposalDto, FinanceProposalReviewDto, FinanceStatementImportDto } from './finance-reconciliation.dto';
import { FinanceReconciliationService } from './finance-reconciliation.service';

@Controller('admin/finance')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.finance.read', 'admin.finance.reconcile')
export class FinanceReconciliationController {
  constructor(private readonly reconciliation: FinanceReconciliationService) {}
  @Post('statements') importStatement(@CurrentUser() actor: AuthUser, @Body() input: FinanceStatementImportDto) { return this.reconciliation.importStatement(actor, input); }
  @Get('statement-lines') @AdminPermissions('admin.finance.read') lines(@CurrentUser() actor: AuthUser, @Query() query: FinanceLinesQueryDto) { return this.reconciliation.lines(actor, query); }
  @Post('statement-lines/:id/proposals') propose(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: FinanceProposalDto) { return this.reconciliation.propose(actor, id, input); }
  @Get('statement-lines/:id/candidates') candidates(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.reconciliation.candidates(actor, id); }
  @Get('reconciliation-proposals') proposals(@CurrentUser() actor: AuthUser) { return this.reconciliation.proposals(actor); }
  @Post('reconciliation-proposals/:id/approve') approve(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: FinanceProposalReviewDto) { return this.reconciliation.review(actor, id, input, true); }
  @Post('reconciliation-proposals/:id/reject') reject(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: FinanceProposalReviewDto) { return this.reconciliation.review(actor, id, input, false); }
}
