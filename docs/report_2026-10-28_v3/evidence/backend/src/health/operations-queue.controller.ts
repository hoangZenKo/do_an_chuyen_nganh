import { Controller, Get, Header, Query } from '@nestjs/common';
import { IsIn, IsOptional } from 'class-validator';
import { AdminPageQuery } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { Roles } from '../common/roles.decorator';
import { OperationsQueueService } from './operations-queue.service';

export class OperationsQueueQuery extends AdminPageQuery {
  @IsOptional() @IsIn(['PENDING', 'PROCESSING', 'DEAD', 'SENT', 'CANCELLED']) jobStatus?: string;
}

@Controller('admin/operations/delivery-jobs')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.operations.view')
export class OperationsQueueController {
  constructor(private readonly queue: OperationsQueueService) {}
  @Get() @Header('Cache-Control', 'private, no-store')
  list(@Query() query: OperationsQueueQuery) { return this.queue.list(query); }
}
