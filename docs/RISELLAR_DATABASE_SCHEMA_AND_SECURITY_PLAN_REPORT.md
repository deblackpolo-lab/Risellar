# Risellar Database Schema and Security Plan Report

## A. Summary

Created `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN.md`, a complete database schema and RLS/security planning document for Risellar. It is documentation only and does not create migrations, tables, policies, backend code, UI, or Supabase resources.

## B. Source Documents Read

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC_REPORT.md`
- `docs/RISELLAR_FULL_PRD.md`
- `docs/RISELLAR_FULL_PRD_REPORT.md`

## C. Key Schema Decisions Captured

- Clerk maps to a local `profiles` table through `clerk_user_id`.
- Role-specific records are separated into customer, reseller, supplier staff, and admin staff areas.
- Product, variant, stock movement, stock reservation, order, settlement, commission, withdrawal, risk, queue, and audit tables are planned as separate groups.
- Order items store immutable supplier base price, platform margin, reseller margin, reseller cost, customer price, settlement due, and commission snapshots.
- Shared supplier stock is protected by database-side atomic reservation logic.
- Supplier settlement and reseller commission are ledger-style records, not loose status text.

## D. RLS and Security Model

- RLS is required on every application table.
- Customers, resellers, suppliers, inventory managers, support, finance, admin, and super admin each have explicit access boundaries.
- Private storage buckets are planned for KYC, settlement proofs, and dispute evidence.
- Sensitive actions require audit logs.
- Sensitive calculations and transitions are assigned to future secure RPC/database functions.

## E. Assumptions

- Supabase/Postgres is the database target.
- Supabase Storage is used for product images and private file uploads.
- Pay Online remains disabled/placeholder until a real provider is selected.
- No phone OTP, no native mobile, no rider app, and no WhatsApp Business API automation in MVP.
- Audit logs remain indefinitely for MVP unless a legal/storage policy changes.

## F. Open Questions Carried Forward

- Reseller approval default.
- Minimum withdrawal amount.
- Supplier overdue settlement threshold.
- KYC retention policy.
- Ghana Card access boundaries.
- Pay Online provider.
- Delivery SLA and ownership.
- Launch categories and prohibited categories.
- Promotion pricing and duration.
- Trusted supplier and risk thresholds.

## G. Files Created/Changed

- Created `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN.md`
- Created `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN_REPORT.md`

## H. Current Git Status

```text
?? docs/
```

## I. Commands Run

- Read the attached task brief.
- Searched the approved business rules, PRD, and brand/UI docs for schema-relevant requirements.
- Verified the primary plan contains all 63 required sections.
- Verified key security anchors are present.
- Checked current git status.

## J. Recommended Next Step

Review and approve the schema/security plan. The next logical task is generating Supabase migrations and RLS policy drafts from this document, still without building UI.
