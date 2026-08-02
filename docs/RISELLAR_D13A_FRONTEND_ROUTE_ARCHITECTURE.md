# Risellar D13-A Frontend Route Architecture

Date: 2026-08-02

## Summary

D13-A defines the final route architecture for disputes, returns, refunds, finance holds, reseller liabilities, and withdrawal-review UI activation. This phase does not build the full workflow screens.

## Production Auth Smoke

| Route | Result |
| --- | --- |
| /sign-in | HTTP 200 |
| /sign-up | HTTP 200 |
| /customer/dashboard | Signed-out request returned safe 404/protect rewrite |
| /supplier/dashboard | Signed-out request returned safe 404/protect rewrite |
| /reseller/dashboard | Signed-out request returned safe 404/protect rewrite |
| /admin/dashboard | Signed-out request returned safe 404/protect rewrite |

The sign-in route is available. Protected routes did not expose content to signed-out callers, but the production response is a safe 404 rewrite rather than a visible redirect in this smoke test.

## Customer Routes

| Route | Current state | D13 target |
| --- | --- | --- |
| /customer/dashboard | Exists, live dashboard | Keep |
| /customer/orders | Exists, live safe-read order history | Keep |
| /customer/orders/[id] | Exists, live safe-read order detail | Keep |
| /customer/disputes | Missing | Build in D13-B |
| /customer/disputes/[id] | Exists, mock-only detail shell | Replace with live D13-B detail |
| /customer/returns | Missing | Build in D13-C |
| /customer/returns/[id] | Missing | Build in D13-C |
| /customer/refunds | Missing | Build in D13-C |
| /customer/refunds/[id] | Missing | Build in D13-C |

Existing order-linked issue routes are mock-only entry points and must not be treated as live.

## Supplier Routes

| Route | Current state | D13 target |
| --- | --- | --- |
| /supplier/dashboard | Exists, live dashboard | Keep |
| /supplier/orders | Exists, live supplier order list | Keep |
| /supplier/orders/[id] | Exists, live supplier order detail/actions | Keep |
| /supplier/disputes | Missing | Build in D13-D |
| /supplier/disputes/[id] | Missing | Build in D13-D |
| /supplier/returns | Missing | Build in D13-E |
| /supplier/returns/[id] | Missing | Build in D13-E |
| /supplier/refunds | Missing | Build in D13-E |
| /supplier/refunds/[id] | Missing | Build in D13-E |

Existing /supplier/support routes are mock support surfaces and should stay quarantined until replaced.

## Reseller Routes

| Route | Current state | D13 target |
| --- | --- | --- |
| /reseller/dashboard | Exists, live dashboard | Keep |
| /reseller/earnings | Exists | Keep |
| /reseller/wallet | Exists, live wallet/withdrawal context | Keep |
| /reseller/withdrawals | Exists, live withdrawal history | Keep |
| /reseller/withdrawals/[withdrawalId] | Exists, live withdrawal detail | Keep |
| /reseller/liabilities | Missing | Build in D13-I |
| /reseller/liabilities/[id] | Missing | Build in D13-I |

Reseller support and commission-dispute mock routes should remain non-live until the liability workflow is connected to safe RPCs.

## Admin And Finance Routes

| Route | Current state | D13 target |
| --- | --- | --- |
| /admin/dashboard | Exists | Keep |
| /admin/disputes | Exists, mock-only | Replace in D13-F |
| /admin/disputes/[id] | Exists, mock-only | Replace in D13-F |
| /admin/returns | Exists, mock-only | Replace in D13-G |
| /admin/returns/[id] | Exists, mock-only | Replace in D13-G |
| /admin/refunds | Exists, mock-only | Replace in D13-H |
| /admin/refunds/[id] | Exists, mock-only | Replace in D13-H |
| /admin/finance | Exists, finance dashboard | Keep |
| /admin/finance-holds | Missing | Build in D13-H |
| /admin/finance-holds/[id] | Missing | Build in D13-H |
| /admin/liabilities | Missing | Build in D13-H |
| /admin/liabilities/[id] | Missing | Build in D13-H |
| /admin/settlements | Exists, live settlement review | Keep |
| /admin/settlements/[orderId] | Exists, live settlement detail | Keep |
| /admin/withdrawals | Exists, live withdrawal review | Keep |
| /admin/withdrawals/[withdrawalId] | Exists, live withdrawal detail | Keep |

Finance routes should stay under /admin rather than a separate /finance root.

## Final Approved Route Structure

Customer:

- /customer/disputes
- /customer/disputes/[id]
- /customer/returns
- /customer/returns/[id]
- /customer/refunds
- /customer/refunds/[id]

Supplier:

- /supplier/disputes
- /supplier/disputes/[id]
- /supplier/returns
- /supplier/returns/[id]
- /supplier/refunds
- /supplier/refunds/[id]

Reseller:

- /reseller/liabilities
- /reseller/liabilities/[id]
- /reseller/wallet
- /reseller/withdrawals
- /reseller/withdrawals/[withdrawalId]

Support/admin:

- /admin/disputes
- /admin/disputes/[id]
- /admin/returns
- /admin/returns/[id]

Finance:

- /admin/refunds
- /admin/refunds/[id]
- /admin/finance-holds
- /admin/finance-holds/[id]
- /admin/liabilities
- /admin/liabilities/[id]
- /admin/settlements
- /admin/settlements/[orderId]
- /admin/withdrawals
- /admin/withdrawals/[withdrawalId]

## Immediate Build Priority

1. D13-B customer disputes list/detail and report-problem replacement.
2. D13-F support/admin disputes queue/detail replacement.
3. D13-C customer returns/refunds list/detail.
4. D13-G admin returns.
5. D13-H finance refunds/holds/liabilities.
6. D13-D and D13-E supplier disputes/returns/refunds.
7. D13-I reseller liabilities and withdrawal-review visibility.
8. D13-J navigation and full browser QA.

