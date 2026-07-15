# Risellar Database Schema and Security Plan

## 1. Document Purpose

This document plans Risellar's database and security foundation before migrations, Supabase tables, RLS policies, backend code, or UI are created. It is the source of truth for future schema design, RLS policy generation, server-side database functions, storage bucket policies, audit requirements, QA/security tests, backend service-layer boundaries, and typed data access patterns.

The goal is to protect Risellar's controlled Ghana reseller marketplace model: Supplier -> Risellar/Admin -> Reseller -> Customer.

## 2. Source Documents Reviewed

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`: confirms PWA/web platform direction, role-specific surfaces, GH₵ financial transparency, settlement/risk visibility, and no native mobile implementation.
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`: confirms the reference images are UI guidance only and that reseller, supplier, checkout, and admin surfaces have distinct operational needs.
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`: confirms strengthened non-negotiables around PWA direction, admin density, financial breakdowns, settlement states, risk states, and Pay on Delivery trust.
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`: defines pricing, stock reservation, settlement, commission, risk, notification, WhatsApp helper, support, audit, and MVP boundaries.
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC_REPORT.md`: summarizes business-rule decisions and remaining questions.
- `docs/RISELLAR_FULL_PRD.md`: defines the product requirements, roles, user journeys, high-level data objects, acceptance criteria, and implementation phases.
- `docs/RISELLAR_FULL_PRD_REPORT.md`: summarizes PRD scope, assumptions, and the recommended schema/RLS planning step.

## 3. Architecture Assumptions

- Frontend: Next.js App Router, TypeScript, Tailwind CSS, PWA/mobile-first for reseller and supplier, mobile web checkout for customer, desktop web dashboard for admin.
- Auth: Clerk Google/email authentication. Phone/WhatsApp numbers are collected but not OTP-verified in MVP.
- Database: Supabase Postgres with RLS enabled on all application tables.
- Storage: Supabase Storage for product images and private files such as Ghana Card/KYC, settlement proofs, and dispute evidence.
- Email: Resend for transactional email and email event logs.
- WhatsApp: manual helper templates only in MVP. No WhatsApp Business API automation.
- Payments: Pay on Delivery is default. Pay Online is a disabled/placeholder model until Paystack, Hubtel, or another real provider is selected.
- Delivery: no rider app in MVP. Delivery is supplier/admin/customer coordinated and represented by estimates, quotes, statuses, and notes.

## 4. Security Principles

- Enable RLS on every application table.
- Never trust frontend-sent prices, margins, roles, `supplier_id`, `reseller_id`, settlement amounts, commission amounts, or stock quantities.
- Use server-side logic or secure Postgres functions for sensitive calculations and state transitions.
- Keep the Supabase service role key server-only and never expose it to browser/PWA clients.
- Store price and margin snapshots on order items so existing orders cannot be changed by later product, margin, or listing edits.
- Make stock reservation atomic and database-safe.
- Keep supplier private data away from customers and resellers.
- Keep customer private contact details away from suppliers except operational fields explicitly required to fulfill an order.
- Audit every sensitive action with actor, role, target, before/after data, reason, and request context where available.

## 5. Data Ownership Model

- Customer-owned data: profile, addresses, cart, own orders, own disputes, own support tickets, own notification preferences.
- Reseller-owned data: reseller profile, shop, listings, share links, attributed orders, commissions, withdrawals, promotions submitted by reseller if added later.
- Supplier-owned data: supplier workspace, staff, products, variants, stock movements, fulfillment records, settlement proofs, payout account metadata.
- Admin-owned data: approvals, risk decisions, restrictions, queue assignment, settlement verification, overrides, platform settings, audit review.
- Platform-owned data: margins, status transitions, price snapshots, stock reservations, commission ledger, settlement ledger, risk scores, notification logs, audit logs.

## 6. Role and Permission Model

Core roles:

- `customer`: buys through reseller shops/links, confirms orders, approves delivery quotes, tracks orders, opens disputes.
- `reseller`: browses approved products, adds listings to shop, sets allowed reseller margin, shares links, views commissions, requests withdrawals.
- `supplier_owner`: owns a supplier workspace, manages products, stock, staff, payout details, fulfillment, settlement proof.
- `inventory_manager`: supplier staff role for product, stock, variant, and order-preparation work only.
- `support_staff`: future/limited admin role for support and dispute follow-up without finance authority.
- `finance_staff`: verifies settlements and handles withdrawals without broad system settings access.
- `admin`: manages operations, approvals, queues, disputes, settlements, commissions, restrictions, and risk.
- `super_admin`: manages staff roles, sensitive settings, manual overrides, and all admin privileges.

Permissions must be enforced in RLS and server logic, not only in UI.

## 7. Authentication and Clerk Mapping

Use a local `profiles` table keyed by an internal UUID with a unique `clerk_user_id`.

Recommended fields:

- `id uuid primary key`
- `clerk_user_id text unique not null`
- `email text not null`
- `full_name text`
- `phone text`
- `whatsapp text`
- `primary_role user_role not null`
- `account_status account_status not null default 'active'`
- `created_at`, `updated_at`, `last_seen_at`

Clerk session identity should map to the local profile through a secure helper. Role claims in Clerk metadata may be cached for convenience, but database authorization must resolve against trusted local tables. Admin role assignment must be manual and audited.

## 8. Schema Naming Conventions

- Use lowercase snake_case table and column names.
- Use plural table names.
- Use `id uuid primary key default gen_random_uuid()` for most entities.
- Use `created_at`, `updated_at`, `deleted_at` for lifecycle timestamps.
- Use `created_by_profile_id`, `updated_by_profile_id`, `approved_by_profile_id`, and `verified_by_profile_id` for action attribution.
- Use `_status` suffix for enum statuses.
- Use `_amount` suffix for monetary numeric values.
- Store currency as `currency_code text default 'GHS'`.
- Store money as `numeric(12,2)` with non-negative checks.
- Use soft deletion where audit or ledger history matters.

## 9. Core Entity Relationship Overview

At a high level:

- `profiles` connect to role-specific records: `customers`, `resellers`, `supplier_staff`, `admin_staff`.
- `suppliers` own `products`, `product_variants`, `stock_movements`, and `supplier_settlements`.
- `resellers` own `reseller_shops`, `reseller_listings`, `commissions`, and `withdrawals`.
- `customers` own `carts`, `orders`, `delivery_addresses`, and disputes.
- `orders` contain `order_items`, each linked to a product variant, supplier, reseller listing, reseller, customer, settlement, commission, and stock reservation snapshot.
- `stock_reservations` protect product variants during checkout and customer confirmation.
- `admin_queue_items`, `risk_events`, `restrictions`, and `audit_logs` track operational control.

## 10. Table Groups Overview

- Identity: `profiles`, `customers`, `resellers`, `admin_staff`.
- Supplier workspace: `suppliers`, `supplier_staff`, `supplier_staff_invites`, `supplier_verifications`, `supplier_payout_accounts`.
- Catalog: `products`, `product_variants`, `product_images`, `product_categories`, `product_price_rules`.
- Inventory: `stock_movements`, `stock_reservations`.
- Commerce: `carts`, `cart_items`, `orders`, `order_items`, `order_status_events`.
- Delivery: `delivery_estimates`, `delivery_quotes`, `delivery_quote_events`.
- Finance: `supplier_settlements`, `supplier_settlement_items`, `settlement_proofs`, `reseller_commissions`, `withdrawals`, `payment_intents`.
- Growth: `promotions`, `product_insight_snapshots`, `whatsapp_templates`.
- Operations: `support_tickets`, `disputes`, `returns`, `refunds`, `risk_scores`, `restrictions`, `admin_queue_items`, `audit_logs`.
- Platform: `notification_logs`, `email_logs`, `settings`, `idempotency_keys`.

## 11. User/Profile Tables

`profiles` stores identity shared across roles. A profile may have one customer record, one reseller record, membership in supplier workspaces, and optionally admin staff privileges.

Additional profile support tables:

- `profile_contact_methods`: optional normalized contact details and verification flags.
- `profile_sessions_audit`: optional security event trail for login/session anomalies.
- `profile_consents`: terms, privacy policy, supplier agreement, reseller rules agreement, and timestamped versions.

Sensitive fields such as phone and WhatsApp are private and role-limited.

## 12. Customer Tables

`customers`:

- `id`, `profile_id unique`, `customer_status`, `risk_score`, `default_address_id`, timestamps.

`customer_addresses`:

- `id`, `customer_id`, `label`, `location_type`, `city_area`, `campus`, `address_line`, `landmark`, `notes`, `is_default`.

Customers must create/sign into an account before placing an order. Customer phone/WhatsApp supports fulfillment communication but is not OTP-verified in MVP.

## 13. Reseller Tables

`resellers`:

- `id`, `profile_id unique`, `reseller_type`, `approval_status`, `risk_level`, `payout_status`, `commission_available_amount`, `commission_pending_amount`.

`reseller_shops`:

- `id`, `reseller_id`, `shop_slug unique`, `display_name`, `bio`, `status`, `visibility`, `restricted_reason`.

`reseller_listings`:

- `id`, `reseller_id`, `shop_id`, `product_id`, `variant_id nullable`, `listing_status`, `reseller_margin_amount`, `customer_product_price_amount`, `share_slug`, timestamps.

The server must calculate reseller cost, max allowed price, reseller margin, and final customer price. Reseller listings must not expose supplier private contact or internal supplier settlement data.

## 14. Supplier Tables

`suppliers`:

- `id`, `owner_profile_id`, `business_name`, `business_type`, `primary_category_id`, `location_region`, `location_city`, `supplier_status`, `verification_status`, `risk_level`, `trust_level`, `settlement_status`, timestamps.

`supplier_verifications`:

- `id`, `supplier_id`, `submitted_by_profile_id`, `verification_status`, `ghana_card_front_path`, `ghana_card_back_path`, `business_document_path`, `review_notes`, `reviewed_by_profile_id`, timestamps.

`supplier_payout_accounts`:

- `id`, `supplier_id`, `provider`, `account_name`, `account_number_masked`, `encrypted_reference`, `status`, timestamps.

KYC and payout records are private. Ghana Card access should be limited to admin/super admin by default, not support staff.

## 15. Supplier Staff / Inventory Manager Tables

`supplier_staff`:

- `id`, `supplier_id`, `profile_id`, `supplier_role`, `staff_status`, `permissions jsonb`, `invited_by_profile_id`, timestamps.

`supplier_staff_invites`:

- `id`, `supplier_id`, `email`, `role`, `permissions jsonb`, `invite_status`, `expires_at`, `accepted_profile_id`.

Recommended permissions:

- `products.read`, `products.create`, `products.update`
- `stock.read`, `stock.adjust`, `stock.restock`
- `orders.read`, `orders.prepare`, `orders.ready`
- `settlements.read` owner-only unless explicitly expanded
- `payouts.manage` owner-only
- `staff.manage` owner-only

Inventory managers cannot change payout details, approve finance, verify settlements, or access platform-wide data.

## 16. Product and Catalog Tables

`product_categories`:

- `id`, `parent_id`, `name`, `slug`, `status`, `risk_level`, `requires_admin_review`.

`products`:

- `id`, `supplier_id`, `category_id`, `name`, `slug`, `description`, `brand`, `product_status`, `approval_status`, `base_price_amount`, `platform_margin_amount`, `reseller_cost_amount`, `max_customer_price_amount`, `rejection_reason`, timestamps.

`product_price_rules`:

- `id`, `product_id nullable`, `category_id nullable`, `supplier_id nullable`, `platform_margin_type`, `platform_margin_amount`, `max_reseller_margin_amount`, `effective_from`, `effective_to`, `status`.

Product approval and prohibited product decisions are admin-controlled and audited.

## 17. Product Variant and Image Tables

`product_variants`:

- `id`, `product_id`, `sku`, `variant_name`, `attributes jsonb`, `total_stock_quantity`, `reserved_stock_quantity`, `sold_stock_quantity`, `low_stock_threshold`, `variant_status`, timestamps.

`product_images`:

- `id`, `product_id`, `variant_id nullable`, `storage_path`, `alt_text`, `sort_order`, `image_status`, `is_primary`.

Variant stock is the ordering source of truth. Product images can be public only after product approval; unapproved product media should remain supplier/admin visible.

## 18. Inventory and Stock Movement Tables

`stock_movements`:

- `id`, `supplier_id`, `product_id`, `variant_id`, `movement_type`, `quantity_delta`, `previous_total_quantity`, `new_total_quantity`, `reason`, `order_id nullable`, `created_by_profile_id`, timestamps.

Movement types:

- `initial_stock`
- `restock`
- `reservation_created`
- `reservation_released`
- `sale_committed`
- `order_cancelled_release`
- `manual_adjustment`
- `return_restock`

Stock changes must be audited, append-only, and reconciled against variant stock fields.

## 19. Stock Reservation Tables

`stock_reservations`:

- `id`, `reservation_reference unique`, `customer_id`, `reseller_id`, `reseller_listing_id`, `product_id`, `variant_id`, `order_id nullable`, `quantity`, `reservation_status`, `expires_at`, `released_at`, `committed_at`, timestamps.

Reservation statuses:

- `pending`
- `reserved`
- `committed`
- `released`
- `expired`
- `failed`

Adding to cart does not reserve stock. Placing an order must call a secure reservation function. Recommended MVP reservation/confirmation timeout is 1 hour.

## 20. Cart and Checkout Tables

`carts`:

- `id`, `customer_id`, `reseller_id`, `shop_id`, `cart_status`, `expires_at`, timestamps.

`cart_items`:

- `id`, `cart_id`, `reseller_listing_id`, `product_id`, `variant_id`, `quantity`, `display_price_snapshot_amount`, timestamps.

Cart values are preview-only. Checkout must revalidate listing status, product approval, supplier status, risk restrictions, price rules, and stock availability before order creation.

## 21. Order and Order Item Tables

`orders`:

- `id`, `order_number unique`, `customer_id`, `reseller_id`, `shop_id`, `order_status`, `payment_method`, `payment_collection_status`, `delivery_status`, `customer_confirmation_status`, `delivery_quote_status`, `subtotal_product_amount`, `delivery_estimate_min_amount`, `delivery_estimate_max_amount`, `final_delivery_amount`, `total_payable_amount`, `currency_code`, timestamps.

`order_items`:

- `id`, `order_id`, `supplier_id`, `product_id`, `variant_id`, `reseller_listing_id`, `quantity`, `supplier_base_price_snapshot_amount`, `platform_margin_snapshot_amount`, `reseller_margin_snapshot_amount`, `reseller_cost_snapshot_amount`, `customer_product_price_snapshot_amount`, `line_total_amount`, `settlement_due_amount`, `commission_amount`, timestamps.

Order item snapshots are immutable after creation except for audited correction records.

## 22. Delivery Estimate and Delivery Quote Tables

`delivery_estimates`:

- `id`, `location_type`, `city_area`, `delivery_method`, `min_amount`, `max_amount`, `estimated_min_days`, `estimated_max_days`, `status`.

`delivery_quotes`:

- `id`, `order_id`, `quoted_by_profile_id`, `quote_status`, `delivery_method`, `quoted_amount`, `customer_approved_at`, `customer_rejected_at`, `expires_at`, notes.

`delivery_quote_events`:

- `id`, `delivery_quote_id`, `event_type`, `actor_profile_id`, `notes`, timestamps.

Delivery cost remains separate from product price and may require customer approval before dispatch.

## 23. Supplier Settlement Tables

`supplier_settlements`:

- `id`, `supplier_id`, `order_id`, `settlement_status`, `due_amount`, `paid_amount`, `outstanding_amount`, `due_at`, `verified_at`, `verified_by_profile_id`, `risk_level`, timestamps.

`supplier_settlement_items`:

- `id`, `settlement_id`, `order_item_id`, `platform_margin_amount`, `reseller_commission_amount`, `settlement_due_amount`, `settlement_paid_amount`, `item_status`.

`settlement_proofs`:

- `id`, `settlement_id`, `uploaded_by_profile_id`, `storage_path`, `payment_method`, `reference_number`, `proof_status`, `reviewed_by_profile_id`, review notes, timestamps.

Partial settlement must be supported. Overdue settlement must trigger restrictions and admin queue entries.

## 24. Reseller Commission Tables

`reseller_commissions`:

- `id`, `reseller_id`, `order_id`, `order_item_id`, `supplier_settlement_id`, `commission_status`, `commission_amount`, `available_at`, `withdrawal_id nullable`, `held_reason`, timestamps.

Commission statuses:

- `pending_order`
- `awaiting_delivery_payment`
- `awaiting_supplier_settlement`
- `available`
- `withdrawal_requested`
- `paid`
- `cancelled`
- `held`
- `adjusted`

Commission is calculated from the order item snapshot and becomes available only after settlement verification.

## 25. Withdrawal Tables

`withdrawals`:

- `id`, `reseller_id`, `requested_amount`, `approved_amount`, `withdrawal_status`, `provider`, `account_name`, `account_number_masked`, `requested_by_profile_id`, `approved_by_profile_id`, `paid_by_profile_id`, `failed_reason`, timestamps.

`withdrawal_items`:

- `id`, `withdrawal_id`, `commission_id`, `amount`.

Withdrawals can only use available commissions. Failed withdrawals should keep commission available or return it to available through audited logic.

## 26. Payment / Pay Online Placeholder Tables

`payment_intents`:

- `id`, `order_id`, `provider`, `payment_method`, `payment_status`, `amount`, `currency_code`, `provider_reference`, `disabled_reason`, timestamps.

For MVP, Pay Online rows may exist only as disabled/placeholder records. Real provider fields and webhook handling must wait until provider selection.

## 27. Promotion / Boost Tables

`promotions`:

- `id`, `supplier_id`, `product_id`, `requested_by_profile_id`, `promotion_type`, `promotion_status`, `requested_amount`, `approved_amount`, `starts_at`, `ends_at`, `reviewed_by_profile_id`, rejection reason, timestamps.

Promotion eligibility must check product approval, stock availability, supplier status, and no overdue settlement. Supplier cannot boost with overdue settlement.

## 28. Trending / Product Insight Tables

`product_insight_snapshots`:

- `id`, `product_id`, `variant_id nullable`, `category_id`, `area`, `snapshot_date`, `views_count`, `share_count`, `cart_count`, `order_count`, `sold_quantity`, `estimated_profit_amount`, `rank`.

`reseller_insight_snapshots`:

- `id`, `reseller_id`, `snapshot_date`, `products_shared_count`, `orders_count`, `commission_pending_amount`, `commission_available_amount`.

Advanced insight features may be locked behind future Pro rules, but basic product discovery must remain available.

## 29. Support and Dispute Tables

`support_tickets`:

- `id`, `opened_by_profile_id`, `related_order_id nullable`, `ticket_type`, `ticket_status`, `priority`, `assigned_to_profile_id`, timestamps.

`support_messages`:

- `id`, `ticket_id`, `sender_profile_id`, `message_body`, `visibility_scope`, timestamps.

`disputes`:

- `id`, `order_id`, `opened_by_profile_id`, `dispute_type`, `dispute_status`, `priority`, `assigned_to_profile_id`, `resolution`, timestamps.

`dispute_evidence`:

- `id`, `dispute_id`, `uploaded_by_profile_id`, `storage_path`, `evidence_type`, timestamps.

Evidence files are private. Disputes may hold commission and settlement actions.

## 30. Return / Refund Tables

`returns`:

- `id`, `order_id`, `order_item_id nullable`, `return_status`, `reason`, `approved_by_profile_id`, timestamps.

`refunds`:

- `id`, `order_id`, `return_id nullable`, `refund_status`, `refund_amount`, `refund_method`, `provider_reference`, timestamps.

MVP refunds are manual/admin tracked. Automated refunds are future.

## 31. Notification / Email Log Tables

`notification_logs`:

- `id`, `recipient_profile_id`, `channel`, `event_type`, `related_entity_type`, `related_entity_id`, `notification_status`, timestamps.

`email_logs`:

- `id`, `notification_log_id`, `resend_message_id`, `to_email`, `template_key`, `subject`, `send_status`, `error_message`, timestamps.

Important email events: account/onboarding, customer order, confirmation, delivery quote, supplier new order, settlement due/overdue, product approval/rejection, commission pending/available, withdrawal status, dispute updates.

## 32. Manual WhatsApp Helper Tables

`whatsapp_templates`:

- `id`, `template_key`, `audience`, `template_body`, `status`, `created_by_profile_id`, timestamps.

`whatsapp_template_logs`:

- `id`, `template_id`, `generated_by_profile_id`, `related_entity_type`, `related_entity_id`, `recipient_role`, `redaction_profile`, timestamps.

MVP does not send WhatsApp messages automatically. Logs should record generated/copyable templates, not message delivery.

## 33. Risk Score and Restriction Tables

`risk_scores`:

- `id`, `entity_type`, `entity_id`, `risk_level`, `score`, `last_calculated_at`, `summary`.

`risk_events`:

- `id`, `entity_type`, `entity_id`, `risk_event_type`, `severity`, `source_entity_type`, `source_entity_id`, `notes`, timestamps.

`restrictions`:

- `id`, `entity_type`, `entity_id`, `restriction_type`, `restriction_status`, `reason`, `starts_at`, `ends_at`, `created_by_profile_id`, `lifted_by_profile_id`, timestamps.

Risk should prioritize admin review and not silently punish users without clear admin visibility.

## 34. Admin Operations Queue Tables

`admin_queue_items`:

- `id`, `queue_type`, `priority`, `queue_status`, `related_entity_type`, `related_entity_id`, `assigned_to_profile_id`, `due_at`, `summary`, `created_from_event`, timestamps.

Required queues:

- customer confirmation
- delivery quote approval/follow-up
- supplier approval
- product approval
- settlement due
- overdue settlement
- proof verification
- commission release
- withdrawal review
- failed delivery
- dispute/support
- low/out-of-stock
- promotion approval
- risk review

Queues may be materialized from status tables where possible, with `admin_queue_items` used for assignment, SLA, manual triage, and historical workflow.

## 35. Audit Log Tables

`audit_logs`:

- `id`, `actor_profile_id nullable`, `actor_role`, `action`, `target_entity_type`, `target_entity_id`, `before_data jsonb`, `after_data jsonb`, `reason`, `ip_address`, `user_agent`, `request_id`, `created_at`.

Do not store passwords, raw secrets, private keys, or public URLs for sensitive documents. Store private storage paths only when needed and guard audit access.

## 36. Settings / Config Tables

`settings`:

- `id`, `setting_key unique`, `setting_value jsonb`, `scope`, `updated_by_profile_id`, timestamps.

Recommended settings:

- reservation timeout
- settlement due window
- overdue settlement threshold
- reseller approval mode
- minimum withdrawal amount
- platform margin defaults
- promotion pricing
- risk score thresholds
- delivery estimate defaults
- launch categories

All changes are admin/super admin controlled and audited.

## 37. Storage Bucket Plan

Buckets:

- `product-images`: public read only for approved product images; supplier/admin write with validation.
- `supplier-kyc`: private; admin/super admin read; supplier owner can upload/read own submitted docs only through signed URL rules.
- `settlement-proofs`: private; supplier owner can upload/read own proofs; finance/admin can read/review.
- `dispute-evidence`: private; participant-limited and admin/support readable by assignment.
- `avatars`: profile/shop images; public only for approved display fields.

Private buckets should use signed URLs, short expiration, and table-backed ownership checks.

## 38. RLS Policy Plan by Role

- Customer: own profile/customer/address/cart/order/dispute data; public approved product/listing read; cannot read internal margins, settlements, supplier private data, or commission data.
- Reseller: own reseller/shop/listing/commission/withdrawal data; approved catalog read with reseller-cost visibility; attributed order read; cannot read supplier private contact, supplier payout/KYC, customer data beyond order fulfillment fields, or settlement proof files.
- Supplier owner: own supplier workspace, products, stock, staff, settlements, fulfillment orders; cannot read reseller margin strategy outside order item snapshots required for settlement; cannot read other suppliers.
- Inventory manager: supplier-scoped operational tables only; no payout, KYC approval, settlement verification, staff management, or platform-wide reads.
- Finance staff: settlement, proof, withdrawal, commission queue access; no broad KYC unless explicitly allowed.
- Support staff: assigned tickets/disputes and safe order context only; no payout, KYC, raw settlement proof unless approved.
- Admin: broad operational read/write through audited actions.
- Super admin: all admin permissions plus staff roles, sensitive settings, and exceptional overrides.

## 39. RLS Policy Plan by Table Group

- Identity: users read/update own profile; admins read all; role changes server/admin only.
- Customer: customer own; admin/support assigned; no supplier/reseller broad access.
- Reseller: reseller own; admin all; customers only public shop/listing display.
- Supplier: supplier owner/staff own workspace by membership; admin all; public only approved supplier display fields.
- Catalog: approved active products/listings are public/readable; base price and platform margin hidden from customers and limited by role.
- Inventory: supplier owner/staff and admin only; no customer/reseller direct stock writes.
- Reservations: created/updated only through secure RPC/server; customer can see own reservation/order result.
- Orders: customer own, reseller attributed, supplier fulfillment slice, admin all.
- Finance: supplier settlements supplier/admin/finance only; commissions reseller/admin/finance only; withdrawals reseller/admin/finance only.
- Operations: queue/admin tables admin/support/finance by role; audit logs admin/super admin only.
- Notifications: recipient can see own high-level notifications; admin can see operational logs.

## 40. Secure RPC / Database Function Plan

Future secure functions should include:

- `create_or_get_profile_from_clerk(clerk_user_id, email, name)`
- `create_checkout_order(cart_id, delivery_selection, payment_method, idempotency_key)`
- `reserve_stock(variant_id, quantity, order_id, expires_at)`
- `release_expired_reservations()`
- `commit_stock_reservation(order_id)`
- `calculate_listing_price(product_id, reseller_margin_amount)`
- `mark_customer_confirmed(order_id, source)`
- `submit_delivery_quote(order_id, amount, method)`
- `approve_delivery_quote(order_id)`
- `submit_settlement_proof(settlement_id, proof_metadata)`
- `verify_supplier_settlement(settlement_id, amount, reason)`
- `release_commission_after_settlement(settlement_id)`
- `request_withdrawal(reseller_id, amount, idempotency_key)`
- `apply_restriction(entity_type, entity_id, reason)`
- `write_audit_log(...)`

Sensitive functions should run with controlled privileges, validate actor authorization, and write audit rows.

## 41. Atomic Stock Reservation Logic

Order creation must be transactional:

1. Resolve authenticated customer profile.
2. Resolve reseller listing and product variant from trusted database records.
3. Lock the `product_variants` row with `for update`.
4. Recalculate available stock as `total_stock_quantity - reserved_stock_quantity - sold_stock_quantity`.
5. Fail if product/listing/supplier is inactive, restricted, unapproved, or stock is insufficient.
6. Recalculate all prices and margin snapshots server-side.
7. Insert order and order item snapshots.
8. Insert stock reservation row.
9. Increase `reserved_stock_quantity`.
10. Insert stock movement and audit log.
11. Commit transaction.

Expired reservations must release stock through scheduled job/function with audit trail.

## 42. Order Status Transition Rules

Recommended order statuses:

- `draft`
- `placed_pending_confirmation`
- `customer_confirmed`
- `delivery_quote_pending`
- `delivery_quote_ready`
- `delivery_quote_approved`
- `supplier_preparing`
- `ready_for_pickup_or_dispatch`
- `out_for_delivery`
- `delivered_payment_pending`
- `payment_collected`
- `completed`
- `cancelled`
- `failed`
- `disputed`

Supplier preparation is blocked until customer confirmation. Delivery quote approval may be required before dispatch. Completed/payment-collected order can create settlement obligation and commission progression.

## 43. Supplier Settlement Ledger Logic

For each order item:

`settlement_due_amount = platform_margin_snapshot_amount + reseller_margin_snapshot_amount`

For each supplier/order:

- Create settlement after Pay on Delivery payment is marked collected or when settlement obligation becomes due by operational rule.
- Support partial paid amounts.
- Outstanding amount is derived from settlement item totals minus verified payments.
- Overdue status is derived from `due_at`, outstanding amount, and verification status.
- Verification by admin/finance can release associated reseller commissions.
- Rejection of proof keeps settlement outstanding and creates queue/risk events.

## 44. Reseller Commission Lifecycle Logic

Commission is created from order item snapshot:

`commission_amount = reseller_margin_snapshot_amount`

Lifecycle:

1. `pending_order` at order creation.
2. `awaiting_delivery_payment` after customer confirmation/supplier preparation.
3. `awaiting_supplier_settlement` after delivery/payment collection.
4. `available` after supplier settlement is verified.
5. `withdrawal_requested` when included in withdrawal.
6. `paid` when withdrawal is paid.
7. `cancelled` if order is cancelled/refused/refunded.
8. `held` if dispute/risk requires review.

Manual adjustments require reason and audit.

## 45. Price Snapshot and Margin Calculation Logic

Pricing formula:

`Customer Product Price = Supplier Base Price + Risellar Platform Margin + Reseller Margin`

Store on order item:

- supplier base price snapshot
- platform margin snapshot
- reseller cost snapshot
- reseller margin snapshot
- customer product price snapshot
- delivery estimate/quote separately on order

Only trusted server/database logic calculates sensitive values. Product/listing updates must never mutate existing order snapshots.

## 46. Supplier Staff Permission Logic

Supplier staff access is scoped by `supplier_id` membership and permission flags.

Inventory manager can:

- read/create/update products within supplier workspace
- update variant stock through controlled functions
- view low-stock alerts and inventory activity
- mark orders ready/prepared where assigned

Inventory manager cannot:

- manage payout accounts
- approve/verify settlements
- view full platform margins beyond role-appropriate operational values
- manage staff
- access other suppliers

Permission changes are owner/admin only and audited.

## 47. Promotions Eligibility Logic

Promotion approval must check:

- supplier is approved/active
- product is approved/active
- stock is available
- no overdue settlement restrictions
- product is not risky/prohibited
- promotion payment/manual approval is complete where required

Promotion status changes create admin queue/audit records.

## 48. Risk and Restriction Logic

Risk events feed risk scores and queues. Triggers include late settlement, rejected proof, fake/wrong product, stock mismatch, repeated failed delivery, customer refusal, fake orders, complaints, and suspicious admin override patterns.

Restriction effects may include:

- warning only
- new orders blocked
- product hidden
- promotion blocked
- settlement-required before new fulfillment
- account restricted
- account suspended

Automated restrictions should be conservative in MVP and visible to admin.

## 49. Admin Permissions and Staff Role Separation

Admin permission groups:

- `operations`: orders, delivery, queues, support context.
- `catalog`: products, categories, approvals.
- `risk`: restrictions, risk review, manual queue escalation.
- `finance`: settlement proof review, settlement verification, commission release, withdrawal handling.
- `super_admin`: admin staff, sensitive settings, exceptional overrides.

Manual overrides must require reason, permission check, and audit log. Finance/support separation protects sensitive KYC and payout data.

## 50. Indexes and Performance Plan

Recommended indexes:

- `profiles(clerk_user_id) unique`
- `profiles(email)`
- `customers(profile_id) unique`
- `resellers(profile_id) unique`
- `reseller_shops(shop_slug) unique`
- `suppliers(owner_profile_id)`
- `supplier_staff(supplier_id, profile_id) unique`
- `products(supplier_id, product_status, approval_status)`
- `product_variants(product_id, variant_status)`
- `reseller_listings(shop_id, listing_status)`
- `reseller_listings(product_id, reseller_id)`
- `stock_reservations(variant_id, reservation_status, expires_at)`
- `orders(customer_id, created_at)`
- `orders(reseller_id, order_status)`
- `order_items(supplier_id, order_id)`
- `supplier_settlements(supplier_id, settlement_status, due_at)`
- `reseller_commissions(reseller_id, commission_status)`
- `admin_queue_items(queue_type, queue_status, priority, due_at)`
- `audit_logs(target_entity_type, target_entity_id, created_at)`

Use partial indexes for active/approved public catalog and open queues.

## 51. Constraints and Data Integrity Rules

- Monetary values must be non-negative.
- Quantity values must be non-negative; movement deltas may be negative.
- `reserved_stock_quantity + sold_stock_quantity <= total_stock_quantity` unless an audited correction state is introduced.
- One customer/reseller record per profile.
- One supplier owner must exist for each supplier.
- Order item snapshots cannot be null.
- Commission amount equals reseller margin snapshot unless audited adjustment exists.
- Settlement due equals platform margin plus reseller commission unless audited adjustment exists.
- Withdrawal items must reference available commissions only.
- Private storage paths must not be public URLs.

## 52. Idempotency and Race Condition Protection

Use `idempotency_keys`:

- `id`, `scope`, `key`, `profile_id`, `request_hash`, `response_reference`, `status`, `expires_at`, timestamps.

Critical idempotent operations:

- checkout order creation
- customer confirmation by email link/account/manual admin
- delivery quote approval
- settlement proof submission
- settlement verification
- commission release
- withdrawal request
- webhook handling for future Pay Online

Use row locks and unique constraints for stock reservation and payment/settlement references.

## 53. Audit Logging Requirements

Audit these actions:

- role changes
- supplier approval/rejection/more-info request
- Ghana Card/KYC review
- payout account changes
- product approval/rejection
- price/margin changes
- stock adjustments and reservations
- order status changes
- customer confirmation source changes
- delivery quote approval/rejection
- supplier payment received mark
- settlement proof upload/review/verification/rejection
- commission release/hold/adjustment
- withdrawal approval/rejection/payment/failure
- restrictions/suspensions
- manual overrides
- admin settings changes

## 54. Privacy and Sensitive Data Handling

- Customers cannot see supplier base price, platform margin, reseller commission, supplier private contact, or settlement details.
- Resellers cannot see supplier private contact, supplier payout/KYC, or other resellers' data.
- Suppliers cannot see reseller private strategy beyond settlement-required commission snapshots for their own order items.
- Support staff should see only fields needed to resolve assigned tickets/disputes.
- KYC, payout, settlement proofs, and dispute evidence require private storage and limited role access.
- Avoid logging raw secrets, full Ghana Card numbers, or unmasked payout account numbers.

## 55. Supabase Storage Security Plan

Storage policies should:

- deny public listing of private buckets
- require authenticated users for uploads
- validate ownership through table records
- use signed URLs for private reads
- restrict KYC reads to admin/super admin and supplier owner own submissions
- restrict settlement proof reads to supplier owner, finance, admin, and super admin
- restrict dispute evidence reads to participants and assigned support/admin
- allow public product image reads only after product/image approval

## 56. Resend Email Logging Plan

Every transactional email should create:

1. `notification_logs` row with event context.
2. `email_logs` row with Resend template/message status.
3. Optional audit log for operationally sensitive emails, such as settlement overdue or restriction notice.

Email failures should create admin queue items only for business-critical events.

## 57. Manual WhatsApp Template Data Plan

Templates should be generated from approved `whatsapp_templates` and safe entity data. Template rendering must redact internal margins, supplier private contact, KYC details, payout details, settlement proof links, and unrelated customer data.

Template logs should record who generated the template and for which order/settlement/dispute, but not claim delivery.

## 58. Data Retention / Deletion Considerations

- Audit logs: retain indefinitely for MVP unless legal/storage policy changes.
- Orders, settlements, commissions, withdrawals: retain as financial/operational records.
- KYC documents: retain while supplier is active and for a defined period after offboarding; exact period is an open question.
- Private dispute evidence: retain for dispute lifecycle and defined post-resolution period.
- Soft-delete user-facing records where financial or audit trace must remain.
- Account deletion must anonymize display data where possible while preserving ledger/audit integrity.

## 59. MVP Schema Boundary

Included in MVP schema:

- Clerk profile mapping
- customers/resellers/suppliers/admin staff
- supplier verification/KYC metadata
- supplier products, variants, images
- inventory, movements, atomic reservations
- carts, checkout, orders, order items
- delivery estimates/quotes
- Pay on Delivery tracking
- supplier settlements/proofs
- reseller commissions/withdrawals
- promotions/boost requests
- product insights snapshots
- support/disputes/basic returns/refunds
- Resend logs
- manual WhatsApp templates/logs
- risk/restrictions/queues/audit/settings

Excluded from MVP schema:

- native mobile app records
- rider app accounts
- phone OTP verification tables
- WhatsApp Business API automation
- full online payment automation
- automated MoMo reconciliation
- advanced ML fraud models

## 60. Future Schema Extensions

Future additions may include:

- Paystack/Hubtel provider tables and webhook events
- automated MoMo reconciliation
- WhatsApp Business API messages and delivery receipts
- subscriptions/Pro reseller plans
- AI recommendations/caption generation
- rider/delivery provider accounts
- advanced fraud scoring models
- multi-country/currency support
- supplier trusted-level settlement schedules
- automated refunds

## 61. Security Test Checklist

Future tests must prove:

- unauthenticated users cannot read private data
- customers cannot place order without account
- customer cannot create order when stock reservation fails
- customers cannot alter price/margin/order snapshots
- customers cannot read supplier base price or settlement data
- reseller cannot read supplier private contact/KYC/payout
- reseller cannot withdraw pending commission
- supplier cannot access other suppliers' products/orders/settlements
- inventory manager cannot change payout or verify settlement
- supplier with overdue settlement cannot boost product
- admin sensitive actions write audit logs
- private storage buckets deny public access
- service-role-only functions are not callable directly by ordinary clients
- idempotent checkout does not duplicate orders/reservations
- concurrent checkout cannot oversell variant stock

## 62. Open Questions

- Should low-risk reseller onboarding be auto-approved or require admin approval at launch?
- What exact minimum withdrawal amount should be enforced: GH₵20, GH₵50, or another threshold?
- What overdue settlement amount/count blocks supplier new orders?
- What exact KYC document retention period should Risellar use?
- Which admin roles can view Ghana Card documents beyond super admin/admin?
- Which Pay Online provider will be selected later: Paystack, Hubtel, or another provider?
- What exact delivery SLA and ownership model applies by category/location?
- What exact launch categories and prohibited category list should be configured?
- What promotion pricing and duration rules should launch?
- What thresholds define trusted suppliers and customer/reseller risk restrictions?

## 63. Final Implementation Principles

- Treat this document as planning only until migrations/RLS are explicitly requested.
- Build the database around Risellar's Ghana Pay on Delivery trust model, not a generic ecommerce clone.
- Keep Supplier -> Risellar/Admin -> Reseller -> Customer boundaries intact.
- Calculate sensitive prices, margins, settlement amounts, commission, and stock server-side.
- Store immutable order snapshots.
- Reserve stock atomically.
- Gate reseller commission on verified supplier settlement.
- Keep private files private.
- Make admin operations auditable.
- Keep MVP practical: Clerk, Resend, manual WhatsApp helpers, Pay on Delivery, and controlled admin workflows first.
