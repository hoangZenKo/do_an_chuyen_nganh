import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from "@nestjs/common";

import { AuditService } from "../audit/audit.service";
import { AuthRole } from "../common/auth-role";
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from "../common/current-user.decorator";
import { RequirePermissions } from "../common/permissions.decorator";
import { Roles } from "../common/roles.decorator";
import { CreateTenantAccountDto } from "./dto/create-tenant-account.dto";
import { CreateTenantDto } from "./dto/create-tenant.dto";
import { ListTenantsQueryDto } from "./dto/list-tenants-query.dto";
import { UpdateTenantDto } from "./dto/update-tenant.dto";
import { UpdateTenantStatusDto } from "./dto/update-tenant-status.dto";
import { TenantsService } from "./tenants.service";

@Controller("tenants")
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class TenantsController {
  constructor(
    private readonly tenants: TenantsService,
    private readonly audit: AuditService,
  ) {}

  @Get()
  @RequirePermissions("tenant.view")
  list(@CurrentUser() user: AuthUser, @Query() query: ListTenantsQueryDto) {
    return this.tenants.list(landlordScopeId(user), query);
  }

  @Post()
  @RequirePermissions("tenant.manage")
  async create(@CurrentUser() user: AuthUser, @Body() input: CreateTenantDto) {
    const landlordId = landlordScopeId(user);
    const result = await this.tenants.create(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "tenant.create",
      resourceType: "tenant",
      resourceId: result.data.id,
      summary: `Tạo khách thuê ${result.data.fullName}`,
      metadata: { fullName: result.data.fullName },
    });
    return result;
  }

  @Get(":id")
  @RequirePermissions("tenant.view")
  getById(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.tenants.getById(landlordScopeId(user), id);
  }

  @Get(":id/overview")
  @RequirePermissions("tenant.view")
  overview(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.tenants.overview(landlordScopeId(user), id);
  }

  @Post(":id/account")
  @RequirePermissions("tenant.manage")
  async createAccount(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: CreateTenantAccountDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.tenants.createAccount(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "tenant.account_create",
      resourceType: "tenant",
      resourceId: id,
      summary: `Tạo tài khoản đăng nhập cho ${result.data.fullName}`,
      metadata: { email: input.email.trim().toLowerCase() },
    });
    return result;
  }

  @Patch(":id")
  @RequirePermissions("tenant.manage")
  async update(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: UpdateTenantDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.tenants.update(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "tenant.update",
      resourceType: "tenant",
      resourceId: id,
      summary: `Cập nhật khách thuê ${result.data.fullName}`,
      metadata: { changedFields: Object.keys(input) },
    });
    return result;
  }

  @Patch(":id/status")
  @RequirePermissions("tenant.manage")
  async updateStatus(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: UpdateTenantStatusDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.tenants.updateStatus(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "tenant.status_update",
      resourceType: "tenant",
      resourceId: id,
      summary: `${result.data.isActive ? "Mở lại" : "Khóa"} khách thuê ${result.data.fullName}`,
      metadata: { isActive: result.data.isActive },
    });
    return result;
  }

  @Delete(":id")
  @RequirePermissions("tenant.manage")
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.tenants.remove(landlordId, id);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "tenant.delete",
      resourceType: "tenant",
      resourceId: id,
      summary: "Xóa khách thuê",
    });
  }
}
