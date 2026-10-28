## E001 AuthController.register
backend/src/auth/auth.controller.ts:18
```
18:   @Post('register')
19:   @Throttle({ default: { limit: 5, ttl: 60_000 } })
20:   @HttpCode(HttpStatus.CREATED)
21:   register(@Body() input: RegisterDto) {
22:     return this.auth.register(input);
23:   }
24: 
25:   @Post('register-seeker')
26:   @Throttle({ default: { limit: 5, ttl: 60_000 } })
```

## E002 AuthController.registerSeeker
backend/src/auth/auth.controller.ts:25
```
25:   @Post('register-seeker')
26:   @Throttle({ default: { limit: 5, ttl: 60_000 } })
27:   @HttpCode(HttpStatus.CREATED)
28:   registerSeeker(@Body() input: RegisterDto) {
29:     return this.auth.registerSeeker(input);
30:   }
31: 
32:   @Post('login')
33:   @Throttle({ default: { limit: 10, ttl: 60_000 } })
```

## E003 AuthController.login
backend/src/auth/auth.controller.ts:32
```
32:   @Post('login')
33:   @Throttle({ default: { limit: 10, ttl: 60_000 } })
34:   login(@Body() input: LoginDto) {
35:     return this.auth.login(input);
36:   }
37: 
38:   @Post('refresh')
39:   @Throttle({ default: { limit: 20, ttl: 60_000 } })
40:   refresh(@Body() input: RefreshDto) {
```

## E004 AuthController.logout
backend/src/auth/auth.controller.ts:44
```
44:   @Post('logout')
45:   @Throttle({ default: { limit: 20, ttl: 60_000 } })
46:   @HttpCode(HttpStatus.NO_CONTENT)
47:   async logout(@Body() input: RefreshDto): Promise<void> {
48:     await this.auth.logout(input.refreshToken);
49:   }
50: 
51:   @Get('/me')
52:   @ApiBearerAuth()
```

## E005 AuthController.sessions
backend/src/auth/auth.controller.ts:59
```
59:   @Get('sessions')
60:   @ApiBearerAuth()
61:   @UseGuards(AuthGuard('jwt'))
62:   sessions(@CurrentUser() user: AuthUser) {
63:     return this.auth.sessions(user.userId, user.sessionId);
64:   }
65: 
66:   @Post('sessions/:id/revoke')
67:   @ApiBearerAuth()
```

## E006 AuthController.changePassword
backend/src/auth/auth.controller.ts:80
```
80:   @Post('change-password')
81:   @ApiBearerAuth()
82:   @UseGuards(AuthGuard('jwt'))
83:   @HttpCode(HttpStatus.NO_CONTENT)
84:   async changePassword(
85:     @CurrentUser() user: AuthUser,
86:     @Body() input: ChangePasswordDto,
87:   ): Promise<void> {
88:     await this.auth.changePassword(user.userId, input);
```

## E007 AuthService.registerAccount
backend/src/auth/auth.service.ts:45
```
45:   private async registerAccount(input: RegisterDto, role: UserRole) {
46:     const email = this.normalizeEmail(input.email);
47:     const fullName = input.fullName.trim();
48:     const phone = input.phone.trim();
49: 
50:     try {
51:       const user = await this.prisma.user.create({
52:         data: {
53:           fullName,
```

## E008 AuthService.registerSeeker
backend/src/auth/auth.service.ts:41
```
41:   async registerSeeker(input: RegisterDto) {
42:     return this.registerAccount(input, UserRole.TENANT);
43:   }
44: 
45:   private async registerAccount(input: RegisterDto, role: UserRole) {
46:     const email = this.normalizeEmail(input.email);
47:     const fullName = input.fullName.trim();
48:     const phone = input.phone.trim();
49: 
```

## E009 AuthService.login
backend/src/auth/auth.service.ts:71
```
71:   async login(input: LoginDto) {
72:     const user = await this.prisma.user.findUnique({
73:       where: { email: this.normalizeEmail(input.email) },
74:     });
75:     if (!user || !user.isActive || !(await argon2.verify(user.passwordHash, input.password))) {
76:       throw invalidCredentials();
77:     }
78:     let mfaVerified = false;
79:     if (user.role === UserRole.ADMIN) {
```

## E010 AuthService.logout
backend/src/auth/auth.service.ts:137
```
137:   async logout(rawToken: string): Promise<void> {
138:     const tokenHash = this.hashRefreshToken(rawToken);
139:     await this.prisma.$transaction(async tx => {
140:       const token = await tx.refreshToken.findUnique({ where: { tokenHash } });
141:       if (!token) return;
142:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${token.userId} FOR UPDATE`;
143:       const now = new Date();
144:       if (token.sessionId) {
145:         await tx.authSession.updateMany({ where: { id: token.sessionId, userId: token.userId, revokedAt: null }, data: { revokedAt: now } });
```

## E011 AuthService.sessions
backend/src/auth/auth.service.ts:212
```
212:   async sessions(userId: string, currentSessionId?: string) {
213:     const now = new Date();
214:     const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { sessionVersion: true } });
215:     const rows = await this.prisma.authSession.findMany({
216:       where: { userId, userVersion: user.sessionVersion, revokedAt: null, expiresAt: { gt: now } },
217:       select: { id: true, device: true, ip: true, createdAt: true, lastSeenAt: true, expiresAt: true },
218:       orderBy: { lastSeenAt: 'desc' }, take: 100,
219:     });
220:     return { data: rows.map(row => ({
```

## E012 AuthService.revokeSession
backend/src/auth/auth.service.ts:232
```
232:   async revokeSession(userId: string, sessionId: string) {
233:     await this.prisma.$transaction(async tx => {
234:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
235:       const now = new Date();
236:       const result = await tx.authSession.updateMany({ where: { id: sessionId, userId, revokedAt: null }, data: { revokedAt: now } });
237:       if (result.count !== 1) throw new NotFoundException({ error: { code: 'SESSION_NOT_FOUND', message: 'Session not found.' } });
238:       await tx.refreshToken.updateMany({ where: { sessionId, userId, revokedAt: null }, data: { revokedAt: now } });
239:       await this.sessionAudit(tx, userId, 'auth.session_revoked', sessionId);
240:     });
```

## E013 AuthService.revokeOtherSessions
backend/src/auth/auth.service.ts:244
```
244:   async revokeOtherSessions(userId: string, currentSessionId?: string) {
245:     if (!currentSessionId) throw new UnauthorizedException('Sign in again to manage sessions.');
246:     return this.prisma.$transaction(async tx => {
247:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
248:       const now = new Date();
249:       const result = await tx.authSession.updateMany({
250:         where: { userId, revokedAt: null, id: { not: currentSessionId } }, data: { revokedAt: now },
251:       });
252:       await tx.refreshToken.updateMany({
```

## E014 AuthService.changePassword
backend/src/auth/auth.service.ts:159
```
159:   async changePassword(userId: string, input: ChangePasswordDto): Promise<void> {
160:     const user = await this.prisma.user.findUnique({ where: { id: userId } });
161:     if (
162:       !user ||
163:       !user.isActive ||
164:       !(await argon2.verify(user.passwordHash, input.currentPassword))
165:     ) {
166:       throw invalidCredentials();
167:     }
```

## E015 AuthService.issueSession
backend/src/auth/auth.service.ts:179
```
179:   async issueSession(user: User, existing?: { raw: string; record: { sessionId: string | null; expiresAt: Date } }, mfaVerified = false) {
180:     const refresh = existing ?? await this.prisma.$transaction(async (tx) => {
181:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${user.id} FOR UPDATE`;
182:       const current = await tx.user.findUniqueOrThrow({ where: { id: user.id } });
183:       if (!current.isActive || current.sessionVersion !== user.sessionVersion) throw invalidCredentials();
184:       return this.createRefreshToken(user.id, tx, mfaVerified, undefined, user.sessionVersion);
185:     });
186:     const serializedUser = await this.serializeUser(user);
187:     const accessToken = await this.jwt.signAsync({
```

## E016 AuthService.refresh
backend/src/auth/auth.service.ts:91
```
91:   async refresh(rawToken: string) {
92:     const tokenHash = this.hashRefreshToken(rawToken);
93:     const now = new Date();
94: 
95:     const result = await this.prisma.$transaction(async (tx) => {
96:       const candidate = await tx.refreshToken.findUnique({ where: { tokenHash }, select: { userId: true } });
97:       if (!candidate) throw invalidRefreshToken();
98:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${candidate.userId} FOR UPDATE`;
99:       const token = await tx.refreshToken.findUnique({
```

## E017 AccountAccessService.forgot
backend/src/auth/account-access.service.ts:47
```
47:   async forgot(email: string) {
48:     const user = await this.prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
49:     if (user?.isActive && this.ready()) {
50:       try { await this.send(user.id, 'PASSWORD_RESET'); } catch {}
51:     }
52:     return { data: { message: 'Nếu tài khoản hợp lệ và kênh gửi khả dụng, bạn sẽ nhận được hướng dẫn.' } };
53:   }
54:   async redeem(raw: string, password: string) {
55:     const passwordHash = await argon2.hash(password);
```

## E018 AccountAccessService.redeem
backend/src/auth/account-access.service.ts:54
```
54:   async redeem(raw: string, password: string) {
55:     const passwordHash = await argon2.hash(password);
56:     await this.prisma.$transaction(async tx => {
57:       const token = await tx.accountAccessToken.findUnique({ where: { tokenHash: tokenHash(raw) } });
58:       if (!token) throw new UnauthorizedException('Link không hợp lệ hoặc đã hết hạn.');
59:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${token.userId} FOR UPDATE`;
60:       const current = await tx.accountAccessToken.findUniqueOrThrow({ where: { id: token.id } });
61:       const user = await tx.user.findUniqueOrThrow({ where: { id: token.userId } });
62:       if (current.consumedAt || current.expiresAt <= new Date() || !user.isActive) throw new UnauthorizedException('Link không hợp lệ hoặc đã hết hạn.');
```

## E019 AccountAccessService.enqueue
backend/src/auth/account-access.service.ts:23
```
23:   async enqueue(tx: Prisma.TransactionClient, userId: string, purpose: string) {
24:     if (!this.ready()) throw new ServiceUnavailableException('Kênh gửi lời mời/khôi phục chưa được cấu hình.');
25:     const raw = randomBytes(32).toString('base64url');
26:     await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
27:     const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
28:     if (!user.isActive) throw new UnauthorizedException();
29:     if (user.role !== 'ADMIN') {
30:       const since = new Date(Date.now() - 3_600_000);
31:       const latest = await tx.accountAccessToken.findFirst({ where: { userId, purpose }, orderBy: { createdAt: 'desc' } });
```

## E020 AccountAccessController.forgot
backend/src/auth/account-access.controller.ts:19
```
19:   @Post('forgot') forgot(@Body() input: ForgotDto) { return this.access.forgot(input.email); }
20:   @Post('redeem') redeem(@Body() input: RedeemDto) { return this.access.redeem(input.token, input.password); }
21: }
```

## E021 TenantInvitesController.accept
backend/src/tenants/tenant-invites.controller.ts:45
```
45:   @Post('tenant-invites/accept')
46:   accept(@Body() input: AcceptTenantInviteDto) {
47:     return this.invites.accept(input);
48:   }
49: }
```

## E022 TenantInvitesService.accept
backend/src/tenants/tenant-invites.service.ts:97
```
97:   async accept(input: AcceptTenantInviteDto) {
98:     const now = new Date();
99:     const tokenHash = this.hashInvite(input.inviteCode);
100:     try {
101:       const user = await this.prisma.$transaction(async (tx) => {
102:         let invite = await tx.tenantInvite.findUnique({
103:           where: { tokenHash },
104:           include: { tenant: true },
105:         });
```

## E023 TenantInvitesService.create
backend/src/tenants/tenant-invites.service.ts:54
```
54:   async create(landlordId: string, tenantId: string, input: CreateTenantInviteDto) {
55:     return this.prisma.$transaction(async tx => {
56:     await tx.$queryRaw`SELECT "id" FROM "Tenant" WHERE "id" = ${tenantId} FOR UPDATE`;
57:     const tenant = await tx.tenant.findFirst({
58:       where: { id: tenantId, landlordId, isActive: true, ...tenantScope() },
59:       select: { id: true, userId: true },
60:     });
61:     if (!tenant) throw tenantNotFound();
62:     if (tenant.userId) throw tenantAccountExists();
```

## E024 StaffController.accept
backend/src/staff/staff.controller.ts:96
```
96:   @Post('invites/accept')
97:   accept(@Body() input: AcceptStaffInviteDto) {
98:     return this.staff.accept(input);
99:   }
100: }
```

## E025 StaffService.accept
backend/src/staff/staff.service.ts:104
```
104:   async accept(input: AcceptStaffInviteDto) {
105:     const now = new Date();
106:     const tokenHash = this.hashInvite(input.inviteCode);
107:     try {
108:       const user = await this.prisma.$transaction(async (tx) => {
109:         let invite = await tx.staffInvite.findUnique({ where: { tokenHash } });
110:         if (invite) {
111:           await tx.$queryRaw`SELECT "id" FROM "StaffInvite" WHERE "id" = ${invite.id} FOR UPDATE`;
112:           invite = await tx.staffInvite.findUnique({ where: { tokenHash } });
```

## E026 AdminMfaService.verify
backend/src/auth/admin-mfa.service.ts:66
```
66:   async verify(userId: string, code: string, activate = false) {
67:     const requestId = requestContext.getStore()?.requestId;
68:     return this.prisma.$transaction(async tx => {
69:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
70:       const profile = await tx.adminProfile.findUnique({ where: { userId }, include: { user: true } });
71:       if (!profile?.user.isActive || !profile.mfaSecret || (activate && profile.mfaEnabled) || (!activate && !profile.mfaEnabled)) throw new UnauthorizedException('Invalid MFA state.');
72:       const counter = BigInt(Math.floor(Date.now() / 30000));
73:       let accepted: bigint | null = null;
74:       if (/^\d{6}$/.test(code)) for (const candidate of [counter - 1n, counter, counter + 1n]) {
```

## E027 RegisterDto
backend/src/auth/dto/register.dto.ts:4
```
4: export class RegisterDto {
5:   @ApiProperty({ maxLength: 120 })
6:   @IsString()
7:   @IsNotEmpty()
8:   @MaxLength(120)
9:   fullName!: string;
10: 
11:   @ApiProperty({ format: 'email' }) @IsEmail()
12:   email!: string;
```

## E028 LoginDto
backend/src/auth/dto/login.dto.ts:4
```
4: export class LoginDto {
5:   @ApiPropertyOptional({ minLength: 6, maxLength: 64 })
6:   @IsOptional() @IsString() @MinLength(6) @MaxLength(64)
7:   mfaCode?: string;
8:   @ApiProperty({ format: 'email' }) @IsEmail()
9:   email!: string;
10: 
11:   @ApiProperty({ format: 'password', maxLength: 128 }) @IsString()
12:   @MinLength(1)
```

## E029 ChangePasswordDto
backend/src/auth/dto/change-password.dto.ts:4
```
4: export class ChangePasswordDto {
5:   @ApiProperty({ format: 'password', maxLength: 128 })
6:   @IsString()
7:   @MinLength(1)
8:   @MaxLength(128)
9:   currentPassword!: string;
10: 
11:   @ApiProperty({ format: 'password', minLength: 12, maxLength: 128 })
12:   @IsString()
```

## E030 RefreshDto
backend/src/auth/dto/refresh.dto.ts:4
```
4: export class RefreshDto {
5:   @ApiProperty({ minLength: 32 }) @IsString()
6:   @MinLength(32)
7:   refreshToken!: string;
8: }
```

## E031 AcceptTenantInviteDto
backend/src/tenants/dto/accept-tenant-invite.dto.ts:3
```
3: export class AcceptTenantInviteDto {
4:   @IsString()
5:   @MinLength(16)
6:   @MaxLength(256)
7:   inviteCode!: string;
8: 
9:   @IsString()
10:   @MinLength(12)
11:   @MaxLength(128)
```

## E032 AcceptStaffInviteDto
backend/src/staff/dto/accept-staff-invite.dto.ts:3
```
3: export class AcceptStaffInviteDto {
4:   @IsString()
5:   @MinLength(16)
6:   @MaxLength(256)
7:   inviteCode!: string;
8: 
9:   @IsString()
10:   @MinLength(12)
11:   @MaxLength(128)
```

## E033 JwtStrategy.validate
backend/src/auth/jwt.strategy.ts:25
```
25:   async validate(payload: { sub: string; typ?: string; ver?: number; mfa?: boolean; sid?: string }): Promise<AuthUser> {
26:     if (payload.typ !== 'access') throw new UnauthorizedException();
27:     const user:
28:       | (Pick<User, 'id' | 'email' | 'role' | 'isActive' | 'sessionVersion'> & {
29:           staffProfile?: {
30:             landlordId: string;
31:             permissions: string[];
32:             isActive: boolean;
33:             propertyScopes: { propertyId: string }[];
```

## E034 RolesGuard.canActivate
backend/src/common/roles.guard.ts:23
```
23:   canActivate(context: ExecutionContext): boolean | Promise<boolean> {
24:     const allowedRoles = this.reflector.getAllAndOverride<AuthRole[]>(ROLES_KEY, [
25:       context.getHandler(),
26:       context.getClass(),
27:     ]);
28:     if (!allowedRoles || allowedRoles.length === 0) return true;
29: 
30:     const request = context.switchToHttp().getRequest<{
31:       user?: AuthUser; method?: string; originalUrl?: string; body?: unknown; headers?: Record<string, string>;
```

## E035 PropertyScopeInterceptor
backend/src/common/property-scope.ts:44
```
44: export class PropertyScopeInterceptor implements NestInterceptor {
45:   intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
46:     const request = context.switchToHttp().getRequest<{ user?: AuthUser; body?: Record<string, unknown>; query?: Record<string, unknown> }>();
47:     const actor = request.user;
48:     if (actor?.role !== AuthRole.STAFF) return next.handle();
49:     const controller = context.getClass().name;
50:     const handler = context.getHandler().name;
51:     const denied = () => { throw new ForbiddenException({ error: { code: 'STAFF_PROPERTY_SCOPE_REQUIRED', message: 'This action requires landlord access or a property-scoped workflow.' } }); };
52:     if (controller === 'AuthController') return next.handle();
```

## E036 Admin access predicates
backend/src/common/admin-access.ts:1
```
1: export function adminAccess(permissions: readonly string[], required: readonly string[], mfaRequired: boolean, mfaVerified: boolean) {
2:   const missing = required.filter(permission => !permissions.includes(permission));
3:   return { allowed: required.length > 0 && missing.length === 0 && (!mfaRequired || mfaVerified),
4:     missing, mfaNeeded: mfaRequired && !mfaVerified };
5: }
```

## E037 User
backend/prisma/schema.prisma:177
```
177: model User {
178:   landlordVerification LandlordVerification? @relation("LandlordVerificationOwner")
179:   platformSubscription LandlordSubscription? @relation("LandlordSubscriptionOwner")
180:   billingCommands        BillingCommand[]
181:   billingReceipts        BillingReceipt[]
182:   billingPolicies        BillingReminderPolicy[]
183:   billingEvents          BillingOutboxEvent[]
184:   lifecycleRequests      TenantLifecycleRequest[]
185:   staffPropertyScopes    StaffPropertyScope[]
```

## E038 Tenant
backend/prisma/schema.prisma:816
```
816: model Tenant {
817:   billingReceipts        BillingReceipt[]
818:   billingNotifications   BillingNotification[]
819:   id                     String                        @id @default(uuid())
820:   landlordId             String
821:   userId                 String?                       @unique
822:   fullName               String
823:   phone                  String?
824:   idNumber               String?
```

## E039 AuthSession; RefreshToken trong cùng schema
backend/prisma/schema.prisma:1738
```
1738: model AuthSession {
1739:   stepUpGrants AdminStepUpGrant[]
1740:   id           String             @id @default(uuid())
1741:   userId       String
1742:   user         User               @relation(fields: [userId], references: [id], onDelete: Cascade)
1743:   userVersion  Int
1744:   device       String             @default("Unknown device")
1745:   ip           String?
1746:   lastSeenAt   DateTime           @default(now())
```

## E040 AccountAccessToken
backend/prisma/schema.prisma:1771
```
1771: model AccountAccessToken {
1772:   id         String       @id @default(uuid())
1773:   userId     String
1774:   purpose    String
1775:   tokenHash  String       @unique
1776:   expiresAt  DateTime
1777:   consumedAt DateTime?
1778:   user       User         @relation(fields: [userId], references: [id], onDelete: Cascade)
1779:   createdAt  DateTime     @default(now())
```

## E041 TenantInvite
backend/prisma/schema.prisma:910
```
910: model TenantInvite {
911:   id         String    @id @default(uuid())
912:   landlordId String
913:   tenantId   String
914:   email      String
915:   tokenHash  String    @unique
916:   expiresAt  DateTime
917:   acceptedAt DateTime?
918:   landlord   User      @relation(fields: [landlordId], references: [id], onDelete: Cascade)
```

## E042 StaffProfile; StaffInvite; StaffPropertyScope
backend/prisma/schema.prisma:291
```
291: model StaffProfile {
292:   maintenanceTickets MaintenanceTicket[]
293:   propertyScopes     StaffPropertyScope[]
294:   id                 String               @id @default(uuid())
295:   userId             String               @unique
296:   landlordId         String
297:   fullName           String
298:   phone              String?
299:   preset             String?
```

## E043 RegisterScreen._submit
lib/features/auth/register_screen.dart:79
```
79:   Future<void> _submit() async {
80:     if (_loading) return;
81:     FocusScope.of(context).unfocus();
82:     if (!_formKey.currentState!.validate()) return;
83:     if (!_agreeToTerms) {
84:       ScaffoldMessenger.of(context).showSnackBar(
85:         const SnackBar(
86:           content: Text('Please agree to the Terms & Conditions.'),
87:           backgroundColor: kAuthOrange,
```

## E044 LoginScreen._submit
lib/features/auth/login_screen.dart:37
```
37:   Future<void> _submit() async {
38:     final next = GoRouterState.of(context).uri.queryParameters['next'];
39:     FocusScope.of(context).unfocus();
40:     if (!_formKey.currentState!.validate()) return;
41:     setState(() {
42:       _loading = true;
43:       _error = null;
44:     });
45:     try {
```

## E045 SessionController.logout
lib/features/auth/auth_providers.dart:116
```
116:   Future<void> logout() async {
117:     try {
118:       await ref.read(authRepositoryProvider).logout();
119:     } finally {
120:       state = const SessionState.unauthenticated();
121:     }
122:   }
123: 
124:   Future<AuthSession> acceptTenantInvite({
```

## E046 AdminSessionsScreen
lib/features/admin/admin_sessions_screen.dart:10
```
10: class AdminSessionsScreen extends ConsumerStatefulWidget {
11:   const AdminSessionsScreen({super.key});
12: 
13:   @override
14:   ConsumerState<AdminSessionsScreen> createState() =>
15:       _AdminSessionsScreenState();
16: }
17: 
18: class _AdminSessionsScreenState extends WorkflowState<AdminSessionsScreen> {
```

## E047 TenantChangePasswordScreen
lib/features/tenant_portal/tenant_change_password_screen.dart:8
```
8: class TenantChangePasswordScreen extends ConsumerStatefulWidget {
9:   const TenantChangePasswordScreen({super.key});
10: 
11:   @override
12:   ConsumerState<TenantChangePasswordScreen> createState() =>
13:       _TenantChangePasswordScreenState();
14: }
15: 
16: class _TenantChangePasswordScreenState
```

## E048 PasswordRecoveryDialog
lib/features/auth/password_recovery_dialog.dart:12
```
12: class PasswordRecoveryDialog extends ConsumerStatefulWidget {
13:   const PasswordRecoveryDialog({super.key, this.initialEmail = ''});
14:   final String initialEmail;
15:   @override
16:   ConsumerState<PasswordRecoveryDialog> createState() => _RecoveryState();
17: }
18: 
19: class _RecoveryState extends ConsumerState<PasswordRecoveryDialog> {
20:   final _form = GlobalKey<FormState>();
```

## E049 AccountAccessScreen._submit
lib/features/auth/account_access_screen.dart:32
```
32:   Future<void> _submit() async {
33:     if (_busy || !_form.currentState!.validate()) return;
34:     setState(() {
35:       _busy = true;
36:       _error = null;
37:     });
38:     try {
39:       await AuthApi(ref.read(dioProvider))
40:           .redeemAccountAccess(_token.text.trim(), _password.text);
```

## E050 TenantInviteScreen._submit
lib/features/auth/tenant_invite_screen.dart:39
```
39:   Future<void> _submit() async {
40:     if (!_formKey.currentState!.validate()) return;
41:     setState(() {
42:       _loading = true;
43:       _error = null;
44:     });
45:     try {
46:       final session =
47:           await ref.read(sessionControllerProvider.notifier).acceptTenantInvite(
```

## E051 StaffInviteScreen._submit
lib/features/auth/staff_invite_screen.dart:39
```
39:   Future<void> _submit() async {
40:     if (!_formKey.currentState!.validate()) return;
41:     setState(() {
42:       _loading = true;
43:       _error = null;
44:     });
45:     try {
46:       final session =
47:           await ref.read(sessionControllerProvider.notifier).acceptStaffInvite(
```

## E052 AuthRepository login/register/logout/restore
lib/data/auth/auth_repository.dart:6
```
6: class AuthRepository {
7:   const AuthRepository({required this.api, required this.storage});
8: 
9:   final AuthApi api;
10:   final SecureSessionStorage storage;
11: 
12:   Future<AuthSession> login({
13:     required String email,
14:     required String password,
```

## E053 SessionController
lib/features/auth/auth_providers.dart:52
```
52: class SessionController extends Notifier<SessionState> {
53:   @override
54:   SessionState build() => const SessionState.checking();
55: 
56:   Future<void> restore() async {
57:     state = const SessionState.checking();
58:     try {
59:       final session = await ref.read(authRepositoryProvider).restore();
60:       state = session == null
```

## E054 homeRouteForSession
lib/features/auth/auth_navigation.dart:264
```
264: String homeRouteForSession(AuthSession session) {
265:   if (session.user.role == 'admin') {
266:     return session.user.adminMfaRequired && !session.user.adminMfaVerified
267:         ? adminSecurityRoute
268:         : adminRoute;
269:   }
270:   if (session.user.role == 'tenant') return exploreRoute;
271:   if (session.user.role == 'staff') {
272:     final permissions = session.user.permissions.toSet();
```

## E055 TokenRefreshCoordinator
lib/data/auth/token_refresh_coordinator.dart:8
```
8: class TokenRefreshCoordinator {
9:   TokenRefreshCoordinator({
10:     required this.storage,
11:     required this.refreshClient,
12:     this.onSessionInvalid,
13:   });
14: 
15:   final SecureSessionStorage storage;
16:   final Dio refreshClient;
```

## E056 API client retry 401
lib/core/network/api_client.dart:52
```
52:         final alreadyRetried = error.requestOptions.extra['authRetry'] == true;
53:         final isProtected = !publicAuthPaths.contains(requestPath);
54: 
55:         if (error.response?.statusCode != 401 ||
56:             !isProtected ||
57:             alreadyRetried) {
58:           handler.next(error);
59:           return;
60:         }
```

## E057 Global validation and API prefix
backend/src/app.bootstrap.ts:1
```
1: import { ValidationPipe } from '@nestjs/common';
2: import { INestApplication } from '@nestjs/common';
3: import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
4: import { Request, Response } from 'express';
5: import helmet from 'helmet';
6: import { randomUUID } from 'node:crypto';
7: import { UploadsService } from './uploads/uploads.service';
8: import { requestContext } from './common/request-context';
9: import { RuntimeMetricsService } from './health/runtime-metrics.service';
```

## E058 Module registrations and global interceptors
backend/src/app.module.ts:37
```
37: @Module({
38:   imports: [
39:     ConfigModule.forRoot({ isGlobal: true }),
40:     ChatbotModule,
41:     ListingsModule,
42:     HousingModule,
43:     ReviewsModule,
44:     OnlinePaymentsModule,
45:     ThrottlerModule.forRoot([{ ttl: 60_000, limit: 60 }]),
```

## E059 ApiErrorFilter
backend/src/common/api-error.filter.ts:18
```
18: export class ApiErrorFilter implements ExceptionFilter {
19:   private readonly logger = new Logger(ApiErrorFilter.name);
20: 
21:   catch(exception: unknown, host: ArgumentsHost) {
22:     const http = host.switchToHttp();
23:     const response = http.getResponse<Response>();
24:     const request = http.getRequest<Request>();
25:     const status = exception instanceof HttpException
26:       ? exception.getStatus()
```

## E060 Flutter routing
lib/app/app.dart:80
```
80: final appRouterProvider = Provider<GoRouter>((ref) {
81:   final refresh = ValueNotifier<int>(0);
82:   late final GoRouter router;
83: 
84:   ref.listen<SessionState>(sessionControllerProvider, (_, __) {
85:     refresh.value++;
86:   });
87: 
88:   router = GoRouter(
```

## E061 Turnover stages and beginTurnover
backend/src/operations/turnover.workflow.ts:4
```
4: export const turnoverStages = [TurnoverStage.RETURNED, TurnoverStage.INSPECTION, TurnoverStage.REPAIR, TurnoverStage.CLEANING, TurnoverStage.READY];
5: export const turnoverTitles = ['Xác nhận trả phòng, nhận lại chìa khóa', 'Kiểm tra tài sản, chốt điện nước và tiền cọc', 'Xử lý hư hỏng hoặc xác nhận không cần sửa', 'Vệ sinh phòng và kiểm tra lần cuối', 'Sẵn sàng cho thuê'];
6: 
7: export async function beginTurnover(tx: Prisma.TransactionClient, landlordId: string, roomId: string, leaseId?: string, note?: string) {
8:   await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${roomId} FOR UPDATE`;
9:   const active = await tx.roomTurnover.findFirst({ where: { roomId, status: 'ACTIVE' } });
10:   if (active) throw new ConflictException('Phòng đang có quy trình bàn giao chưa hoàn tất.');
11:   const room = await tx.room.findUniqueOrThrow({ where: { id: roomId } });
12:   const turnover = await tx.roomTurnover.create({ data: {
```

## E062 DemoCardGateway.assertEnabled; validateCard
backend/src/billing/demo-card.gateway.ts:7
```
7: export class DemoCardGateway {
8:   get enabled() {
9:     return process.env.NODE_ENV !== 'production' && process.env.DEMO_PAYMENTS_ENABLED === 'true';
10:   }
11: 
12:   assertEnabled() {
13:     if (!this.enabled) throw new ServiceUnavailableException('Thanh toán trực tuyến chưa khả dụng. Vui lòng liên hệ người quản lý.');
14:     this.secret();
15:   }
```

## E063 ReportsScreen CSV clipboard
lib/features/reports/reports_screen.dart:96
```
96:     await Clipboard.setData(ClipboardData(text: export.content));
97:     if (!context.mounted) return;
98:     ScaffoldMessenger.of(context).showSnackBar(
99:       SnackBar(content: Text('Đã copy CSV: ${export.filename}')),
100:     );
101:   }
102: }
103: 
104: class ReminderPolicyCard extends ConsumerWidget {
```

## E064 Inventory subscription entitlements
backend/src/common/subscription-entitlements.ts:4
```
4: export async function assertInventoryGrowth(tx: Prisma.TransactionClient, landlordId: string,
5:   kind: 'property' | 'room', amount = 1) {
6:   await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${landlordId} FOR UPDATE`;
7:   const subscription = await tx.landlordSubscription.findUnique({ where: { landlordId }, select: { planSnapshot: true, endsAt: true } });
8:   if (!subscription) return;
9:   if (subscription.endsAt && subscription.endsAt <= new Date()) {
10:     throw new ConflictException({ error: { code: 'SUBSCRIPTION_EXPIRED', message: 'Gói đã hết hạn. Gia hạn trước khi tăng số khu trọ/phòng; dữ liệu hiện có được giữ nguyên.' } });
11:   }
12:   const terms = subscription.planSnapshot as Record<string, unknown>;
```

## E065 Chatbot default disabled
backend/src/chatbot/chatbot.config.ts:19
```
19:   const enabledValue = env.CHATBOT_ENABLED ?? 'false';
20:   if (!['true', 'false'].includes(enabledValue)) invalid();
21:   const baseUrl = env.OLLAMA_BASE_URL ?? 'http://127.0.0.1:11434';
22:   let url: URL;
23:   try { url = new URL(baseUrl); } catch { return invalid(); }
24:   const isLoopback = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) ||
25:     /^127(?:\.\d{1,3}){3}$/.test(url.hostname);
26:   if (!isLoopback || !['http:', 'https:'].includes(url.protocol) || url.username || url.password ||
27:       url.search || url.hash || url.pathname !== '/') invalid();
```

## E066 Chatbot role
backend/src/chatbot/chatbot.controller.ts:14
```
14: @Roles(AuthRole.LANDLORD)
15: @UseFilters(ChatbotExceptionFilter)
16: export class ChatbotController {
17:   constructor(private readonly chatbot: ChatbotService) {}
18: 
19:   @Post('ask')
20:   @HttpCode(200)
21:   @UseGuards(ChatbotRateLimitGuard)
22:   async ask(@CurrentUser() user: AuthUser, @Body() input: AskChatbotDto) {
```

## E067 Local lease PDF
lib/features/tenants/lease_pdf.dart:1
```
1: import 'dart:typed_data';
2: 
3: import 'package:pdf/pdf.dart';
4: import 'package:pdf/widgets.dart' as pw;
5: import 'package:printing/printing.dart';
6: 
7: import '../../core/utils/format.dart';
8: import '../../models/lease.dart';
9: import '../../models/tenant.dart';
```

## E068 Local invoice PDF
lib/features/billing/invoice_pdf.dart:1
```
1: import 'package:flutter/services.dart';
2: import 'package:pdf/pdf.dart';
3: import 'package:pdf/widgets.dart' as pw;
4: import 'package:printing/printing.dart';
5: 
6: import '../../core/utils/format.dart';
7: import '../../models/billing.dart';
8: 
9: Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
```

## E069 RegisterScreen tests; validate/register two purposes
test/features/auth/register_screen_test.dart:152
```
152:   testWidgets('purpose selector matches the light authentication fields',
153:       (tester) async {
154:     await _mount(tester);
155:     final dropdown =
156:         tester.widget<DropdownButton<bool>>(find.byType(DropdownButton<bool>));
157:     expect(dropdown.style?.color, kAuthText);
158:     expect(dropdown.style?.fontSize, 15);
159:     expect(dropdown.dropdownColor, kAuthCardBg);
160:     expect(dropdown.isExpanded, isTrue);
```

## E070 AuthService tests; register, duplicate, inactive, change password
backend/src/auth/auth.service.spec.ts:57
```
57:   it('registers as a landlord and normalizes the email', async () => {
58:     prisma.user.create.mockResolvedValue(user);
59:     prisma.refreshToken.create.mockResolvedValue({
60:       id: 'refresh-1',
61:       expiresAt: new Date(Date.now() + 86_400_000),
62:     });
63: 
64:     const service = new AuthService(prisma, jwt, config);
65:     await service.register({
```

## E071 JwtStrategy tests
backend/src/auth/jwt.strategy.spec.ts:20
```
20:   it('maps an active landlord to a typed auth user', async () => {
21:     prisma.user.findUnique.mockResolvedValue({
22:       id: 'u1',
23:       email: 'test@example.com',
24:       role: UserRole.LANDLORD,
25:       isActive: true,
26:     });
27:     const strategy = new JwtStrategy(config, prisma);
28: 
```

## E072 Password change and cache isolation tests
test/features/auth/session_cache_isolation_test.dart:113
```
113:       'password change clears the local session and returns to unauthenticated state',
114:       () async {
115:     final storage = _FakeSessionStorage();
116:     final container = _container(storage);
117:     addTearDown(container.dispose);
118:     final controller = container.read(sessionControllerProvider.notifier);
119:     await controller.login(email: 'a@example.com', password: 'secret');
120:     await controller.changePassword(
121:         currentPassword: 'secret', newPassword: 'NewPassword!123');
```

## E073 Account access send rate-limit unit test
backend/src/auth/account-access.service.spec.ts:4
```
4:   it('rate-limits repeated non-admin account access sends', async () => {
5:     const tx = {
6:       $queryRaw: jest.fn(),
7:       user: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'user', email: 'user@example.test', isActive: true, role: 'TENANT' }) },
8:       accountAccessToken: {
9:         findFirst: jest.fn().mockResolvedValue({ createdAt: new Date() }),
10:         count: jest.fn().mockResolvedValue(1),
11:       },
12:     } as any;
```

## E074 Account access link parsing and recovery UI tests
test/features/auth/account_access_test.dart:10
```
10:   test('activation handles fragments, query links, and malformed tokens safely',
11:       () {
12:     expect(
13:         accountAccessTokenFromUri(Uri.parse('/account/activate#token=$token')),
14:         token);
15:     expect(
16:         accountAccessTokenFromUri(Uri.parse('/account/activate?token=$token')),
17:         token);
18:     expect(
```

## E075 Tenant invite create tests, không phải accept E2E
backend/src/tenants/tenant-invites.service.spec.ts:32
```
32:   it('creates a hashed activation invite for an active tenant', async () => {
33:     const expiresAt = new Date(Date.now() + 86_400_000);
34:     prisma.tenant.findFirst.mockResolvedValue({ id: 'tenant-1', userId: null });
35:     prisma.user.findUnique.mockResolvedValue(null);
36:     prisma.tenantInvite.create.mockResolvedValue({
37:       id: 'invite-1',
38:       email: 'tenant@example.com',
39:       expiresAt,
40:     });
```

## E076 Tenant and STAFF accept E2E source; chưa chạy
backend/test/e2e/app-functional.e2e-spec.ts:151
```
151:   it('limits tenant invite resends, invalidates the previous link and consumes activation exactly once', async () => {
152:     const tenant = await createTenant(harness.baseUrl, ownerToken, 'Invited tenant');
153:     const email = `${randomUUID()}@example.test`;
154:     const first = await api(`tenants/${tenant.id}/invite`, ownerToken, 'POST', { email });
155:     expect(first.status).toBe(201);
156:     expect((await api(`tenants/${tenant.id}/invite`, ownerToken, 'POST', { email })).status).toBe(429);
157:     await harness.prisma.tenantInvite.update({ where: { id: first.json!.data.id }, data: { createdAt: new Date(Date.now() - 61_000) } });
158:     const second = await api(`tenants/${tenant.id}/invite`, ownerToken, 'POST', { email });
159:     expect(second.status).toBe(201);
```

## E077 Own-session revoke E2E source; chưa chạy
backend/test/e2e/admin-next-sprints.e2e-spec.ts:42
```
42:   it('revokes other devices while retaining the current session', async () => {
43:     const first = await registerLandlord(harness.baseUrl, 'session-all');
44:     const second = await login(harness.baseUrl, first.email);
45:     const result = await requestJson(harness.baseUrl, '/api/v1/auth/sessions/revoke-all', {
46:       method: 'POST', token: first.accessToken,
47:     });
48:     expect(result.json.data.revoked).toBe(1);
49:     expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: first.accessToken })).status).toBe(200);
50:     expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: second.accessToken })).status).toBe(401);
```

## E078 Auth refresh/logout E2E source; chưa chạy
backend/test/e2e/auth.e2e-spec.ts:58
```
58:   it('logs in, serves /auth/me, rotates refresh tokens, and logs out', async () => {
59:     const registered = await registerLandlord(harness.baseUrl, 'auth-login');
60: 
61:     const badLogin = await requestJson(harness.baseUrl, '/api/v1/auth/login', {
62:       method: 'POST',
63:       body: { email: registered.email, password: 'WrongPassword!123' },
64:     });
65:     expect(badLogin.status).toBe(401);
66: 
```

## E079 LeasesService.create
backend/src/leases/leases.service.ts:87
```
87:   async create(landlordId: string, input: CreateLeaseDto) {
88:     const lease = await this.prisma.$transaction((tx) =>
89:       this.createWithinTransaction(tx, landlordId, input));
90:     return { data: this.serialize(lease) };
91:   }
92: 
93:   async createWithinTransaction(
94:     tx: Prisma.TransactionClient,
95:     landlordId: string,
```

## E080 LeasesService.end
backend/src/leases/leases.service.ts:160
```
160:   async end(landlordId: string, id: string) {
161:     const lease = await this.prisma.$transaction(async (tx) => {
162:       const found = await tx.lease.findFirst({
163:         where: { id, room: { property: propertyWhere(landlordId) } },
164:       });
165:       if (!found) throw leaseNotFound();
166: 
167:       await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${found.roomId} FOR UPDATE`;
168:       const latest = await tx.lease.findUniqueOrThrow({ where: { id } });
```

## E081 TurnoversService.advance
backend/src/operations/turnovers.service.ts:35
```
35:   async advance(user: AuthUser, id: string, input: AdvanceTurnoverDto) {
36:     return this.prisma.$transaction(async tx => {
37:       const owned = await tx.roomTurnover.findFirst({ where: { id, landlordId: landlordScopeId(user) } });
38:       if (!owned) throw new NotFoundException('Không tìm thấy quy trình trả phòng.');
39:       await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${owned.roomId} FOR UPDATE`;
40:       const current = await tx.roomTurnover.findUniqueOrThrow({ where: { id } });
41:       if (current.status !== 'ACTIVE' || current.version !== input.version || current.stage !== input.stage) throw new ConflictException('Quy trình đã thay đổi. Hãy tải lại.');
42:       if (await tx.lease.count({ where: { roomId: current.roomId, status: 'ACTIVE' } })) throw new ConflictException('Phòng đã có hợp đồng đang thuê.');
43:       const nextStage = turnoverStages[turnoverStages.indexOf(current.stage) + 1];
```

## E082 LeaseSettlementsService.confirm
backend/src/leases/settlements.service.ts:61
```
61:   async confirm(actor: AuthUser, leaseId: string, input: ConfirmLeaseSettlementDto) {
62:     const ownerId = this.owner(actor);
63:     return this.write(async tx => {
64:       const lease = await this.locked(ownerId, leaseId, tx);
65:       if (lease.settlement) {
66:         if (lease.settlement.requestKey !== input.idempotencyKey || lease.settlement.requestHash !== this.requestHash(input) || lease.settlement.previewFingerprint !== input.previewFingerprint) {
67:           throw new ConflictException('Hợp đồng đã được quyết toán bằng request khác.');
68:         }
69:         return { data: this.serialize(lease.settlement), idempotent: true };
```

## E083 LeaseSettlementsService.preview
backend/src/leases/settlements.service.ts:53
```
53:   async preview(actor: AuthUser, leaseId: string, input: LeaseSettlementDto) {
54:     const ownerId = this.owner(actor);
55:     return this.prisma.$transaction(async tx => {
56:       const lease = await this.findOwned(ownerId, leaseId, tx);
57:       return { data: await this.calculate(lease, input, tx) };
58:     }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
59:   }
60: 
61:   async confirm(actor: AuthUser, leaseId: string, input: ConfirmLeaseSettlementDto) {
```

## E084 LeaseSettlementsService.recordRefund
backend/src/leases/settlements.service.ts:101
```
101:   async recordRefund(actor: AuthUser, leaseId: string, input: RecordSettlementRefundDto) {
102:     const ownerId = this.owner(actor);
103:     return this.write(async tx => {
104:       const lease = await this.locked(ownerId, leaseId, tx);
105:       const settlement = lease.settlement;
106:       if (!settlement) throw new NotFoundException('Chưa có quyết toán cho hợp đồng.');
107:       if (settlement.refundStatus === 'PAID') {
108:         if (settlement.refundRequestKey === input.idempotencyKey && settlement.refundReference === input.reference.trim()) return { data: this.serialize(settlement), idempotent: true };
109:         throw new ConflictException('Khoản hoàn cọc đã được ghi nhận.');
```

## E085 TenantLifecycleService.executeRequest
backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148
```
148:   async executeRequest(actor: AuthUser, id: string, input: ExecuteLifecycleDto, now = new Date()) {
149:     const landlordId = landlordScopeId(actor);
150:     const hash = createHash('sha256').update(JSON.stringify({ id, monthlyRent: input.monthlyRent ?? null })).digest('hex');
151:     try {
152:       return await this.prisma.$transaction(async tx => {
153:         const request = await tx.tenantLifecycleRequest.findFirst({ where: { id, landlordId,
154:           lease: { room: { property: propertyWhere(landlordId) } },
155:           OR: [{ requestedRoomId: null }, { requestedRoom: { property: propertyWhere(landlordId) } }] } });
156:         if (!request?.leaseId) throw new NotFoundException('Request not found.');
```

## E086 BillingService.reviewPaymentProof
backend/src/billing/billing.service.ts:1053
```
1053:   async reviewPaymentProof(
1054:     landlordId: string,
1055:     proofId: string,
1056:     reviewerId: string,
1057:     input: ReviewPaymentProofDto,
1058:   ) {
1059:     const decision = this.paymentProofStatus(input.status);
1060:     if (decision === PaymentProofStatus.REJECTED) requiredReason(input.note ?? '');
1061:     if (decision === PaymentProofStatus.PENDING) {
```

## E087 BillingService.cancelInvoice
backend/src/billing/billing.service.ts:1245
```
1245:   async cancelInvoice(
1246:     landlordId: string,
1247:     invoiceId: string,
1248:     input: CancelInvoiceDto,
1249:     actor?: AuthUser,
1250:   ) {
1251:     requiredReason(input.note);
1252:     const updated = await this.prisma.$transaction(async (tx) => {
1253:       const invoice = await this.lockOwnedInvoice(tx, landlordId, invoiceId);
```

## E088 BillingService.reversePayment
backend/src/billing/billing.service.ts:1185
```
1185:   async reversePayment(
1186:     landlordId: string,
1187:     invoiceId: string,
1188:     paymentId: string,
1189:     input: ReversePaymentDto,
1190:   ) {
1191:     try {
1192:       const updated = await this.prisma.$transaction(async (tx) => {
1193:         const invoice = await this.lockOwnedInvoice(tx, landlordId, invoiceId);
```

## E089 ReportsService.monthly
backend/src/reports/reports.service.ts:18
```
18:   async monthly(landlordId: string, month?: string, propertyId?: string) {
19:     if (month && !Number.isFinite(new Date(month).getTime())) throw new BadRequestException('Tháng báo cáo không hợp lệ.');
20:     const monthStart = this.monthStart(month ? new Date(month) : new Date());
21:     const nextMonth = this.addMonths(monthStart, 1);
22:     if (propertyId) {
23:       const property = await this.prisma.property.findFirst({
24:         where: { id: propertyId, ...propertyWhere(landlordId), isArchived: false },
25:         select: { id: true },
26:       });
```

## E090 ListingsService.visibleWhere
backend/src/listings/listings.service.ts:290
```
290:   private visibleWhere(): Prisma.RoomListingWhereInput {
291:     return { status: ListingStatus.PUBLISHED, room: { isActive: true, status: RoomStatus.VACANT,
292:       property: { isArchived: false, landlord: { isActive: true } } } };
293:   }
294: 
295:   private filters(query: PublicListingsQuery): Prisma.RoomListingWhereInput {
296:     if (query.minPrice !== undefined && query.maxPrice !== undefined && query.minPrice > query.maxPrice) {
297:       throw new BadRequestException('Giá tối thiểu phải nhỏ hơn hoặc bằng giá tối đa.');
298:     }
```

## E091 ListingsService.update
backend/src/listings/listings.service.ts:104
```
104:   async update(actor: AuthUser, id: string, input: UpdateListingDto) {
105:     this.validateCoordinates(input);
106:     const { version, ...content } = input;
107:     return this.mutate(actor, id, version, 'listing.update', async () => ({
108:       ...content, status: ListingStatus.DRAFT, reviewNote: null, publishedAt: null,
109:       landlordVerifiedAt: null, inspectedAt: null, availabilityConfirmedAt: null,
110:     }));
111:   }
112: 
```

## E092 SavedSearchesService.create
backend/src/listings/saved-searches.service.ts:25
```
25:   async create(userId: string, input: SavedSearchDto) {
26:     if (input.filters.campusId && !await this.prisma.schoolCampus.findFirst({ where: { id: input.filters.campusId, isActive: true } })) {
27:       throw new BadRequestException('Cơ sở trường không còn hoạt động.');
28:     }
29:     return this.prisma.$transaction(async tx => {
30:       await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
31:       if (await tx.savedSearch.count({ where: { userId } }) >= 10) throw new ConflictException('Bạn chỉ có thể lưu tối đa 10 tìm kiếm.');
32:       const { page, limit, ...filters } = input.filters;
33:       const data = await tx.savedSearch.create({ data: { userId, name: input.name, filters: filters as Prisma.InputJsonObject } });
```

## E093 SupportAttachmentService.upload
backend/src/support/support-attachment.service.ts:25
```
25:   async upload(actor: AuthUser, id: string, input: SupportAttachmentDto, file?: { buffer: Buffer; mimetype: string }) {
26:     const internal = input.internal === 'true';
27:     const ticket = await this.ticket(actor, id, internal);
28:     if (ticket.version !== input.version || ticket.mergedIntoId || ['RESOLVED', 'CLOSED'].includes(ticket.status)) throw new ConflictException('Ticket changed or closed.');
29:     if (!file || !file.buffer.length || file.buffer.length > 8 * 1024 * 1024) throw new BadRequestException('Select a file up to 8 MB.');
30:     const type = detectFile(file.buffer);
31:     if (!type || !['image/jpeg', 'image/png', 'image/webp', 'application/pdf'].includes(type.mime) || type.mime !== file.mimetype) throw new BadRequestException('File content and MIME must match a supported image or PDF.');
32:     const sha256 = await this.scanner.scan(file.buffer, type.mime);
33:     const filename = `${randomUUID()}.${type.extension}`;
```

## E094 HousingService.createLease
backend/src/housing/housing.service.ts:240
```
240:   async createLease(user: AuthUser, id: string, input: ViewingLeaseDto) {
241:     return this.atomic(async (tx) => {
242:       const viewing = await this.lockViewing(tx, user, id, input.version);
243:       if (viewing.status !== 'COMPLETED') throw new ConflictException('Chỉ tạo hợp đồng sau khi đã xem phòng.');
244:       const listing = await tx.roomListing.findFirst({ where: { id: viewing.listingId, ...available } });
245:       if (!listing) throw new ConflictException('Phòng không còn trống hoặc tin đã ngừng nhận khách.');
246:       const student = await tx.user.findUniqueOrThrow({ where: { id: viewing.studentId } });
247:       if (!student.isActive) throw new ConflictException('Tài khoản người thuê đã ngừng hoạt động.');
248:       const existing = await tx.tenant.findUnique({ where: { userId: student.id } });
```
