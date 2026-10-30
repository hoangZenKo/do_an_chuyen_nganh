import { BadRequestException, CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { UploadsService } from './uploads.service';
import { AuthUser } from '../common/current-user.decorator';

@Injectable()
export class UploadReferencesInterceptor implements NestInterceptor {
  constructor(private readonly uploads: UploadsService) {}
  async intercept(context: ExecutionContext, next: CallHandler) {
    const request = context.switchToHttp().getRequest<{ method: string; body?: unknown; user?: AuthUser }>();
    if (request.user && ['POST', 'PATCH', 'PUT'].includes(request.method)) {
      const filenames = new Set<string>();
      const visit = (value: unknown) => {
        if (typeof value === 'string') {
          const match = value.match(/\/uploads\/([a-zA-Z0-9_-]+\.[a-zA-Z0-9]+)(?:\?.*)?$/);
          if (match) filenames.add(match[1]);
        } else if (Array.isArray(value)) value.forEach(visit);
        else if (value && typeof value === 'object') Object.values(value).forEach(visit);
      };
      visit(request.body);
      for (const filename of filenames) {
        if (!await this.uploads.canRead(request.user, filename)) {
          throw new BadRequestException('File không thuộc quyền truy cập của bạn. Hãy tải lại file từ tài khoản của bạn.');
        }
      }
    }
    return next.handle();
  }
}
