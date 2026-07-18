# Customer Account + Checkout Backend Phase Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build customer account, checkout draft, order creation, stock reservation, and Pay on Delivery backend support without trusting browser-sent pricing or connecting online payments.

**Architecture:** Use forward Supabase migrations with audited `SECURITY DEFINER` RPCs for customer account, checkout draft, order placement, stock reservation, confirmation, and delivery quote transitions. Keep UI calls behind server actions/user-context Supabase clients, and keep checkout/order/payment/delivery integrations staged so each phase can pass boundary tests before browser wiring.

**Tech Stack:** Next.js App Router, Clerk auth, Supabase/Postgres, PL/pgSQL RPCs, RLS, Vitest, development-only SQL boundary tests.

## Global Constraints

- Do NOT connect checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow to live Supabase data until the specific phase is approved.
- Do NOT connect production Supabase.
- Do NOT use production data.
- Do NOT apply migrations without explicit approval.
- Do NOT run destructive reset commands.
- Do NOT print secrets.
- Do NOT commit `.env.local`.
- Do NOT weaken RLS/RPC/storage policies.
- Do NOT run `npm audit fix --force`.
- Customer must not send trusted price from browser.
- Server/RPC must calculate final price from approved listing.
- Product/listing must be active and approved.
- Archived/rejected/pending listings cannot be bought.
- No order should be created for unavailable listing.
- Stock reservation must be atomic.
- Customer checkout must not create commission immediately.
- Commission becomes pending only after valid order/payment/settlement rules later.
- Supplier settlement must remain separate.
- Pay on Delivery remains primary.
- Online payment remains deferred.
- Customer must not see supplier base/private price if not public-safe.
- Reseller margin/platform math must be server-controlled.
- Audit logs are required for sensitive transitions.

---

## A. Recommended Build Order

### Phase A: Customer Profile and Address Foundation

Goal: let signed-in customers create or update customer account/contact/address records without creating an order.

Recommended deliverables:

- Forward migration for customer profile helpers if current `customers.default_address` is not enough.
- `public.get_current_customer_account()`.
- `public.upsert_customer_account(p_phone text, p_whatsapp text, p_default_address jsonb)`.
- Development-only RPC boundary test: customer can create/read own customer row; other users cannot read/update it; admin/support visibility remains scoped.
- Server action/helper for checkout account page after RPC test passes.

No order, stock reservation, payment, delivery quote, commission, settlement, or withdrawal side effect.

### Phase B: Cart or Checkout Draft

Goal: persist a customer checkout draft from a public listing without reserving stock.

Recommended deliverables:

- New table such as `public.checkout_drafts`.
- Draft stores customer, reseller shop/listing, product, variant, quantity, delivery estimate choice, customer contact/address snapshot, and server-calculated display snapshot.
- `public.create_or_update_checkout_draft(p_listing_share_slug text, p_quantity int, p_variant_id uuid, p_delivery_details jsonb)`.
- `public.get_checkout_draft(p_checkout_draft_id uuid)`.
- Boundary tests prove server recalculates final customer price from active approved listing and blocks inactive/unapproved/deleted listing/product/supplier/shop states.

No stock reservation yet unless Phase C/D is explicitly combined later.

### Phase C: Order Creation With Snapshot

Goal: create a durable order and order item snapshot from a valid checkout draft or listing, still without online payment.

Recommended deliverables:

- `public.create_pay_on_delivery_order_from_draft(p_checkout_draft_id uuid)`.
- Server-calculated order number.
- Order status starts as `placed_pending_confirmation`.
- Customer confirmation status starts as `pending`.
- Payment method fixed to `pay_on_delivery`.
- Payment collection status fixed to `not_collected`.
- Delivery status starts as `estimate_selected` or `quote_pending`.
- Order item stores supplier base price, platform margin, reseller margin, reseller cost, customer product price, settlement due, and commission snapshot.
- Audit log for order creation.

Do not create commission rows as available. If commission rows are needed for visibility, status must be `pending_order` or `awaiting_customer_confirmation`, not withdrawable.

### Phase D: Atomic Stock Reservation

Goal: prevent overselling shared supplier stock across many reseller links.

Recommended deliverables:

- Atomic reservation RPC, preferably one transaction that locks the selected `product_variants` row with `for update`.
- `public.reserve_stock_for_order(p_order_id uuid)` or integrated internal helper used by Phase C order creation.
- Reservation expiry, recommended default: 1 hour.
- Reservation status: `reserved` on success, `failed` or no order on failure depending final design.
- Inventory movement with `reservation_created`.
- Boundary tests simulate quantity > available, inactive variant, expired reservations, and concurrent-style double-reservation logic.

No payment, settlement, or commission release side effect.

### Phase E: Pay on Delivery Workflow

Goal: progress confirmed orders through customer confirmation and delivery quote approval without online payment.

Recommended deliverables:

- `public.confirm_customer_order(p_order_id uuid)`.
- `public.cancel_unconfirmed_order(p_order_id uuid, p_reason text)`.
- `public.approve_delivery_quote(p_delivery_quote_id uuid)`.
- `public.reject_delivery_quote(p_delivery_quote_id uuid, p_reason text)`.
- Admin/support/supplier quote creation remains separate from customer approval.
- Audit logs for customer confirmation, cancellation, quote approval, quote rejection.

No online payment provider integration.

### Phase F: Later Payment Provider Integration

Goal: defer Paystack/Hubtel/other payment integration until Pay on Delivery order/reservation lifecycle is proven.

Deferred deliverables:

- payment provider tables
- webhook verification
- provider reference storage
- server-side payment reconciliation
- automated split/settlement logic

Do not fake client-side payment success.

## B. Tables Already Available

Existing foundation tables from `20260717000000_risellar_schema_rls_foundation.sql`:

- `profiles`
- `customers`
- `resellers`
- `reseller_shops`
- `suppliers`
- `products`
- `product_variants`
- `product_images`
- `inventory_movements`
- `reseller_products`
- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `settlements`
- `commissions`
- `withdrawals`
- `disputes`
- `returns`
- `notifications`
- `audit_logs`
- `admin_actions`

Existing helper functions include:

- `jwt_subject()`
- `current_profile_id()`
- `has_admin_role(required_role)`
- `is_customer_owner(target_customer_id)`
- `is_reseller_owner(target_reseller_id)`
- `is_supplier_member(target_supplier_id)`
- `is_order_participant(target_order_id)`

Existing public read-only shop RPCs:

- `get_public_reseller_shop(p_shop_slug text)`
- `get_public_reseller_shop_product(p_shop_slug text, p_product_slug text)`

Existing reseller listing RPCs:

- `create_reseller_product_listing(p_product_id uuid, p_reseller_margin numeric)`
- `update_reseller_product_listing(p_listing_id uuid, p_reseller_margin numeric, p_listing_status text)`
- `archive_reseller_product_listing(p_listing_id uuid)`

## C. Tables/Migrations Likely Needed

### Phase A

Current `customers.default_address jsonb` can support MVP if speed matters. If structured address history is required, add:

- `customer_addresses`
  - `id uuid primary key`
  - `customer_id uuid references customers(id)`
  - `label text`
  - `phone text`
  - `whatsapp text`
  - `region text`
  - `city text`
  - `area text`
  - `address_line text`
  - `landmark text`
  - `delivery_notes text`
  - `is_default boolean`
  - `created_at/updated_at/deleted_at`

Recommendation: start with `customers.default_address` for Phase A unless multiple saved addresses are required immediately.

### Phase B

Add `checkout_drafts`:

- `id uuid primary key`
- `customer_id uuid not null references customers(id)`
- `reseller_id uuid not null references resellers(id)`
- `shop_id uuid not null references reseller_shops(id)`
- `reseller_product_id uuid not null references reseller_products(id)`
- `product_id uuid not null references products(id)`
- `variant_id uuid references product_variants(id)`
- `quantity integer not null`
- `draft_status text not null default 'active'`
- `customer_contact_snapshot jsonb not null`
- `delivery_address_snapshot jsonb not null`
- `delivery_estimate_snapshot jsonb not null default '{}'::jsonb`
- `public_listing_snapshot jsonb not null default '{}'::jsonb`
- `expires_at timestamptz`
- `created_at/updated_at/deleted_at`

### Phase C/D

Existing `orders`, `order_items`, and `stock_reservations` are available. Phase C/D likely needs:

- unique order number generator function
- optional `orders.checkout_draft_id` if traceability from draft is needed
- optional `stock_reservations.confirmed_at` if `committed_at` is not sufficient
- optional indexes for active reservations by variant/product/listing

Avoid broad schema churn until RPC boundary tests prove the minimum needed columns.

## D. RPCs/Server Actions Likely Needed

### RPCs

- `get_current_customer_account()`
- `upsert_customer_account(p_phone text, p_whatsapp text, p_default_address jsonb)`
- `create_or_update_checkout_draft(p_shop_slug text, p_listing_slug text, p_variant_id uuid, p_quantity int, p_contact jsonb, p_delivery_address jsonb, p_delivery_option text)`
- `get_checkout_draft(p_checkout_draft_id uuid)`
- `create_pay_on_delivery_order_from_draft(p_checkout_draft_id uuid)`
- `confirm_customer_order(p_order_id uuid)`
- `cancel_unconfirmed_order(p_order_id uuid, p_reason text)`
- `approve_delivery_quote(p_delivery_quote_id uuid)`
- `reject_delivery_quote(p_delivery_quote_id uuid, p_reason text)`

### Server Actions

Keep user-facing submissions in server-only modules:

- `app/checkout/account/actions.ts`
- `app/checkout/delivery/actions.ts`
- `app/checkout/review/actions.ts`
- `app/customer/orders/[id]/confirm/actions.ts`
- `app/customer/orders/[id]/delivery-quote/actions.ts`

All server actions should:

- require Clerk auth
- call `getToken()` with native Clerk/Supabase auth
- use `createSupabaseUserServerClient(accessToken)`
- never import service role
- never accept trusted price, margin, reseller id, supplier id, commission, or platform amount from the client

## E. RLS/Security Requirements

- Customers can select/update only their own `customers` row/address data.
- Customers can create checkout drafts only for themselves.
- Customers can read only their own drafts/orders/delivery quote state.
- Public shop read remains anon-safe and read-only.
- Order creation must be through RPC, not direct client table insert.
- `order_items` insert should remain blocked from customers directly.
- `stock_reservations` insert should remain RPC/admin-only.
- Supplier/reseller/admin views of orders remain participant-scoped.
- Admin/support staff access continues through `admin_staff`, not `profiles.primary_role = 'admin'`.
- All sensitive transitions write audit logs.
- No RLS policy should use broad `using (true)` / `with check (true)` for write paths.

## F. Pricing Snapshot Rules

The browser may send:

- listing slug/share slug
- variant id
- quantity
- selected delivery option id
- customer contact/address fields

The browser must not send trusted:

- final customer price
- supplier base price
- platform margin
- reseller margin
- reseller cost
- commission amount
- settlement due amount
- reseller id
- supplier id

The RPC must calculate:

- `supplier_base_price_snapshot_amount = products.base_price_amount`
- `platform_margin_snapshot_amount = products.platform_margin_amount`
- `reseller_margin_snapshot_amount = reseller_products.reseller_margin_amount`
- `reseller_cost_snapshot_amount = products.reseller_cost_amount`
- `customer_product_price_snapshot_amount = reseller_products.customer_product_price_amount`
- `line_total_amount = quantity * customer_product_price_snapshot_amount`
- `settlement_due_amount = platform_margin_snapshot_amount + reseller_margin_snapshot_amount`
- `commission_amount = reseller_margin_snapshot_amount`

Before snapshotting, RPC must require:

- reseller shop active and non-deleted
- reseller active/approved and non-deleted
- reseller listing active and non-deleted
- supplier active/approved and non-deleted
- product active/approved and non-deleted
- variant active/low_stock and non-deleted
- requested quantity positive

## G. Stock Reservation Rules

Reservation must be inside a single database transaction.

Required algorithm:

1. Resolve order/listing/product/variant under RPC.
2. Lock `product_variants` row with `for update`.
3. Compute available stock:
   - `total_stock_quantity - reserved_stock_quantity - sold_stock_quantity`
4. If available stock is less than requested quantity:
   - fail clearly with `INSUFFICIENT_STOCK`
   - do not create or commit partial order/reservation data, unless the order is explicitly saved as failed/draft.
5. Increment `reserved_stock_quantity`.
6. Insert `stock_reservations` with `reservation_status = 'reserved'`.
7. Insert `inventory_movements` with `movement_type = 'reservation_created'`.
8. Set `expires_at = now() + interval '1 hour'`.
9. Audit the reservation.

Release/expiry later must:

- lock the same variant row
- decrement reserved quantity safely
- mark reservation `expired` or `released`
- insert movement `reservation_released` or `order_cancelled_release`
- audit the transition

## H. Delivery Quote Rules

Phase B/C can store delivery estimate snapshots.

Final quote workflow should remain separate:

- Admin/support/supplier member creates a delivery quote only after order exists.
- Customer can approve/reject only quotes attached to their own order.
- Quote approval updates order delivery quote status and final delivery amount.
- Quote rejection can cancel order before dispatch or return to quote-pending, depending future operations decision.
- Customer cannot set final delivery amount directly.

## I. Pay on Delivery Rules

Immediate MVP:

- `payment_method = 'pay_on_delivery'`
- `payment_collection_status = 'not_collected'`
- customer pays on delivery later
- supplier payment received mark and settlement proof remain later phases
- no online payment provider or webhook

Order lifecycle starts:

- `placed_pending_confirmation`
- `customer_confirmation_status = 'pending'`
- supplier preparation blocked until confirmation

After customer confirmation:

- `order_status = 'customer_confirmed'`
- `customer_confirmation_status = 'confirmed'`
- `confirmed_at = now()`
- keep reservation active
- audit confirmation

## J. What Remains Deferred

Deferred until later explicit approval:

- live checkout UI connecting to order creation
- online payment provider integration
- payment webhooks
- payment tables/provider references
- supplier fulfillment actions
- supplier payment received actions
- settlement proof and settlement verification
- commission availability/release
- reseller withdrawals
- delivery provider/rider integration
- WhatsApp Business API automation
- email send automation beyond notification planning

## K. Test Plan

### SQL Boundary Tests

Create development-only scripts in `scripts/rpc/`:

- `customer-account-rpc-tests-dev-only.sql`
- `checkout-draft-rpc-tests-dev-only.sql`
- `checkout-order-rpc-tests-dev-only.sql`
- `stock-reservation-rpc-tests-dev-only.sql`
- `pay-on-delivery-rpc-tests-dev-only.sql`

Required assertions:

- unauthenticated user cannot create customer account/draft/order
- customer can create/read own customer account
- one customer cannot read/update another customer's account/draft/order
- public listing RPC remains read-only
- customer cannot submit trusted price/margin fields
- server-calculated price snapshot matches approved listing
- pending/rejected/archived/deleted listing/product/supplier states are blocked
- quantity must be positive
- insufficient stock blocks order/reservation
- reservation updates variant stock atomically
- customer cannot confirm another customer's order
- delivery quote approval is customer-owner-only
- audit logs exist for order/reservation/confirmation/quote transitions
- no commission becomes available at order creation
- no settlement is created until settlement phase

### App Tests

Add/update Vitest coverage:

- server action requires auth
- server action uses `getToken()` native Clerk/Supabase token
- no service role imported in checkout/customer components
- customer forms do not expose hidden trusted price/margin inputs
- checkout review renders server-returned snapshot only
- Pay Online remains disabled/deferred
- place-order action handles `INSUFFICIENT_STOCK`, `UNAVAILABLE_LISTING`, and duplicate/expired draft errors clearly

## L. Manual QA Plan

Run manually only after each backend boundary script passes:

1. Sign in with development customer test account.
2. Visit `/auth/qa-profile-sync`.
3. Visit public shop/product page as customer.
4. Start checkout from active approved listing only after checkout UI is explicitly connected.
5. Save customer phone/WhatsApp/address.
6. Create checkout draft.
7. Verify draft snapshot in development Supabase without printing secrets.
8. Place Pay on Delivery order.
9. Verify order, order item, and stock reservation rows.
10. Verify price snapshot fields.
11. Verify unavailable listing/insufficient stock errors.
12. Confirm order.
13. Verify customer cannot access another order.
14. Verify no online payment, settlement, commission release, or withdrawal side effect.

## M. Risks and Blockers

- Existing checkout/customer pages are mock UI and currently import mock data from `components/customer/screens.tsx`.
- Existing schema has `customers.default_address jsonb`, but multiple address management may need `customer_addresses`.
- Direct `orders_insert_customer_or_admin` RLS exists, but checkout must use RPC to avoid browser-sent price/snapshot tampering.
- Direct `order_items_insert_admin_only` and `stock_reservations_insert_admin_only_until_rpc` are correctly restrictive; RPCs must handle inserts safely.
- Atomic reservation needs explicit lock strategy and boundary tests; do not implement stock reservation only in app code.
- Order creation and stock reservation transaction boundary must be decided before implementation: either one all-or-nothing RPC or draft/order/reservation split with safe failure cleanup.
- Pay on Delivery means settlement and commission remain operationally sensitive; do not mark commission available early.
- Delivery ownership/SLA and exact delivery estimate options need business confirmation before production launch.

## N. Exact Recommended Next Implementation Prompt

Use this prompt to start Phase A safely:

```text
You are working on Risellar.

Task: Customer Account Phase A backend foundation.

Do NOT connect checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow to live Supabase data.
Do NOT connect production Supabase.
Do NOT use production data.
Do NOT apply migrations without explicit approval.
Do NOT run destructive reset commands.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS/RPC/storage policies.
Do NOT run npm audit fix --force.

Context:
- Public reseller shop read-only browsing works.
- Customer checkout pages are still mock-only.
- Current schema already has public.customers with default_address jsonb.
- This phase must create customer account/contact/address backend only.

Goal:
Create a forward migration and development-only tests for customer profile/contact/address RPCs.

Scope:
- get_current_customer_account()
- upsert_customer_account(p_phone text, p_whatsapp text, p_default_address jsonb)
- no order creation
- no checkout draft
- no stock reservation
- no payment
- no delivery quote
- no commission/settlement/withdrawal

Requirements:
1. Use Clerk/Supabase native user-context auth.
2. Customer can create/find only their own customer row.
3. Customer can update own phone/WhatsApp/default_address.
4. Customer cannot assign roles.
5. Customer cannot update another customer.
6. Admin/support read behavior must follow existing admin_staff access rules.
7. Keep service role out of app/components.
8. Add scripts/rpc/customer-account-rpc-tests-dev-only.sql.
9. Run npx supabase db push --dry-run only.
10. Do not run real db push.

Verification:
Run git status --short, git diff --check, npm test, npm run lint, npm run build, npm run typecheck.
Run secret/scope scan.

Create docs/RISELLAR_CUSTOMER_ACCOUNT_PHASE_A_FOUNDATION_REPORT.md.
Do not commit unless asked.
```

