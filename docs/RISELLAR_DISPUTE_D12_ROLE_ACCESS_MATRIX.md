# Risellar Dispute D12 Role Access Matrix

Date: 2026-08-02

## Development Role Matrix

Masked aggregate DEVELOPMENT database inspection found active QA populations for:

- Customers
- Supplier owners with active/approved suppliers
- Approved/active resellers
- Finance staff

No active support/dispute-admin or super-admin bucket appeared in the aggregate `admin_staff` role matrix. This means D12 cannot claim support/dispute-admin or super-admin authenticated browser coverage.

## Verified Backend Role Boundaries

SQL and concurrency tests verified:

- Anonymous callers are blocked from protected dispute, return, refund, finance, settlement, withdrawal, and notification processor paths.
- Customers can act only on their own orders/disputes/returns/refund status.
- Supplier owners can act only for their own supplier scope and cannot act as another supplier.
- Resellers receive commission/wallet/liability impact views only and cannot access complaint text, supplier responses, refund references, settlement private data, or other reseller records.
- Support/admin investigation RPCs require active support/admin/super-admin `admin_staff` authority.
- Finance actions require active `finance_staff` or equivalent finance authority and are not granted by `profiles.primary_role` alone.
- Support-only admins are blocked from finance mutations in backend tests.
- Finance-only admins are not counted as support/dispute-admin browser proof.
- Inactive admin staff and suspended profiles are blocked by backend tests.

## Browser Coverage Status

- Customer browser coverage: partially available through live customer order/contact/address/order-history surfaces; full dispute UI remains mock/pending where Phase 13 screens are used.
- Supplier browser coverage: supplier order/finance surfaces are live for prior verified order handling; supplier dispute/return/refund support UI remains mock/pending where Phase 13 screens are used.
- Reseller browser coverage: dashboard, wallet, earnings, withdrawals, and liability-related finance views are live/previously verified; commission-dispute support pages remain mock/pending.
- Finance-admin browser coverage: finance dashboard, settlement verification, and withdrawal review were previously verified; D12 backend regression reconfirmed finance boundaries.
- Support/dispute-admin browser coverage: blocked by missing real support/dispute-admin QA account.
- Super-admin browser coverage: blocked by missing real super-admin QA account.

## Access Activation Recommendation

Keep finance, settlement, withdrawal, dashboard, supplier order, customer order-history, and notification surfaces available only under their existing guards. Keep dispute/return/refund/support Phase 13 routes out of MVP activation until live RPC-backed UI is implemented and browser-tested with a real support/dispute-admin account.
