# Admin Route And Permission Inventory

Generated from controller metadata; API prefix: `/api/v1`. Regenerate with `npx tsx scripts/admin-route-inventory.ts`.

This is an RBAC inventory, not production acceptance. All required permissions are ANDed. Shared routes additionally enforce requester/resource ownership in services. MFA, account/session revocation, feature flags, step-up and domain-specific checks still apply.

Exception: `/admin/me/security` GET and enroll/confirm POST use JWT plus an explicit ADMIN role/profile check bound to the current user, without RolesGuard/capability metadata. This allows initial MFA enrollment before MFA verification. The release gate tests these three self-only routes separately.

`account-invites` additionally checks `admin.admins.manage` plus fresh MFA for ADMIN, or `admin.accounts.manage` for LANDLORD. `moderation/queue`, `moderation/work`, analytics, context and search filter/check domain capabilities in the service. Admin profile changes verify fresh MFA directly. Step-up rules apply in production or with `ADMIN_STEP_UP_REQUIRED=true`; step-up does not replace route capabilities.

| Method | Route | Allowed Roles | Required Capabilities | Presets (Metadata Only) | Step-Up Action |
|---|---|---|---|---|---|
| GET | `/admin/access-reviews` | admin | `admin.admins.manage` | super_admin | - |
| POST | `/admin/access-reviews/:id` | admin | `admin.admins.manage` | super_admin | access.review |
| POST | `/admin/account-invites` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/accounts` | admin | `admin.accounts.view` | super_admin, support | - |
| GET | `/admin/accounts/:id` | admin | `admin.accounts.view` | super_admin, support | - |
| POST | `/admin/accounts/:id/reset-password` | admin | `admin.accounts.manage` | super_admin | - |
| POST | `/admin/accounts/:id/restore` | admin | `admin.accounts.suspend` | super_admin | - |
| POST | `/admin/accounts/:id/reveal` | admin | `admin.pii.reveal` | super_admin | pii.reveal |
| POST | `/admin/accounts/:id/revoke-sessions` | admin | `admin.sessions.revoke` | super_admin | - |
| POST | `/admin/accounts/:id/suspend` | admin | `admin.accounts.suspend` | super_admin | account.suspend |
| GET | `/admin/admins` | admin | `admin.admins.manage` | super_admin | - |
| PATCH | `/admin/admins/:id` | admin | `admin.admins.manage` | super_admin | - |
| GET | `/admin/admins/:id/access` | admin | `admin.admins.manage` | super_admin | - |
| GET | `/admin/admins/:id/lifecycle` | admin | `admin.admins.manage` | super_admin | - |
| POST | `/admin/admins/:id/resend-invite` | admin | `admin.admins.manage` | super_admin | admin.invite.resend |
| POST | `/admin/admins/:id/revoke-sessions` | admin | `admin.admins.manage`, `admin.sessions.revoke` | super_admin | admin.sessions.revoke |
| GET | `/admin/analytics/overview` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/analytics/summary` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/audit-logs` | admin | `admin.audit.view` | super_admin | - |
| GET | `/admin/audit-logs/:id` | admin | `admin.audit.view` | super_admin | - |
| POST | `/admin/audit-logs/export` | admin | `admin.audit.view`, `admin.audit.export` | super_admin | audit.export |
| GET | `/admin/campuses` | admin | `admin.campuses.manage` | super_admin, moderator | - |
| POST | `/admin/campuses` | admin | `admin.campuses.manage` | super_admin, moderator | - |
| PATCH | `/admin/campuses/:id` | admin | `admin.campuses.manage` | super_admin, moderator | - |
| GET | `/admin/feature-flags` | admin | `admin.flags.manage` | super_admin | - |
| PATCH | `/admin/feature-flags/:key` | admin | `admin.flags.manage` | super_admin | - |
| GET | `/admin/feature-flags/effective` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/finance/reconciliation` | admin | `admin.finance.read` | super_admin, analyst | - |
| GET | `/admin/finance/reconciliation-proposals` | admin | `admin.finance.read`, `admin.finance.reconcile` | super_admin | - |
| POST | `/admin/finance/reconciliation-proposals/:id/approve` | admin | `admin.finance.read`, `admin.finance.reconcile` | super_admin | - |
| POST | `/admin/finance/reconciliation-proposals/:id/reject` | admin | `admin.finance.read`, `admin.finance.reconcile` | super_admin | - |
| GET | `/admin/finance/statement-lines` | admin | `admin.finance.read` | super_admin, analyst | - |
| GET | `/admin/finance/statement-lines/:id/candidates` | admin | `admin.finance.read`, `admin.finance.reconcile` | super_admin | - |
| POST | `/admin/finance/statement-lines/:id/proposals` | admin | `admin.finance.read`, `admin.finance.reconcile` | super_admin | - |
| POST | `/admin/finance/statements` | admin | `admin.finance.read`, `admin.finance.reconcile` | super_admin | - |
| GET | `/admin/finance/transactions` | admin | `admin.finance.read` | super_admin, analyst | - |
| GET | `/admin/landlord-verifications` | admin | `admin.verifications.view`, `admin.support.read` | super_admin | - |
| POST | `/admin/landlord-verifications` | admin | `admin.verifications.manage`, `admin.support.read` | super_admin | - |
| POST | `/admin/landlord-verifications/:id/review` | admin | `admin.verifications.manage`, `admin.support.read` | super_admin | verification.review |
| GET | `/admin/landlords` | admin | `admin.accounts.manage` | super_admin | - |
| POST | `/admin/landlords` | admin | `admin.accounts.manage` | super_admin | - |
| GET | `/admin/landlords/:id` | admin | `admin.accounts.manage` | super_admin | - |
| PATCH | `/admin/landlords/:id` | admin | `admin.accounts.manage` | super_admin | - |
| PATCH | `/admin/landlords/:id/status` | admin | `admin.accounts.suspend` | super_admin | landlord.status |
| POST | `/admin/landlords/:id/subscription` | admin | `admin.plans.manage` | super_admin | subscription.assign |
| GET | `/admin/listings` | admin | `admin.listings.moderate` | super_admin, moderator | - |
| POST | `/admin/listings/:id/review` | admin | `admin.listings.moderate` | super_admin, moderator | - |
| POST | `/admin/listings/:id/verification` | admin | `admin.listings.moderate` | super_admin, moderator | - |
| GET | `/admin/listings/reports` | admin | `admin.listings.moderate` | super_admin, moderator | - |
| POST | `/admin/listings/reports/:id/review` | admin | `admin.listings.moderate` | super_admin, moderator | - |
| GET | `/admin/me/capabilities` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/me/security` | ADMIN self-only (service) | JWT + own admin profile | self-enrollment | - |
| POST | `/admin/me/security/confirm` | ADMIN self-only (service) | JWT + own admin profile | self-enrollment | - |
| POST | `/admin/me/security/enroll` | ADMIN self-only (service) | JWT + own admin profile | self-enrollment | - |
| POST | `/admin/me/security/step-up` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/moderation-policies` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| POST | `/admin/moderation-policies` | admin | `admin.admins.manage` | super_admin | - |
| POST | `/admin/moderation-policies/:id/activate` | admin | `admin.admins.manage` | super_admin | - |
| GET | `/admin/moderation-policies/quality` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| GET | `/admin/moderation-policies/quality/samples` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| GET | `/admin/moderation-policies/quality/samples/:id` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| POST | `/admin/moderation-policies/quality/samples/:id/review` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| GET | `/admin/moderation-v2/appeals` | admin | `admin.moderation.appeals` | super_admin, moderator | - |
| POST | `/admin/moderation-v2/appeals/:id/assign` | admin | `admin.moderation.appeals` | super_admin, moderator | - |
| POST | `/admin/moderation-v2/appeals/:id/resolve` | admin | `admin.moderation.appeals` | super_admin, moderator | - |
| POST | `/admin/moderation-v2/bulk` | admin | `admin.moderation.bulk` | super_admin, moderator | moderation.bulk |
| POST | `/admin/moderation-v2/bulk/preview` | admin | `admin.moderation.bulk` | super_admin, moderator | - |
| GET | `/admin/moderation-v2/decisions` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| GET | `/admin/moderation-v2/history/:kind/:id` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/moderation-v2/reports` | admin | `admin.moderation.reports` | super_admin, moderator, analyst | - |
| GET | `/admin/moderation/items/:kind/:id` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/moderation/queue` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| POST | `/admin/moderation/work` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/operations/delivery-jobs` | admin | `admin.operations.view` | super_admin | - |
| GET | `/admin/operations/health` | admin | `admin.operations.view` | super_admin | - |
| GET | `/admin/operations/incidents` | admin | `admin.operations.view` | super_admin | - |
| GET | `/admin/operations/incidents/:id` | admin | `admin.operations.view` | super_admin | - |
| POST | `/admin/operations/incidents/:id/acknowledge` | admin | `admin.operations.manage` | super_admin | - |
| POST | `/admin/operations/incidents/:id/actions` | admin | `admin.operations.view`, `admin.operations.manage` | super_admin | - |
| GET | `/admin/operations/incidents/assignees` | admin | `admin.operations.view` | super_admin | - |
| GET | `/admin/operations/notification-delivery` | admin | `admin.operations.view` | super_admin | - |
| POST | `/admin/operations/notification-delivery/:id/retry` | admin | `admin.operations.view`, `admin.operations.manage` | super_admin | - |
| GET | `/admin/overview` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/permission-catalog` | admin | `admin.admins.manage` | super_admin | - |
| POST | `/admin/permissions/simulate` | admin | `admin.permissions.simulate` | super_admin | - |
| GET | `/admin/properties` | admin | `admin.properties.view` | super_admin, support | - |
| POST | `/admin/properties` | admin | `admin.properties.manage` | super_admin | - |
| GET | `/admin/properties/:id` | admin | `admin.properties.view` | super_admin, support | - |
| PATCH | `/admin/properties/:id` | admin | `admin.properties.manage` | super_admin | - |
| POST | `/admin/properties/:id/submit-review` | admin | `admin.properties.manage` | super_admin | - |
| GET | `/admin/property-reviews` | admin | `admin.properties.view` | super_admin, support | - |
| POST | `/admin/property-reviews/:id/review` | admin | `admin.properties.manage` | super_admin | property.review |
| GET | `/admin/report-runs/:id/download` | admin | `admin.reports.manage` | super_admin, analyst | - |
| POST | `/admin/report-runs/:id/download-link` | admin | `admin.reports.manage` | super_admin, analyst | - |
| POST | `/admin/report-runs/:id/retry` | admin | `admin.reports.manage` | super_admin, analyst | - |
| GET | `/admin/report-schedules` | admin | `admin.reports.manage` | super_admin, analyst | - |
| POST | `/admin/report-schedules` | admin | `admin.reports.manage` | super_admin, analyst | - |
| PATCH | `/admin/report-schedules/:id` | admin | `admin.reports.manage` | super_admin, analyst | - |
| POST | `/admin/report-schedules/:id/run` | admin | `admin.reports.manage` | super_admin, analyst | - |
| GET | `/admin/report-schedules/:id/runs` | admin | `admin.reports.manage` | super_admin, analyst | - |
| GET | `/admin/resources` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/resources/:id` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/room-reviews` | admin | `admin.reviews.moderate` | super_admin, moderator | - |
| POST | `/admin/room-reviews/:id/moderate` | admin | `admin.reviews.moderate` | super_admin, moderator | - |
| POST | `/admin/room-reviews/:id/reply/moderate` | admin | `admin.reviews.moderate` | super_admin, moderator | - |
| GET | `/admin/rooms` | admin | `admin.properties.view` | super_admin, support | - |
| GET | `/admin/search` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/service-plans` | admin | `admin.plans.view` | super_admin | - |
| POST | `/admin/service-plans` | admin | `admin.plans.manage` | super_admin | plan.save |
| GET | `/admin/subscriptions` | admin | `admin.plans.view` | super_admin | - |
| POST | `/admin/subscriptions/:id/cancel` | admin | `admin.plans.manage` | super_admin | subscription.cancel |
| GET | `/admin/subscriptions/:id/events` | admin | `admin.plans.view` | super_admin | - |
| POST | `/admin/support-cases/:id/links` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| POST | `/admin/support-cases/:id/timeline` | admin | `admin.support.read` | super_admin, support | - |
| POST | `/admin/support-context` | admin | `admin.support.read` | super_admin, support | - |
| GET | `/admin/support-sla-policy` | admin | `admin.support.read`, `admin.support.manage`, `admin.admins.manage` | super_admin | - |
| PATCH | `/admin/support-sla-policy` | admin | `admin.support.read`, `admin.support.manage`, `admin.admins.manage` | super_admin | - |
| GET | `/admin/team` | admin | `admin.teams.manage` | super_admin | - |
| GET | `/admin/teams` | admin | `admin.teams.manage` | super_admin | - |
| POST | `/admin/teams` | admin | `admin.teams.manage` | super_admin | - |
| PATCH | `/admin/teams/:id` | admin | `admin.teams.manage` | super_admin | - |
| POST | `/admin/teams/:id/members` | admin | `admin.teams.manage` | super_admin | - |
| POST | `/admin/teams/:id/members/:userId/remove` | admin | `admin.teams.manage` | super_admin | - |
| GET | `/admin/workspace/action-items` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/admin/workspace/summary` | admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/housing/feedback` | admin | `admin.listings.moderate` | super_admin, moderator | - |
| GET | `/housing/pilot` | tenant, landlord, admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/moderation/appeals` | landlord, tenant, staff, admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| POST | `/moderation/appeals` | landlord, tenant, staff, admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/moderation/decisions` | landlord, tenant, staff, admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/moderation/features` | landlord, tenant, staff, admin | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/notification-center` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| POST | `/notification-center/:id/read` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| GET | `/notification-center/preferences` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| PATCH | `/notification-center/preferences` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| POST | `/notification-center/read-all` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| GET | `/support/notifications` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| POST | `/support/notifications/:id/read` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| POST | `/support/notifications/read-all` | admin, landlord, staff, tenant | `admin.notifications.view` | super_admin, support, moderator, analyst | - |
| GET | `/support/skills` | admin | `admin.support.read`, `admin.support.manage`, `admin.admins.manage` | super_admin | - |
| PATCH | `/support/skills/:id` | admin | `admin.support.read`, `admin.support.manage`, `admin.admins.manage` | super_admin | - |
| GET | `/support/templates` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| POST | `/support/templates` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| PATCH | `/support/templates/:id` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| GET | `/support/tickets` | admin, landlord, staff, tenant | `admin.support.read` | super_admin, support | - |
| POST | `/support/tickets` | admin, landlord, staff, tenant | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| GET | `/support/tickets/:id` | admin, landlord, staff, tenant | `admin.support.read` | super_admin, support | - |
| PATCH | `/support/tickets/:id/assignment` | admin, landlord, staff, tenant | `admin.support.read` | super_admin, support | - |
| POST | `/support/tickets/:id/attachments` | admin, landlord, staff, tenant | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| POST | `/support/tickets/:id/auto-assign` | admin | `admin.support.read`, `admin.support.manage`, `admin.admins.manage` | super_admin | - |
| POST | `/support/tickets/:id/feedback` | admin, landlord, staff, tenant | `admin.dashboard.view` | super_admin, support, moderator, analyst | - |
| PATCH | `/support/tickets/:id/labels` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| POST | `/support/tickets/:id/merge` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| POST | `/support/tickets/:id/notes` | admin, landlord, staff, tenant | `admin.support.read` | super_admin, support | - |
| POST | `/support/tickets/:id/replies` | admin, landlord, staff, tenant | `admin.support.read` | super_admin, support | - |
| PATCH | `/support/tickets/:id/status` | admin, landlord, staff, tenant | `admin.support.read` | super_admin, support | - |
| GET | `/support/tickets/assignees` | admin | `admin.support.manage` | super_admin, support | - |
| GET | `/support/tickets/teams` | admin | `admin.support.manage` | super_admin, support | - |
| GET | `/support/views` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| POST | `/support/views` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| DELETE | `/support/views/:id` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| PATCH | `/support/views/:id` | admin | `admin.support.read`, `admin.support.manage` | super_admin, support | - |
| GET | `/uploads/:filename/access` | landlord, tenant, staff, admin | `admin.support.read` | super_admin, support | - |

## Presets

- `super_admin`: `admin.dashboard.view`, `admin.accounts.view`, `admin.accounts.manage`, `admin.accounts.suspend`, `admin.sessions.revoke`, `admin.properties.view`, `admin.properties.manage`, `admin.support.read`, `admin.pii.reveal`, `admin.listings.moderate`, `admin.reviews.moderate`, `admin.audit.view`, `admin.campuses.manage`, `admin.admins.manage`, `admin.operations.view`, `admin.operations.manage`, `admin.audit.export`, `admin.support.manage`, `admin.notifications.view`, `admin.moderation.appeals`, `admin.moderation.bulk`, `admin.moderation.reports`, `admin.flags.manage`, `admin.teams.manage`, `admin.permissions.simulate`, `admin.finance.read`, `admin.finance.reconcile`, `admin.reports.manage`, `admin.verifications.view`, `admin.verifications.manage`, `admin.plans.view`, `admin.plans.manage`
- `support`: `admin.dashboard.view`, `admin.accounts.view`, `admin.properties.view`, `admin.support.read`, `admin.support.manage`, `admin.notifications.view`
- `moderator`: `admin.dashboard.view`, `admin.listings.moderate`, `admin.reviews.moderate`, `admin.campuses.manage`, `admin.moderation.appeals`, `admin.moderation.bulk`, `admin.moderation.reports`, `admin.notifications.view`
- `analyst`: `admin.dashboard.view`, `admin.moderation.reports`, `admin.finance.read`, `admin.reports.manage`, `admin.notifications.view`

163 route entries; 32 capabilities. Explicit grants use the versioned Admin profile command: fresh MFA, active super-admin grant authority, no self-change, no delegation outside the actor's current permissions, session revocation and before/after audit. Preset-only commands remain supported. No break-glass policy introduced.
