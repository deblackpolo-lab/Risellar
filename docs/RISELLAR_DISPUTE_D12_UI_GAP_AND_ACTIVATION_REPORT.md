# Risellar Dispute D12 UI Gap and Activation Report

Date: 2026-08-02

## Activation Classification

Classification: **B. Backend and partial UI complete, more UI required.**

## Safe To Keep Active

Routes with live or previously verified RPC-backed behavior may remain under existing role guards:

- Customer address/contact setup
- Customer order-history safe reads
- Checkout draft and confirmed-order reads within their existing approved scope
- Supplier order decision, preparation, delivery, payment-reported, and dashboard/finance reads
- Reseller dashboard, wallet, earnings, withdrawal request/history, catalog, my-products, and public read-only shop
- Admin product approval, settlement verification, withdrawal review, finance dashboard, and notification APIs

## Do Not Activate As Live D12 Workflow Yet

The following route groups are present but should remain mock-only/UI-pending until a live RPC-backed implementation and browser QA pass are completed:

- `/customer/orders/[id]/return-request`
- `/customer/orders/[id]/refund-status`
- `/customer/support`
- `/customer/support/tickets`
- `/supplier/support`
- `/supplier/support/returns`
- `/supplier/support/settlement-dispute`
- `/reseller/support`
- `/reseller/support/commission-disputes/[id]`
- `/admin/disputes`
- `/admin/disputes/[id]`
- `/admin/returns`
- `/admin/returns/[id]`
- `/admin/refunds`
- `/admin/refunds/[id]`
- `/admin/support`
- `/admin/support/tickets`

## Blockers

- Missing active support/dispute-admin QA account with verified primary email.
- Missing active super-admin QA account.
- Production home page still displays the Phase 1 design shell message.
- Production protected route sweep did not prove the expected Clerk redirect behavior for activated role routes.
- D12 dispute/return/refund UI routes still use preserved mock/support-disputes components.

## Recommended Activation Path

1. Create real DEVELOPMENT support/dispute-admin and super-admin QA accounts through approved admin-staff bootstrap.
2. Replace mock-only D12 routes with live server-action/RPC UI screens.
3. Add route-level tests proving mock components are absent from activated D12 paths.
4. Redeploy production and verify root/role routes reflect the activated app.
5. Rerun D12 browser QA with real customer, supplier, reseller, support/dispute-admin, finance-admin, and super-admin sessions.

## D13-A Follow-Up

D13-A completed the access and route architecture planning pass. Safe aggregate DEVELOPMENT audit still found no active support_staff or super_admin admin_staff bucket, so real support/super-admin browser QA remains blocked until verified Clerk-backed QA accounts are provided or approved for bootstrap.

The final D13 route architecture, guard matrix, mock audit, data-access plan, shared component plan, navigation plan, implementation groups, and release gap report are captured in the D13-A documentation pack. No D13-A workflow UI, migration, RLS policy, finance/business logic, notification behavior, or mock activation was added.

## D13-B Customer Disputes Follow-Up

D13-B source implementation has replaced the customer dispute mock routes locally:

- `/customer/disputes`
- `/customer/disputes/[id]`
- `/customer/orders/[id]/report-problem`
- `/customer/orders/[id]/report-issue` redirects to `/customer/orders/[id]/report-problem`

These routes use the customer-safe dispute RPCs and no longer import `lib/mock/support-disputes`. The safe customer order-item selector RPC is applied in development and item-specific browser QA has passed. Final verification, commit, push, and production smoke remain before this route group can be considered release-ready.
