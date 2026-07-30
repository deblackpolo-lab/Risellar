# Risellar Recovery Phase 4 Active Route Inventory

Date: 2026-07-30

## Purpose

This inventory records which routes are allowed to behave as live routes after the recovery checkpoint and which routes must remain coming-soon, mock-only, or hidden from navigation before checkout draft UI is reintroduced.

## Confirmed Live Routes

### Public

- `/`
- `/shop/[shopSlug]` read-only public reseller shop
- `/shop/[shopSlug]/product/[productId]` read-only public reseller product detail
- `/sign-in`
- `/sign-up`

### Auth QA

- `/auth/qa-profile-sync` development-only profile sync QA route

### Customer

- `/customer/addresses` for Customer Phase A contact and delivery address management

Customer fallback after completed profile/onboarding now points to `/customer/addresses`, not `/customer/orders`.

### Reseller

- `/reseller/dashboard`
- `/reseller/products`
- `/reseller/products/[id]`
- `/reseller/my-products`
- `/reseller/settings`
- `/reseller/support`

These routes can show approved product catalog and reseller listing management that was previously tested through RPC and browser QA. They must not create orders, reserve stock, collect payment, trigger delivery, create settlement rows, create commission rows, or start withdrawals.

### Supplier

- `/supplier/dashboard`
- `/supplier/products`
- `/supplier/products/new`
- `/supplier/products/[id]`
- `/supplier/products/[id]/edit`
- `/supplier/inventory`
- `/supplier/team`
- `/supplier/settings`
- `/supplier/support`

Supplier product management remains limited to product/listing foundation work. Supplier order preparation, payment, delivery, settlement, and commission workflows remain disconnected.

### Admin

- `/admin/dashboard`
- `/admin/products`
- `/admin/products/[id]`
- `/admin/onboarding-requests`
- `/admin/operations/product-approvals`

Admin routes may review onboarding and product approval through audited server paths already tested. Admin order, settlement, commission, and withdrawal workflows remain mock-only and are hidden from primary navigation.

## Coming-Soon or Mock-Only Routes Retained

The following route groups are retained only as safe placeholders or design references:

- `/checkout/*`
- `/customer/orders`
- `/customer/orders/[id]`
- `/customer/orders/[id]/confirm`
- `/customer/orders/[id]/delivery-quote`
- `/reseller/orders`
- `/reseller/orders/[id]`
- `/reseller/wallet`
- `/reseller/withdraw`
- `/supplier/orders`
- `/supplier/orders/[id]`
- `/supplier/orders/[id]/prepare`
- `/supplier/settlements`
- `/supplier/settlements/*`
- `/supplier/finance`
- `/admin/orders`
- `/admin/orders/[id]`
- `/admin/settlements`
- `/admin/commissions`
- `/admin/withdrawals`

These routes must not be discoverable as active business workflows. If visited directly, they must make clear that order creation, supplier preparation, stock reservation, delivery, payment, settlement, commission, and withdrawal flows are deferred.

## Navigation Links Hidden or Removed

- Customer completed-role fallback no longer routes to `/customer/orders`.
- Reseller bottom navigation no longer exposes Orders or Wallet as active tabs.
- Supplier bottom navigation no longer exposes Orders as an active tab.
- Supplier dashboard quick action for Orders is disabled as coming soon.
- Admin sidebar no longer exposes Orders, Settlements, Commissions, or Withdrawals.
- Admin dashboard primary links now point to product review and onboarding review, not orders or settlements.

## Active Mutation Audit

Phase 4 did not add backend mutations, migrations, Supabase queries, checkout submit paths, order creation paths, stock reservation paths, payment paths, delivery quote paths, settlement mutation paths, commission release paths, or withdrawal paths.

Existing business logic and mock preview components may still describe these future domains, but the cleaned route surfaces must remain read-only, disabled, or coming-soon unless a later approved backend phase explicitly connects them.

## Files Removed

No route files were removed in Phase 4. The recovery approach kept route files in place and made their user-facing states honest and non-actionable.
