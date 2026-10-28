import { ArgumentsHost, BadRequestException, HttpException, Logger, UnauthorizedException } from '@nestjs/common';
import { ApiErrorFilter } from './api-error.filter';

describe('ApiErrorFilter', () => {
  const json = jest.fn();
  const response = { status: jest.fn().mockReturnThis(), json, getHeader: jest.fn().mockReturnValue('request-123') };
  const request = { method: 'POST', route: { path: '/api/v1/auth/login' }, header: jest.fn() };
  const host = { switchToHttp: () => ({ getRequest: () => request, getResponse: () => response }) } as unknown as ArgumentsHost;

  beforeEach(() => { jest.clearAllMocks(); jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined); });
  afterEach(() => jest.restoreAllMocks());

  it('preserves stable application error codes', () => {
    new ApiErrorFilter().catch(new UnauthorizedException({ error: { code: 'MFA_REQUIRED', message: 'Enter MFA.' } }), host);
    expect(json).toHaveBeenCalledWith({ error: { code: 'MFA_REQUIRED', message: 'Enter MFA.' }, requestId: 'request-123' });
  });

  it('normalizes validation messages without reflecting request payloads', () => {
    new ApiErrorFilter().catch(new BadRequestException({ message: ['email must be an email'] }), host);
    expect(json).toHaveBeenCalledWith({ error: { code: 'VALIDATION_ERROR', message: 'Request validation failed.', details: ['email must be an email'] }, requestId: 'request-123' });
  });

  it.each([new Error('postgres://private:password@database'), new HttpException('SQL and private token', 503)])('redacts unknown and server errors from clients and logs', error => {
    new ApiErrorFilter().catch(error, host);
    expect(json.mock.calls[0][0].error).toEqual({ code: 'INTERNAL_SERVER_ERROR', message: 'Internal server error.' });
    expect(Logger.prototype.error).toHaveBeenCalledWith(expect.stringContaining('request-123'));
    expect(JSON.stringify(json.mock.calls) + JSON.stringify((Logger.prototype.error as jest.Mock).mock.calls)).not.toContain(error.message);
  });
});
