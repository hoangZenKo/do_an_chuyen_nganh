import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { UploadReferencesInterceptor } from './upload-references.interceptor';

import { UploadsController } from './uploads.controller';
import { UploadsService } from './uploads.service';

@Module({
  controllers: [UploadsController],
  providers: [UploadsService, { provide: APP_INTERCEPTOR, useClass: UploadReferencesInterceptor }],
  exports: [UploadsService],
})
export class UploadsModule {}
