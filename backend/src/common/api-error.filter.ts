import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

interface ErrorBody {
  code: string;
  message: string;
  details?: unknown;
}

@Catch()
export class ApiErrorFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiErrorFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<Request>();
    const status = exception instanceof HttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;
    const error = this.normalize(exception, status);
    const requestId = this.requestId(response, request);
    if (status >= 500) {
      this.logger.error(JSON.stringify({ event: 'request_failed', requestId, method: request.method,
        route: request.route?.path ?? 'unmatched', status, code: error.code }));
    }

    response.status(status).json({
      error: {
        code: error.code,
        message: error.message,
        ...(error.details === undefined ? {} : { details: error.details }),
      },
      requestId,
    });
  }

  private normalize(exception: unknown, status: number): ErrorBody {
    if (!(exception instanceof HttpException) || status >= 500) {
      return { code: 'INTERNAL_SERVER_ERROR', message: 'Internal server error.' };
    }

    const payload = exception.getResponse();
    if (typeof payload === 'string') {
      return { code: this.defaultCode(status), message: payload };
    }
    if (!payload || typeof payload !== 'object') {
      return { code: this.defaultCode(status), message: exception.message };
    }

    const body = payload as Record<string, unknown>;
    const nested = body.error && typeof body.error === 'object'
      ? body.error as Record<string, unknown>
      : null;
    const rawMessage = nested?.message ?? body.message ?? exception.message;
    const message = Array.isArray(rawMessage)
      ? 'Request validation failed.'
      : String(rawMessage);
    const details = Array.isArray(rawMessage) ? rawMessage : nested?.details;

    return {
      code: typeof nested?.code === 'string'
        ? nested.code
        : Array.isArray(rawMessage)
          ? 'VALIDATION_ERROR'
          : this.defaultCode(status),
      message,
      ...(details === undefined ? {} : { details }),
    };
  }

  private defaultCode(status: number) {
    switch (status) {
      case HttpStatus.BAD_REQUEST: return 'BAD_REQUEST';
      case HttpStatus.UNAUTHORIZED: return 'UNAUTHORIZED';
      case HttpStatus.FORBIDDEN: return 'FORBIDDEN';
      case HttpStatus.NOT_FOUND: return 'NOT_FOUND';
      case HttpStatus.CONFLICT: return 'CONFLICT';
      case HttpStatus.TOO_MANY_REQUESTS: return 'RATE_LIMITED';
      default: return status >= 500 ? 'INTERNAL_SERVER_ERROR' : 'HTTP_ERROR';
    }
  }

  private requestId(response: Response, request: Request) {
    const value = response.getHeader('X-Request-ID') ?? request.header('x-request-id');
    return Array.isArray(value) ? value[0] : String(value ?? 'unknown');
  }
}
