import { Body, Controller, ForbiddenException, Get, HttpCode, HttpException, Param, Post, Req, Res } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Request, Response } from 'express';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { demoCheckoutPage } from './demo-checkout.page';
import { OnlinePaymentsService } from './online-payments.service';

@Controller('tenant/invoices')
@Roles(AuthRole.TENANT)
export class TenantOnlinePaymentsController {
  constructor(private readonly payments: OnlinePaymentsService) {}
  @Post(':id/payment-link') create(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.payments.createLink(user, id); }
  @Post(':id/demo-invoice') demoInvoice(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.payments.createDemoInvoice(user, id); }
  @Get(':id/payment-link') status(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.payments.status(user, id); }
}

@Controller('billing/invoices')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class LandlordOnlinePaymentsController {
  constructor(private readonly payments: OnlinePaymentsService) {}
  @Get(':id/payment-link') @RequirePermissions('billing.view') status(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.payments.status(user, id); }
  @Get(':id/payment-events') @RequirePermissions('billing.view') events(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.payments.events(user, id); }
  @Post(':id/payment-events/:eventId/reconcile') @RequirePermissions('billing.record_payment') reconcile(@CurrentUser() user: AuthUser, @Param('id') id: string, @Param('eventId') eventId: string) { return this.payments.reconcile(user, id, eventId); }
}

@Controller('payments/demo')
export class DemoCardPaymentController {
  constructor(private readonly payments: OnlinePaymentsService) {}

  private headers(response: Response) {
    response.set({
      'Cache-Control': 'no-store',
      'Referrer-Policy': 'no-referrer',
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
    });
  }

  @Get('checkout/:token')
  async checkout(@Param('token') token: string, @Res() response: Response) {
    this.headers(response);
    try {
      const state = await this.payments.checkout(token);
      return response.type('html').send(demoCheckoutPage({ token, ...state }));
    } catch (error) {
      if (!(error instanceof HttpException)) throw error;
      return response.status(error.getStatus()).type('html').send(demoCheckoutPage({ error: error.message }));
    }
  }

  @Post('checkout/:token/confirm')
  @HttpCode(200)
  @Throttle({ default: { limit: 12, ttl: 60000 } })
  async confirm(@Param('token') token: string, @Body() body: unknown, @Req() request: Request, @Res() response: Response) {
    this.headers(response);
    const browserForm = request.is('application/x-www-form-urlencoded');
    try {
      const origin = request.get('origin');
      let sameOrigin = !origin || origin === 'null';
      if (origin && origin !== 'null') {
        try {
          const parsed = new URL(origin);
          sameOrigin = ['http:', 'https:'].includes(parsed.protocol) && parsed.host === request.get('host') && !parsed.username && !parsed.password;
        } catch {
          sameOrigin = false;
        }
      }
      if (request.get('sec-fetch-site') === 'cross-site' || !sameOrigin) throw new ForbiddenException('Chỉ xác nhận từ trang thanh toán hợp lệ.');
      const result = await this.payments.confirmDemo(token, body);
      if (!browserForm) return response.json(result);
      const state = await this.payments.checkout(token);
      return response.type('html').send(demoCheckoutPage({ token, ...state }));
    } catch (error) {
      if (!(error instanceof HttpException)) throw error;
      if (!browserForm) return response.status(error.getStatus()).json({ message: error.message });
      const state = await this.payments.checkout(token).catch(() => ({}));
      return response.status(error.getStatus()).type('html').send(demoCheckoutPage({ token, ...state, error: error.message }));
    }
  }
}
