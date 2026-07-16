# Risellar Frontend Backend Handoff Checklist

## 1. Mock Data Domains Created

- Design system examples: products, orders, people, finance, admin queues, promotions.
- Reseller core: profile, shop, products, reseller listings, orders, wallet, transactions, notifications.
- Customer checkout: public shop, customer profile, cart, delivery details, delivery options, order, tracking, support.
- Supplier core: supplier profile, onboarding, products, orders, notifications, settings.
- Supplier inventory: stock metrics, variants, movements, restock, price change requests, inventory manager activity.
- Supplier settlements: obligations, proofs, trust score, restrictions, settlement history, finance and payout details.
- Admin core: dashboard metrics, orders, products, suppliers, resellers, customers, settlements, commissions, withdrawals.
- Admin operations: queues, risk entities, audit logs, manual override examples.
- Promotions and insights: supplier boosts, packages, reseller insights, sponsored products, admin approvals.
- Team and permissions: supplier staff, roles, permission groups, activity, inventory manager views.
- Support and disputes: tickets, disputes, returns, refunds, evidence placeholders, timelines.
- Edge cases: loading, empty, not found, offline, restricted, suspended, stock, settlement, commission, verification, delivery, support states.

## 2. Mock Actions Currently Used

- Add product to shop, save selling price, copy/share caption, request withdrawal.
- Place order, confirm order, approve delivery quote, report issue, request return, view refund.
- Add/edit product, mark preparing, mark ready, restock, request price change.
- Submit settlement proof, copy payment instructions, export/download statement.
- Create promotion, upload promotion proof, copy product link, approve/reject/pause placeholders.
- Invite team member, preview permission toggles, request access.
- Open support ticket, upload evidence placeholder, add note, resolve/reject placeholders.
- Admin queue assignment, risk review, manual override reason entry, approval controls.

## 3. Routes That Need Backend Data

- All `/reseller/*` routes need authenticated reseller profile, shop, listings, orders, commissions, withdrawals, and notifications.
- All `/shop/*`, `/checkout/*`, and `/customer/*` routes need customer auth, cart, address, order, delivery, support, return, refund, and dispute data.
- All `/supplier/*` routes need supplier workspace, staff role, products, stock, orders, settlements, finance, promotions, team, and support data.
- All `/admin/*` routes need admin role, platform-wide operational data, queues, audit logs, risk, finance, and support data.
- `/edge-cases/*`, `/design-system`, and `/preview` can remain internal/static review surfaces.

## 4. Forms That Need Persistence

- Reseller onboarding, shop edit, pricing, withdrawal, support, and missing commission forms.
- Customer account, delivery, payment selection, order confirmation, issue report, return request, dispute evidence forms.
- Supplier onboarding, product create/edit, stock/restock, price change, settlement proof, payout details, promotion request, team invite, support forms.
- Admin filters, notes, queue actions, approvals, refunds/returns, support resolution, risk decisions, and manual override reason forms.

## 5. Status Transitions That Need Server Validation

- Order: awaiting confirmation, customer confirmed, preparing, delivery quote pending, delivery approved, out for delivery, delivered, payment collected, settlement due, completed, cancelled, refused, dispute opened.
- Stock reservation: pending, reserved, expired, released, converted to sale, failed.
- Product: pending approval, active, rejected, needs changes, price change pending, needs reseller review, out of stock, hidden, suspended.
- Settlement: due, proof submitted, verifying, partially settled, paid, overdue, disputed.
- Commission: pending, awaiting settlement, available, withdrawal requested, paid, cancelled, disputed.
- Promotion: pending payment, pending approval, active, paused, completed, rejected, cancelled.
- Verification: pending, approved, rejected, more info required.
- Support/dispute/return/refund statuses and all admin override outcomes.

## 6. File Upload Placeholders That Need Storage

- Supplier Ghana Card and business verification files.
- Product images.
- Settlement proof screenshots or receipts.
- Promotion payment proof.
- Dispute, return, refund, and support evidence.
- Future admin attachments or audit-supporting documents.

## 7. Email Events That Need Resend

- Account welcome and approval/rejection.
- Customer order received, confirmation reminder, delivery quote ready, cancellation, delivery, and support updates.
- Reseller order attribution, commission pending, commission available, withdrawal status, support updates.
- Supplier product approval/rejection, confirmed order, settlement due/overdue, proof review, support updates.
- Admin queue alerts, approval events, dispute updates, and risk/restriction notices.

## 8. Auth / Role Points That Need Clerk

- Customer account creation before checkout.
- Reseller onboarding and reseller-only route access.
- Supplier owner onboarding, supplier workspace membership, and inventory manager access.
- Admin, finance, support staff, and super admin role assignment.
- Route protection and server-side role checks for every sensitive page.

## 9. Security-Sensitive Operations Needing Server Enforcement

- Price calculation and margin limits.
- Stock reservation and release.
- Order creation and status changes.
- Delivery quote approval.
- Supplier settlement proof review and verification.
- Commission release and withdrawal approval.
- Supplier/product/customer/reseller restrictions or suspensions.
- Team permissions and owner-only controls.
- Admin manual overrides.
- Dispute, return, and refund resolution.

## 10. Stock Reservation Integration Points

- Checkout order placement.
- Customer confirmation timeout.
- Supplier preparation gating.
- Cancellation/refusal stock release.
- Delivered/paid conversion to sold stock.
- Variant-level reservation, especially low stock and "only 1 left" products.

## 11. Supplier Settlement Integration Points

- Payment collected event.
- Settlement ledger creation.
- Proof upload.
- Admin/finance verification.
- Partial settlement handling.
- Overdue restriction trigger.
- Trust score impact.

## 12. Commission Release Integration Points

- Commission snapshot at order creation.
- Commission hold while confirmation, payment, delivery, settlement, or dispute is incomplete.
- Commission available after verified settlement.
- Withdrawal request and payout status.
- Dispute/return/refund reversal or hold rules.

## 13. Admin Operations Integration Points

- Queue counts and assignment.
- Product and supplier approvals.
- Customer confirmation follow-up.
- Delivery quote coordination.
- Settlement due and overdue queues.
- Commission release queue.
- Withdrawal queue.
- Risk review queue.
- Audit log write/read model.
- Manual override approval and reason capture.

## 14. Dispute / Return / Refund Integration Points

- Ticket creation and messaging.
- Evidence upload and private access.
- Dispute status transitions.
- Return eligibility by category.
- Refund calculation for Pay on Delivery and future Pay Online.
- Commission and settlement holds during disputes.
- Admin resolution and audit logging.

## 15. Future Payment / Pay Online Integration Points

- Pay Online is currently disabled/placeholder.
- Provider choice, payment intent creation, callback/webhook verification, reconciliation, refunds, and fraud checks are future backend work.
- Paystack/Hubtel/MoMo provider secrets must remain server-only.
- Customer UI must only show Pay Online as available after backend verification exists.

## 16. Open Frontend Questions Before Backend

- Confirm launch categories and prohibited-category enforcement copy.
- Confirm minimum reseller withdrawal amount.
- Confirm supplier settlement grace period and restriction thresholds.
- Confirm delivery ownership model and quote SLA.
- Confirm admin staff roles for support vs finance vs super admin.
- Confirm whether reseller onboarding needs admin approval at MVP.
- Confirm Pay Online provider decision and whether it remains disabled for MVP.
- Confirm production logo/image asset pipeline.
