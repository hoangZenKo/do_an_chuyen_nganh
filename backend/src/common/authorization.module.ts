import { Global, Module } from '@nestjs/common';

import { RolesGuard } from './roles.guard';
import { AuthModule } from '../auth/auth.module';

@Global()
@Module({
  imports: [AuthModule],
  providers: [RolesGuard],
  exports: [RolesGuard],
})
export class AuthorizationModule {}
