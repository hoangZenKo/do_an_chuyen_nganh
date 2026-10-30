# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

- Landlords and staff use the app to manage properties, interactive room maps, rooms, service tariffs, tenants, leases, lease settlements, billing/bulk invoicing, payment events, expenses, P1 operations, maintenance, reports, notifications, and staff workflows.
- Tenants use the tenant portal to check rent status, invoices, online payments, leases, announcements, maintenance requests, notifications, and landlord messages.
- Prospective tenants / students browse public and authenticated room listings, filter by criteria, inspect room details and reviews, and submit viewing or booking requests.
- Platform admins use the admin workspace to oversee landlords, properties, moderation queues, governance/SLA policies, access reviews, step-up authentication, active sessions, finance statements, support cases, and audit logs.

## Product Purpose

Rental Room Management is a Flutter app for running end-to-end rental-property discovery, tenant living, landlord operations, and platform governance from a mobile-first interface. Success means every role can quickly see what matters, take the next action, and stay in sync with the live backend system.

## Positioning

It centralizes rental discovery, landlord/staff operations, tenant self-service, AI-assisted support, and multi-tenant admin governance into a single role-routed workflow tied to the live NestJS API.

## Operating Context

- Vietnamese-first UI copy is used throughout the app.
- The app runs with splash, onboarding, auth (including invite flows and admin step-up verification), role routing, discovery listings, landlord/admin workspaces, and the tenant portal.
- The tenant portal is used on mobile as a quick check-in surface for rent, online payment, invoices, announcements, maintenance, and landlord communication.
- Flutter consumes the backend under `/api/v1`.

## Capabilities and Constraints

- Role routing and specialized surfaces exist for `admin`, `landlord`, `tenant`, and `staff`, plus student/tenant room discovery (`lib/features/listings/`) and an in-app AI chatbot (`lib/features/chatbot/`).
- Landlord workflows include visual room-map dashboards (`lib/features/dashboard/room_map_dashboard.dart`), meter readings, service tariffs, bulk invoicing, lease expiry/settlement (`lib/features/tenants/lease_settlement_screen.dart`), and P1 operational action items (`lib/features/operations/`).
- Tenant portal data includes profile, active lease, dashboard counts, invoices, online payments (`lib/features/tenant_portal/tenant_online_payment_screen.dart`), announcements, lease history, notifications, Zalo messages, and maintenance tickets.
- Admin console workflows include account/session management, moderation v2, SLA policies, access reviews, finance statement CSV exports, support center cases, and audit trails (`lib/features/admin/`).
- The UI uses the Manrope font and a green primary theme.
- iOS project files are present in the repo; `web/` and `backend/` directories also exist in the workspace.

## Brand Commitments

- Product name: `Rental Room Management`.
- Existing assets: `assets/images/atrium_living_logo.png`, `assets/images/atrium_floorplan_scene_reference.png`, and `assets/images/zalo_logo.png`.
- Tone: practical, direct, Vietnamese-first.

## Evidence on Hand

- `README.md`
- `PROJECT_STATUS.md`
- `pubspec.yaml`
- `lib/core/theme/app_theme.dart`
- `lib/app/app.dart`
- `lib/features/dashboard/room_map_dashboard.dart`
- `lib/features/tenant_portal/tenant_portal_screen.dart`
- `lib/features/listings/`
- `lib/features/admin/admin_workspace_screen.dart`
- `lib/features/chatbot/`
- `assets/images/atrium_living_logo.png`
- `assets/images/zalo_logo.png`

## Product Principles

- Make the next status obvious within seconds.
- Keep the mobile experience fast to scan and easy to tap.
- Surface money, lease, maintenance, and messages without forcing deep navigation.
- Preserve role-based behavior and live backend data.

## Accessibility & Inclusion

- Keep the tenant experience readable on small screens.
- Preserve clear contrast, tappable controls, and legible Vietnamese text.
