# Risellar D13-A Role Guard Matrix

Date: 2026-08-02

## Guard Principles

- Route guards are necessary but not sufficient.
- Client-side checks are never the only protection.
- Pages must call server actions or server-only helpers.
- Server code must use the signed-in user context and role-specific RPCs.
- No page or client component may use a service-role client.
- Super-admin access must still flow through controlled RPCs with state, cap, idempotency, and audit checks.

## Route Guard Matrix

| Area | Roles allowed | Data scope | Mutation authority | Blocked roles |
| --- | --- | --- | --- | --- |
| Customer disputes | active customer | Own dispute/order records | Customer open/respond RPCs | anonymous, other customers, supplier, reseller, admin without customer ownership |
| Customer returns | active customer | Own return/order records | Customer return/request/transit RPCs | anonymous, other customers, supplier, reseller, admin direct table mutation |
| Customer refunds | active customer | Own refund records | Customer confirm-received RPC only | anonymous, other customers, supplier, reseller, support finance mutations |
| Supplier disputes | active approved supplier_owner | Own supplier item disputes | Supplier response RPC | anonymous, customer, reseller, other supplier, finance-only |
| Supplier returns | active approved supplier_owner | Own return item records | Supplier receipt/condition RPCs | anonymous, customer, reseller, other supplier |
| Supplier refunds | active approved supplier_owner | Own supplier refund obligations | Supplier report-sent RPC only | anonymous, customer, reseller, other supplier |
| Reseller liabilities | active reseller | Own liability and commission-impact records | No direct finance mutation | anonymous, customer, supplier, other reseller, support-only finance mutation |
| Support disputes | active support_staff, admin, or super_admin | Support-safe dispute queue/details | D6 support RPCs only | anonymous, customer, supplier, reseller, finance_staff-only |
| Admin returns | active support_staff, admin, or super_admin | Support-safe return queue/details | Return admin RPCs only | anonymous, customer, supplier, reseller, finance_staff-only unless super_admin |
| Finance refunds | active finance_staff or super_admin | Finance-safe refund records | Refund finance RPCs only | anonymous, customer, supplier, reseller, support_staff-only |
| Finance holds | active finance_staff or super_admin | Finance-safe hold records | Finance hold RPCs only | anonymous, customer, supplier, reseller, support_staff-only |
| Finance liabilities | active finance_staff or super_admin | Finance-safe liability records | Liability finance RPCs only | anonymous, customer, supplier, reseller, support_staff-only |
| Withdrawals review | active finance_staff or super_admin | Withdrawal review records | Withdrawal payout RPCs only | anonymous, customer, supplier, reseller, support_staff-only |

## Current Route Boundary Observation

The current protected route policy has broad role buckets for /customer, /supplier, /reseller, and /admin. Admin subroutes already contain more specific finance access checks for finance dashboard, settlement, and withdrawal routes.

D13 implementation must add route/action-level checks for:

- support_staff versus finance_staff separation
- finance_staff versus support-only separation
- super_admin routed through the same RPC state machines
- inactive or deleted admin_staff rows blocked
- suspended profiles blocked safely

## Admin Staff Model

Public admin authority must come from active public.admin_staff rows, not profiles.primary_role alone.

Known role buckets:

- support_staff: support/dispute action authority
- finance_staff: refund, hold, liability, settlement, and withdrawal finance authority
- admin: broad operational admin where existing helpers allow it
- super_admin: controlled exceptional authority, still RPC-bound

## D13 Guard Test Requirements

- Customer cannot read or mutate another customer's dispute, return, refund, or address.
- Supplier cannot read or mutate another supplier's item dispute, return, or refund.
- Reseller cannot read another reseller's liability, wallet, withdrawal, or commission impact.
- Support_staff cannot approve refunds, create finance holds, verify refunds, apply liabilities, or mark withdrawals paid.
- Finance_staff cannot perform support investigation mutations unless explicitly granted by support role.
- Super_admin cannot bypass caps, invalid states, idempotency keys, or audit logging.
- Inactive/suspended users receive safe redirects or not-found states without content flash.

