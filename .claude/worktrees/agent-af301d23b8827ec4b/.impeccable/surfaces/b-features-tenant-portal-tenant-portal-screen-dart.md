---
version: 1
slug: "b-features-tenant-portal-tenant-portal-screen-dart"
primary_target: "lib/features/tenant_portal/tenant_portal_screen.dart"
related_targets: ["lib/features/tenant_portal/tenant_portal_providers.dart","lib/core/theme/app_theme.dart"]
---

Scope: Tenant portal dashboard in `lib/features/tenant_portal/tenant_portal_screen.dart`.

Mode: Operate.

Audience: authenticated tenants checking rent, lease, maintenance, invoices, and landlord messages on mobile.

Job: understand status fast, open the next invoice, review messages, and jump into maintenance or invoice detail when needed.

Proof/content: live profile, active lease, outstanding balance, invoice due status, unread notifications, Zalo previews, maintenance tickets, and payment proof context.

Constraints: preserve existing routes and backend data, keep Vietnamese copy, keep the green/Manrope identity, and make the screen easy to scan one-handed on small displays.

Direction: a modern, clean tenant home with a strong top summary, fewer stacked cards, clearer priority order, and fast access to the next action.

Memorable moment: the first viewport should read like a personal rent status board, not a generic dashboard.

Open decisions: how much motion to add, and whether to keep all current sections equally prominent or demote some into secondary access.
