import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';

import { AuthModule } from '../auth/auth.module';
import { AuditModule } from '../audit/audit.module';
import { PropertiesModule } from '../properties/properties.module';
import {
  PropertyRoomsController,
  RoomsController,
} from './rooms.controller';
import { RoomsService } from './rooms.service';

@Module({
  imports: [PassportModule, AuthModule, PropertiesModule, AuditModule],
  controllers: [PropertyRoomsController, RoomsController],
  providers: [RoomsService],
})
export class RoomsModule {}
