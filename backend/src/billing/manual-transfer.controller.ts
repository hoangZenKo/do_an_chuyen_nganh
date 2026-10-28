import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Put } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { SaveTransferAccountDto } from './manual-transfer.dto';
import { ManualTransferService } from './manual-transfer.service';

@Controller('properties/:id/transfer-account')
@Roles(AuthRole.LANDLORD)
export class TransferAccountController {
  constructor(private readonly transfers: ManualTransferService) {}
  @Get() @Header('Cache-Control', 'private, no-store')
  account(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.transfers.account(actor, id); }
  @Put() @Header('Cache-Control', 'private, no-store')
  save(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SaveTransferAccountDto) { return this.transfers.save(actor, id, input); }
}

@Controller('tenant/invoices/:id/transfer-instructions')
@Roles(AuthRole.TENANT)
export class TransferInstructionsController {
  constructor(private readonly transfers: ManualTransferService) {}
  @Get() @Header('Cache-Control', 'private, no-store')
  instructions(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.transfers.instructions(actor.userId, id); }
}
