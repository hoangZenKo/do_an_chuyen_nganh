# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

- Landlords use the app to manage properties, rooms, tenants, leases, billing, expenses, maintenance, reports, notifications, and staff/admin workflows.
- Tenants use the tenant portal to check rent status, invoices, leases, maintenance requests, notifications, and landlord messages.

## Product Purpose

Rental Room Management is a Flutter app for running rental-property operations from a mobile-first interface. Success means users can quickly see what matters, take the next action, and stay in sync with the backend system.

## Positioning

It centralizes rental operations into a tenant and landlord workflow tied to the live NestJS API, with role-based routing and session-aware startup.

## Operating Context

- Vietnamese-first UI copy is used throughout the app.
- The app runs with splash, onboarding, auth, role routing, and portal/dashboard surfaces.
- The tenant portal is used on mobile as a quick check-in surface for rent, invoices, maintenance, and landlord communication.
- Flutter consumes the backend under `/api/v1`.

## Capabilities and Constraints

- Role routing exists for `admin`, `landlord`, `tenant`, and `staff`.
- Tenant portal data includes profile, active lease, dashboard counts, invoices, lease history, notifications, Zalo messages, and maintenance tickets.
- The UI uses the Manrope font and a green primary theme.
- iOS project files are present in the repo; no web or Android scaffold is visible in the current workspace snapshot.

## Brand Commitments

- Product name: `Rental Room Management`.
- Existing assets: `assets/images/atrium_living_logo.png` and `assets/images/zalo_logo.png`.
- Tone: practical, direct, Vietnamese-first.

## Evidence on Hand

- `README.md`
- `pubspec.yaml`
- `lib/core/theme/app_theme.dart`
- `lib/app/app.dart`
- `lib/features/tenant_portal/tenant_portal_screen.dart`
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
