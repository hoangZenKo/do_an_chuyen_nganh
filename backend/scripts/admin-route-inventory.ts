import { resolve } from 'node:path';
import { ADMIN_PERMISSIONS, ADMIN_PRESETS } from '../src/common/admin-permissions';
import { adminRouteInventory } from '../src/admin/admin-route-inventory';

const routes = adminRouteInventory(resolve(__dirname, '../src'));
console.log('# Admin Route And Permission Inventory\n');
console.log('Generated from controller metadata; API prefix: `/api/v1`. Regenerate with `npx tsx scripts/admin-route-inventory.ts`.\n');
console.log('This is an RBAC inventory, not production acceptance. All required permissions are ANDed. Shared routes additionally enforce requester/resource ownership in services. MFA, account/session revocation, feature flags, step-up and domain-specific checks still apply.\n');
console.log('Exception: `/admin/me/security` GET and enroll/confirm POST use JWT plus an explicit ADMIN role/profile check bound to the current user, without RolesGuard/capability metadata. This allows initial MFA enrollment before MFA verification. The release gate tests these three self-only routes separately.\n');
console.log('`account-invites` additionally checks `admin.admins.manage` plus fresh MFA for ADMIN, or `admin.accounts.manage` for LANDLORD. `moderation/queue`, `moderation/work`, analytics, context and search filter/check domain capabilities in the service. Admin profile changes verify fresh MFA directly. Step-up rules apply in production or with `ADMIN_STEP_UP_REQUIRED=true`; step-up does not replace route capabilities.\n');
console.log('| Method | Route | Allowed Roles | Required Capabilities | Presets (Metadata Only) | Step-Up Action |');
console.log('|---|---|---|---|---|---|');
for (const route of routes) console.log(`| ${route.method} | \`${route.path}\` | ${route.roles.join(', ') || 'ADMIN self-only (service)'} | ${route.permissions.map(value => `\`${value}\``).join(', ') || 'JWT + own admin profile'} | ${route.presets.join(', ') || 'self-enrollment'} | ${route.stepUp ?? '-'} |`);
console.log('\n## Presets\n');
for (const [preset, permissions] of Object.entries(ADMIN_PRESETS)) console.log(`- \`${preset}\`: ${permissions.map(value => `\`${value}\``).join(', ')}`);
console.log(`\n${routes.length} route entries; ${ADMIN_PERMISSIONS.length} capabilities. Explicit grants use the versioned Admin profile command: fresh MFA, active super-admin grant authority, no self-change, no delegation outside the actor's current permissions, session revocation and before/after audit. Preset-only commands remain supported. No break-glass policy introduced.`);
