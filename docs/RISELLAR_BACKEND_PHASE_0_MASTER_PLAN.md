# Risellar Backend Phase 0 Master Plan

> Planning only. This document does not create backend code, migrations, integrations, credentials, storage buckets, payment flows, email sending, WhatsApp automation, or database connections.

## 1. Purpose

This plan defines the safest backend implementation order for Risellar after the approved frontend and documentation phases. It is based on:

- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`
- `docs/RISELLAR_FULL_PRD.md`
- `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN.md`
- `docs/RISELLAR_FRONTEND_BACKEND_HANDOFF_CHECKLIST.md`
- `docs/RISELLAR_FRONTEND_PRD_COVERAGE_AUDIT_REPORT.md`
- `docs/RISELLAR_FRONTEND_PRD_COVERAGE_MATRIX.md`
- Phase 1-15 frontend reports

The backend must preserve Risellar's core trust chain:

```text
Supplier -> Risellar/Admin -> Reseller -> Customer
```

The first backend milestone is not "connect everything." It is to create a controlled, testable, server-enforced foundation where identity, role boundaries, schema shape, audit logging, and mutation contracts are reviewed before any production workflow can move money, reserve stock, release commission, expose private files, or notify users.

## 2. Non-Negotiable Constraints

- Do not connect Paystack, Hubtel, WhatsApp Business API, automated MoMo, or payouts in MVP backend Phase 0.
- Do not enable Pay Online as a real payment method until a provider, webhook model, reconciliation plan, and refund plan are approved.
- Do not trust frontend-sent price, margin, role, supplier ID, reseller ID, settlement amount, commission amount, stock quantity, or payment status.
- Do not expose Supabase service role keys, Clerk secrets, Resend keys, storage signing secrets, or future payment secrets to browser code.
- Do not let suppliers go live before approval.
- Do not let product listings become orderable before supplier, product, variant stock, reseller listing, and restriction checks pass server-side.
- Do not let supplier preparation start before customer confirmation.
- Do not release reseller commission before supplier settlement is verified.
- Do not make KYC, settlement proof, payout, or dispute evidence files public.
- Do not bypass audit logs for admin, finance, inventory, stock, settlement, commission, withdrawal, role, restriction, and manual override actions.

## 3. What Must Be Built First

Build these foundations before feature-specific backend work:

1. Backend decision record and environment contract:
   - Confirm Supabase project boundaries, local/staging/production naming, environment variable names, and secret ownership.
   - Confirm Clerk publishable/secret key handling and webhook signing strategy.
   - Confirm Resend domain/sender strategy without sending real emails yet.

2. Auth and local profile model:
   - Clerk Google and email/password only.
   - Local `profiles` record keyed by internal UUID and unique `clerk_user_id`.
   - Server-side role resolution from trusted database records, not client claims.
   - Manual admin/super admin assignment flow and audit requirement.

3. Schema foundation:
   - Enumerations and core identity tables first.
   - Role tables and supplier membership before catalog, order, finance, or operations tables.
   - Immutable financial snapshot fields before checkout/order mutations.

4. RLS/security foundation:
   - RLS enabled on every application table from the start.
   - Deny-by-default policies before broad reads.
   - Private table access helpers before UI integration.

5. Audit log and idempotency foundation:
   - `audit_logs` and `idempotency_keys` must exist before sensitive state transitions.
   - Every admin/finance/supplier-stock mutation plan must specify its audit event.

## 4. What Must Not Be Built Yet

Do not build these until their prerequisites are complete and separately approved:

- Phone OTP authentication.
- WhatsApp Business API automation.
- Paystack, Hubtel, card, MoMo, or bank payment integrations.
- Automated payout or withdrawal disbursement.
- Automated MoMo reconciliation.
- Native mobile apps.
- Rider/delivery app.
- Advanced fraud ML or automatic permanent bans.
- Reseller Pro subscriptions.
- Automated refunds.
- Public KYC, proof, payout, or dispute file URLs.
- Generic supplier-to-reseller chat or contact exchange.
- Guest checkout.
- Backend shortcuts that mutate stock, settlement, commission, or payout state without audit logs.

## 5. Clerk Auth Approach

MVP auth uses Clerk with:

- Google/Gmail login.
- Email/password login.
- No phone OTP at MVP.

Phone and WhatsApp numbers are collected as profile, checkout, supplier, and reseller operational data, but they are not authentication factors in MVP.

Implementation order:

1. Add Clerk only after the database profile contract is approved.
2. On first authenticated request, create or resolve a local `profiles` row using `clerk_user_id`, email, and display name.
3. Store role and account status in local tables. Clerk metadata may mirror role for UI convenience, but authorization must read trusted local records.
4. Customers can create accounts before checkout.
5. Resellers can onboard with configurable approval mode, recommended default: low-risk reseller onboarding allowed with admin restriction available.
6. Suppliers can create accounts and draft onboarding data, but supplier workspaces cannot go live before admin approval.
7. Admin, finance, support, and super admin roles must be manually assigned by super admin or approved seed process and audit logged.
8. Phone OTP is a future phase that must add verified contact methods without replacing Clerk email/Google identity.

## 6. Backend Build Phases

### Phase B0: Planning Freeze and Contracts

Goal: freeze backend scope before implementation.

Build only planning artifacts:

- Backend route/action inventory from the frontend coverage matrix.
- Mutation contract list for checkout, confirmation, delivery quote, stock, settlement, commission, withdrawal, support, promotion, and admin operations.
- Status transition map aligned to PRD statuses.
- Seed-data plan for local development only.

Exit gate:

- Product owner confirms open MVP defaults: withdrawal minimum, supplier overdue thresholds, delivery SLA/ownership, launch categories, reseller approval mode, Ghana Card access roles, Pay Online disabled mode.

### Phase B1: Project Backend Architecture Setup

Goal: create safe backend structure without business mutations.

Build:

- Environment variable contract.
- Server-only client boundaries.
- Typed data-access folder structure.
- Error shape and validation conventions.
- Test harness for server utilities.

Do not:

- Connect live Supabase, Resend, storage, payments, or WhatsApp.
- Add migrations before the schema PR is approved.

Exit gate:

- Tests prove server-only modules are not imported by client components.

### Phase B2: Supabase Schema Baseline

Goal: create database shape in the safest dependency order.

Schema order:

1. Platform primitives:
   - extensions, enums, currency/money checks, timestamps, status values.
2. Identity and consent:
   - `profiles`, `profile_consents`, optional contact methods.
3. Role records:
   - `customers`, `resellers`, `admin_staff`.
4. Supplier workspace:
   - `suppliers`, `supplier_staff`, `supplier_staff_invites`, `supplier_verifications`, `supplier_payout_accounts`.
5. Catalog:
   - `product_categories`, `products`, `product_variants`, `product_images`, `product_price_rules`.
6. Inventory:
   - `stock_movements`, `stock_reservations`.
7. Commerce:
   - `carts`, `cart_items`, `orders`, `order_items`, `order_status_events`.
8. Delivery:
   - `delivery_estimates`, `delivery_quotes`, `delivery_quote_events`.
9. Finance:
   - `supplier_settlements`, `supplier_settlement_items`, `settlement_proofs`, `reseller_commissions`, `withdrawals`, `withdrawal_items`, disabled `payment_intents`.
10. Operations:
   - `support_tickets`, `disputes`, `returns`, `refunds`, `risk_scores`, `risk_events`, `restrictions`, `admin_queue_items`.
11. Growth and messaging:
   - `promotions`, `product_insight_snapshots`, `reseller_insight_snapshots`, `whatsapp_templates`, `notification_logs`, `email_logs`.
12. Platform control:
   - `settings`, `idempotency_keys`, `audit_logs`.

Exit gate:

- Schema review proves financial snapshots, stock counters, private storage paths, and audit fields exist before mutations are implemented.

### Phase B3: RLS and Security Baseline

Goal: enforce table isolation before UI integration.

RLS order:

1. Enable RLS on all application tables with default deny.
2. Add profile self-read/update policies for safe fields only.
3. Add role lookup policies through trusted helper functions.
4. Add public approved catalog reads, excluding private supplier and internal pricing fields.
5. Add customer own-data policies.
6. Add reseller own shop/listing/commission/withdrawal policies.
7. Add supplier-owner and supplier-staff workspace policies.
8. Add inventory-manager limited policies.
9. Add finance/support/admin scoped policies.
10. Add super-admin sensitive settings and staff-role policies.
11. Add audit-log read restrictions: admin/super admin only by default.
12. Add storage table ownership checks before creating upload workflows.

Exit gate:

- Security tests prove cross-role reads fail for supplier private contact, KYC paths, payout data, settlements, commissions, customer private data, and audit logs.

### Phase B4: Storage Buckets and File Security

Goal: make upload/read rules safe before any real upload UI is connected.

Bucket plan:

- `product-images`: approved product images may become public-read only after product/image approval; drafts remain supplier/admin scoped.
- `supplier-kyc`: private; supplier owner can upload/read own submitted docs through signed URLs; admin/super admin can review; support and finance denied unless explicitly approved.
- `settlement-proofs`: private; supplier owner uploads own proof; finance/admin/super admin can review.
- `dispute-evidence`: private; order participants see only their own dispute context; assigned support/admin can review.
- `avatars`: public only for approved display images; private while pending moderation if needed.

Storage security order:

1. Create metadata rows before upload signing.
2. Validate owner, role, file category, file size, MIME type, and status.
3. Use short-lived signed URLs for private files.
4. Deny bucket listing for private buckets.
5. Store storage paths, not public URLs, for private evidence.
6. Audit sensitive file review actions.

Exit gate:

- Tests prove unauthenticated/public reads cannot access KYC, settlement proof, payout, or dispute evidence files.

### Phase B5: Read Models and Mock Replacement

Goal: replace static frontend data with safe read-only backend data before enabling mutations.

Build read endpoints/loaders in this order:

1. Public approved shop and product reads.
2. Authenticated customer profile/order reads.
3. Reseller profile, shop, listings, catalog, wallet summary reads.
4. Supplier workspace, products, stock, orders, settlements reads.
5. Admin dashboard, queues, audit, risk, finance reads.

Do not:

- Enable stock-changing, settlement-changing, commission-changing, or approval-changing actions yet.

Exit gate:

- UI can render from backend reads with all role visibility rules intact.

### Phase B6: Catalog, Supplier, Reseller, and Product Mutations

Goal: allow low-risk setup workflows before checkout.

Build:

- Supplier onboarding submission and KYC metadata.
- Reseller onboarding and shop creation.
- Supplier product drafts.
- Product variant creation.
- Product image metadata.
- Product approval requests.
- Admin supplier approval/rejection/more-info.
- Admin product approval/rejection/needs-changes.
- Reseller listing creation and price/margin validation.
- Supplier price change request flow.

Server rules:

- Server calculates reseller cost and final customer price.
- Reseller margin must be within configured limits.
- Product cannot be active without approved supplier, approved product, valid variant stock, and no restriction.
- Supplier price changes cannot mutate existing order snapshots.

Exit gate:

- Tests prove users cannot spoof supplier ID, reseller ID, price, margin, status, or approval decisions.

### Phase B7: Inventory and Atomic Stock Reservation

Goal: protect shared supplier stock before checkout is enabled.

Order/stock reservation plan:

1. Inventory mutations run through controlled server/database functions.
2. Product variants are the stock source of truth.
3. Stock movement rows are append-only.
4. Checkout reservation locks the variant row.
5. Available stock is recalculated as `total_stock_quantity - reserved_stock_quantity - sold_stock_quantity`.
6. Reservation fails if supplier/product/listing/restriction/status/stock checks fail.
7. Order and order item snapshots are created in the same transaction as stock reservation.
8. `reserved_stock_quantity` increments only after the reservation row is inserted.
9. Reservation timeout defaults to 1 hour while awaiting customer confirmation.
10. Expired, cancelled, refused, or unavailable orders release stock through audited logic.
11. Delivered/payment-collected orders convert reserved stock to sold stock.

Exit gate:

- Concurrency tests prove two simultaneous customers cannot buy the last variant.
- Idempotency tests prove retrying checkout does not duplicate orders or reservations.

### Phase B8: Checkout, Order, Confirmation, and Delivery Quote

Goal: enable customer Pay on Delivery ordering safely.

Build:

- Authenticated checkout only. No guest checkout.
- Order creation using trusted reseller listing/product/variant records.
- Price, margin, settlement, and commission snapshots.
- Customer confirmation by account button and email-token path.
- Admin manual confirmation source.
- Delivery estimate selection.
- Delivery quote submission and customer approval/rejection.
- Supplier preparation gated by customer confirmation.

Do not:

- Enable real Pay Online.
- Treat client payment status as proof of payment.

Exit gate:

- Tests prove customer cannot place orders unauthenticated, cannot alter prices, cannot bypass stock reservation, and cannot force supplier preparation before confirmation.

### Phase B9: Supplier Fulfillment and Settlement Ledger

Goal: track Pay on Delivery supplier obligations.

Supplier settlement ledger plan:

1. Settlement due amount per order item equals `platform_margin_snapshot_amount + reseller_margin_snapshot_amount`.
2. Create settlement obligation after delivered/payment-collected event or approved operational trigger.
3. Group settlement by supplier/order where practical, with item-level details retained.
4. Support partial settlement by tracking due, paid, and outstanding amounts.
5. Supplier uploads proof metadata and private file path.
6. Finance/admin reviews proof.
7. Verified payment reduces outstanding amount.
8. Rejected proof keeps settlement outstanding and creates queue/risk event.
9. Overdue settlement creates queue item and may trigger warning, hidden products, new-order block, restriction, or suspension based on configured thresholds.

Exit gate:

- Tests prove supplier cannot verify own settlement, cannot read other suppliers' settlements, and cannot boost products while overdue.

### Phase B10: Reseller Commission and Withdrawal Lifecycle

Goal: protect reseller earnings without premature payout automation.

Reseller commission lifecycle plan:

1. Commission row is created from order item snapshot at order creation.
2. Initial state: pending/awaiting customer confirmation.
3. After confirmation/fulfillment: awaiting delivery/payment.
4. After payment collected: awaiting supplier settlement.
5. After settlement verified: available.
6. During dispute/refund/return: held or disputed.
7. If order cancelled/refused: cancelled.
8. Withdrawal request can include available commissions only.
9. Withdrawal processing remains manual/admin or finance controlled.
10. Paid withdrawal marks related commissions paid.
11. Failed/rejected withdrawal returns commissions to available through audited logic.

Exit gate:

- Tests prove pending, held, disputed, cancelled, and awaiting-settlement commissions cannot be withdrawn.

### Phase B11: Admin Operations Mutations

Goal: turn admin queues into audited state transitions.

Admin operations mutation plan:

- Every mutation requires authenticated admin/finance/support/super-admin role as appropriate.
- Every sensitive mutation requires reason/note where the frontend already shows a reason field or manual override warning.
- Every mutation writes `audit_logs`.
- Every queue action is idempotent and records old/new status.
- Permission groups:
  - Operations: order status, delivery quote coordination, queue assignment.
  - Catalog: product/category approvals.
  - Finance: settlement verification, commission release, withdrawal handling.
  - Risk: restrictions, suspensions, risk review.
  - Support: assigned tickets/disputes only.
  - Super admin: staff permissions, sensitive settings, exceptional overrides.

Mutation order:

1. Queue assignment and notes.
2. Customer confirmation follow-up/manual confirmation.
3. Delivery quote operations.
4. Supplier/product approval decisions.
5. Settlement proof review.
6. Commission release after verified settlement.
7. Withdrawal approval/rejection/paid/failed.
8. Dispute/return/refund status decisions.
9. Risk restrictions/suspensions.
10. Manual overrides last, after all normal flows exist.

Exit gate:

- Tests prove admin mutations fail without proper role and always create audit logs.

### Phase B12: Resend Notifications and Manual WhatsApp Templates

Goal: add messaging after the source events are reliable.

Resend notification plan:

1. Add `notification_logs` and `email_logs` writes before real sending.
2. Build templates for approved events only:
   - account welcome/approval/rejection
   - customer order received
   - customer confirmation reminder
   - order confirmed/cancelled/dispatched/delivered
   - delivery quote ready
   - reseller new order/commission pending/commission available/withdrawal status
   - supplier confirmed order/product decision/settlement due/settlement overdue/proof review
   - admin queue alerts for critical failures only
   - dispute/support updates
3. Validate role-specific redaction before sending.
4. Send only after event transaction succeeds.
5. Record provider message status and failures.
6. Create admin queue items for business-critical email failures only.

Manual WhatsApp plan:

- Generate copyable templates only.
- Log template generation, not delivery.
- Redact private supplier contact, KYC, payout, settlement proof links, internal margins, and unrelated customer data.
- Do not add WhatsApp Business API automation in MVP.

Exit gate:

- Tests prove email payloads do not leak supplier private contact, KYC paths, payout details, supplier base price to customers, or reseller margin strategy to suppliers.

### Phase B13: Support, Disputes, Returns, Refund Tracking

Goal: persist support operations while keeping refunds manual at MVP.

Build:

- Support tickets.
- Disputes tied to orders where possible.
- Evidence metadata and private files.
- Return request and category eligibility status.
- Refund tracking records for manual Pay on Delivery cases.
- Commission and settlement holds during active disputes.
- Admin/support resolution with audit logs.

Exit gate:

- Tests prove support staff can only access assigned/safe context and cannot view KYC, payout, or unrelated finance data.

### Phase B14: Promotions, Insights, and Risk Restrictions

Goal: enable promotions without weakening trust rules.

Build:

- Supplier boost request.
- Manual payment proof metadata.
- Admin promotion approval/rejection/pause.
- Sponsored/featured read model.
- Basic product insight snapshots.
- Eligibility checks:
  - supplier approved and active
  - product approved and active
  - stock available
  - no overdue settlement restriction
  - product not suspended/restricted
  - complaint/risk acceptable

Exit gate:

- Tests prove overdue/restricted suppliers cannot start active promotions and out-of-stock products are not recommended as sellable.

### Phase B15: Launch Hardening and Security QA

Goal: prove the backend resists the known failure modes.

Required verification:

- Authenticated and unauthenticated access tests.
- RLS cross-role access tests.
- Price tampering tests.
- Margin limit tests.
- Concurrent checkout/last-stock tests.
- Idempotent checkout retry tests.
- Reservation expiry/release tests.
- Settlement verification and commission release tests.
- Withdrawal availability tests.
- Storage private access tests.
- Audit log coverage tests.
- Notification redaction tests.
- Admin permission separation tests.
- Build, typecheck, lint, unit, integration, and security regression suite.

Exit gate:

- No MVP launch until stock, price, settlement, commission, storage, and admin audit tests pass.

## 7. Audit Log Plan

Audit logs must be available before sensitive state changes. Each event stores actor profile, actor role, action, entity type, entity ID, before data, after data, reason/note, timestamp, request ID, IP/user-agent where available, and safe metadata.

Audit these actions first:

- Role or account status changes.
- Supplier approval/rejection/more-info/suspension.
- KYC review.
- Payout account changes.
- Product approval/rejection/hide/suspend/archive.
- Product price/margin changes.
- Stock adjustment, restock, reservation, release, sale conversion.
- Order status changes.
- Customer confirmation source changes.
- Delivery quote approval/rejection.
- Supplier payment-received mark.
- Settlement proof submission/review/verification/rejection.
- Commission release/hold/adjustment.
- Withdrawal approval/rejection/payment/failure.
- Dispute/return/refund resolution.
- Promotion approval/pause/rejection.
- Risk restriction/suspension.
- Manual override.
- Admin settings changes.

Never store raw passwords, private keys, API keys, full Ghana Card numbers, unmasked payout account numbers, or public URLs for private files in audit logs.

## 8. Test Plan

Test order:

1. Static/type/lint tests for server-only boundaries.
2. Schema integrity tests for constraints and immutable snapshots.
3. RLS tests by role and table group.
4. Storage policy tests.
5. Unit tests for price, margin, commission, settlement, risk, and status transition helpers.
6. Transaction tests for checkout and stock reservation.
7. Concurrency tests for last-stock variant ordering.
8. Idempotency tests for checkout, confirmation, settlement proof, settlement verification, withdrawal request, and future webhooks.
9. Mutation authorization tests.
10. Audit log coverage tests.
11. Notification redaction and logging tests.
12. End-to-end route tests after mock replacement.
13. Launch smoke tests for customer, reseller, supplier, inventory manager, admin, finance, and support roles.

Minimum acceptance:

- `npm test` passes.
- `npm run typecheck` passes.
- `npm run lint` passes.
- `npm run build` passes.
- Security tests prove no cross-role leaks for private data.
- Race-condition tests prove stock cannot be oversold.

## 9. Risk List

Highest risks:

- Stock overselling if reservation is not database-transactional.
- Price or commission manipulation if frontend values are trusted.
- Supplier settlement leakage or failure to restrict overdue suppliers.
- Reseller commission released before settlement verification.
- KYC/proof/evidence storage accidentally public.
- Admin mutation without audit log.
- Support/finance role overexposure.
- Pay Online placeholder accidentally treated as live payment.
- Resend emails leaking internal pricing or private contact details.
- Supplier/reseller/customer ID spoofing in mutations.
- Idempotency gaps causing duplicate orders, duplicate reservations, duplicate settlement verification, or duplicate withdrawals.
- Existing frontend mock actions being connected directly without server validation.
- Running `npm audit fix --force` blindly and introducing breaking dependency changes.

Mitigations:

- Build server/database functions for sensitive transitions.
- Use RLS from the beginning.
- Require audit rows in tests for sensitive mutations.
- Add concurrency tests before checkout launch.
- Keep payment and WhatsApp automation out of MVP.
- Gate every merge on the commands listed in this plan.

## 10. Exact Recommended Merge Order for Other Agents

Merge only after each PR passes tests and review. Later PRs should be based on the latest merged main.

1. Agent 1: Backend Phase 0 master plan and decision checklist.
2. Agent 2: Backend architecture skeleton, env contract, server-only boundaries, validation/error conventions.
3. Agent 3: Supabase schema PR 1: identity, roles, supplier workspace, admin staff, settings, audit, idempotency.
4. Agent 4: Supabase schema PR 2: catalog, variants, images, price rules, inventory, stock movements, stock reservations.
5. Agent 5: Supabase schema PR 3: carts, orders, order items, delivery, settlement, commission, withdrawal, support, risk, promotions, notification logs.
6. Agent 6: RLS PR 1: profiles, customers, resellers, suppliers, supplier staff, admin staff.
7. Agent 7: RLS PR 2: catalog, inventory, reservations, orders, finance, operations, audit logs.
8. Agent 8: Storage security PR: bucket definitions, metadata ownership checks, signed URL policy plan, tests.
9. Agent 9: Clerk auth/profile mapping PR with Google/email/password only and no phone OTP.
10. Agent 10: Read-model PR 1: public shop/product/catalog and role-safe product visibility.
11. Agent 11: Read-model PR 2: reseller, supplier, customer, and admin dashboards replacing mock reads.
12. Agent 12: Catalog/setup mutation PR: onboarding, shops, supplier products, variants, product approval, reseller listings.
13. Agent 13: Inventory mutation PR: restock, stock adjustment, movements, price change requests, audit logs.
14. Agent 14: Atomic checkout/reservation PR with concurrency and idempotency tests.
15. Agent 15: Customer confirmation and delivery quote PR.
16. Agent 16: Supplier fulfillment and Pay on Delivery payment-collected tracking PR.
17. Agent 17: Supplier settlement ledger and proof metadata PR.
18. Agent 18: Finance/admin settlement verification PR.
19. Agent 19: Reseller commission lifecycle PR.
20. Agent 20: Manual withdrawal request and admin/finance withdrawal handling PR.
21. Agent 21: Admin operations queue mutation PR.
22. Agent 22: Audit coverage hardening PR across all sensitive transitions.
23. Agent 23: Resend notification logging and sending PR with redaction tests.
24. Agent 24: Manual WhatsApp template generation PR, no WhatsApp API.
25. Agent 25: Support/disputes/returns/refunds persistence PR.
26. Agent 26: Promotions/insights/risk restriction PR.
27. Agent 27: Full backend security QA and launch hardening PR.

Do not merge payment-provider work, phone OTP, WhatsApp Business API, automated payouts, or native app work into this sequence.

## 11. Current Frontend Mapping

Frontend coverage is complete for backend planning and currently mock-only. Backend agents should replace these mock domains in order:

1. Design system and preview stay internal/static.
2. Public shop and checkout reads.
3. Customer account, order, confirmation, delivery quote, support reads/mutations.
4. Reseller onboarding, catalog, listing, shop, wallet, support reads/mutations.
5. Supplier onboarding, products, inventory, settlements, finance, promotions, team reads/mutations.
6. Admin dashboard, operations, risk, audit, finance, support reads/mutations.
7. Edge cases should become real error/empty/permission states after backend validation exists.

## 12. Final Recommendation

The safest next step is to keep this repository planning-only until the backend decision checklist is approved, then assign separate agents according to the merge order above. The first implementation PR should be architecture and contracts, not database migrations or external service connections.
