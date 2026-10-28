---
version: 1
slug: "b-features-tenant-portal-tenant-portal-screen-dart"
primary_target: "lib/features/tenant_portal/tenant_portal_screen.dart"
related_targets: ["lib/features/tenant_portal/tenant_portal_providers.dart","lib/core/theme/app_theme.dart","lib/features/tenant_portal/tenant_maintenance_screen.dart"]
---

Scope: Tenant portal dashboard plus tenant maintenance management in `lib/features/tenant_portal/tenant_portal_screen.dart` and `lib/features/tenant_portal/tenant_maintenance_screen.dart`.

Mode: Operate.

Audience: authenticated tenants checking rent, lease, maintenance, invoices, and landlord messages on mobile.

Job: understand status fast, open the next invoice, review messages, create maintenance requests, follow ticket progress, and add comments or attachments when the landlord responds.

Proof/content: live profile, active lease, outstanding balance, invoice due status, unread notifications, Zalo previews, maintenance ticket status/priority/comments, and payment proof context.

Constraints: preserve existing routes and backend data, keep Vietnamese copy, keep the green/Manrope identity, and make the screen easy to scan one-handed on small displays.

Direction: a modern personal rent status board with a deep green hero, a crisp white payment summary, Material Icons only, panelized secondary sections, one-tap access to invoice, maintenance, Zalo, and notification work, plus a dark focused maintenance list for filtering, creating, and replying to tickets.

Memorable moment: the first viewport tells the tenant whether money is owed, when it is due, where they live, and what action to take next; the maintenance screen turns every repair request into a compact status card with an immediate report button.

Open decisions: whether to later add native motion between status changes once the Flutter runtime is available for simulator review.
