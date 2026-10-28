import { Body, Controller, Header, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { IsIn, IsObject, IsString, MaxLength, MinLength } from 'class-validator';
import { AdminReasonDto } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminStepUpService } from './admin-step-up.service';

class AdminStepUpDto extends AdminReasonDto {
  @IsIn(['POST', 'PATCH']) method!: string;
  @IsString() @MinLength(1) @MaxLength(300) path!: string;
  @IsObject() payload!: Record<string, unknown>;
  @IsString() @MinLength(6) @MaxLength(64) code!: string;
}

@Controller('admin/me/security/step-up')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.dashboard.view')
export class AdminStepUpController {
  constructor(private readonly stepUp: AdminStepUpService) {}
  @Post()
  @Header('Cache-Control', 'private, no-store')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  issue(@CurrentUser() actor: AuthUser, @Body() input: AdminStepUpDto) { return this.stepUp.issue(actor, input); }
}
