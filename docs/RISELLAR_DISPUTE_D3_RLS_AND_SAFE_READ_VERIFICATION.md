# Risellar Dispute D3 RLS And Safe-Read Verification

## A. Verification Scope

D3 verified the applied core dispute schema and read-only safe RPCs in the confirmed DEVELOPMENT Supabase project.

In scope:

- schema object existence
- controlled-value constraints
- duplicate active-dispute protection
- idempotency protection
- RLS and grant posture
- `SECURITY DEFINER` posture
- customer/supplier/reseller/admin/finance read boundaries
- empty-state behavior
- fixture rollback and no business side effects

Out of scope:

- dispute-opening mutation RPCs
- customer dispute UI
- supplier response UI
- admin resolution actions
- returns
- refunds
- finance holds
- evidence uploads
- notifications
- order, payment, stock, settlement, commission, wallet, or withdrawal mutation

## B. RLS Result

RLS is enabled and forced on:

- `public.order_disputes`
- `public.dispute_messages`
- `public.dispute_status_history`

Direct table reads and writes are blocked for browser roles.

## C. Direct Grant Result

No direct table grants exist for:

- `PUBLIC`
- `anon`
- `authenticated`

Blocked direct operations verified:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

The migration does not grant direct table privileges for browser roles.

## D. Safe RPC Grant Result

Authenticated users can execute only the approved safe-read RPC entry points:

- `list_customer_disputes_safe`
- `get_customer_dispute_safe`
- `list_supplier_disputes_safe`
- `get_supplier_dispute_safe`
- `get_reseller_dispute_impact_safe`
- `list_admin_disputes_safe`
- `get_admin_dispute_safe`

Anonymous users cannot execute authenticated dispute safe-read RPCs.

Internal helper functions remain ungranted directly to browser roles.

## E. SECURITY DEFINER Result

All D2 safe-read and helper functions are `SECURITY DEFINER` with fixed:

`search_path=public`

Static and live checks found:

- no unnecessary dynamic SQL
- no `SELECT *`
- no caller-supplied profile/customer/supplier/reseller ID trust
- filter validation in list RPCs
- bounded pagination
- deterministic ordering
- active profile and active role checks
- active `admin_staff` authorization for admin access
- finance visibility restricted to `finance_staff` or `super_admin`

## F. Customer Boundary

Verified:

- customer A lists only customer A disputes
- customer A cannot retrieve customer B disputes
- customer B cannot retrieve customer A disputes
- customer detail hides internal admin notes
- customer detail hides supplier-private messages
- customer detail hides finance-only fields
- invalid customer status filters fail safely
- customer empty-state list returns zero safely
- unknown dispute detail returns zero safely
- malformed UUID input fails safely without private data

## G. Supplier Boundary

Verified:

- supplier A lists only disputes for supplier A order items
- supplier A cannot retrieve supplier B disputes
- supplier B cannot retrieve supplier A disputes
- supplier detail hides internal admin notes
- supplier detail hides reseller wallet/commission/settlement/withdrawal details
- supplier empty-state list returns zero safely

## H. Reseller Boundary

Verified:

- reseller A receives only dispute-impact summary for attributed orders
- reseller A cannot retrieve reseller B order impact by ID
- reseller empty-state impact returns zero safely
- reseller output hides complaint descriptions, messages, evidence, refund values, supplier private notes, and settlement details

## I. Admin And Finance Separation

Verified:

- active support/admin can list disputes and view approved non-finance context
- assigned-only admin filtering works
- invalid admin filters fail safely
- ordinary support/admin sees `financeReviewVisible=false`
- finance staff can view restricted finance-review indicators
- finance staff receives no mutation authority through D2
- inactive admin is blocked
- suspended profile is blocked

## J. Constraint And Idempotency Result

Verified invalid values are rejected for:

- dispute category
- reason code
- requested outcome
- status
- priority
- message visibility
- sender role
- actor role
- closed timestamp/status combinations
- short idempotency keys

Verified:

- duplicate active dispute is blocked
- duplicate status-history idempotency key is blocked

## K. Fixture Cleanup Result

The SQL boundary test uses `BEGIN` / `ROLLBACK`.

After test execution:

- `order_disputes`: 0 rows
- `dispute_messages`: 0 rows
- `dispute_status_history`: 0 rows

No permanent fixture rows remained.

## L. No Side Effects

Aggregate counts matched before and after the D3 boundary test for:

- orders
- order items
- products
- stock reservations
- settlements
- commissions
- withdrawals
- audit logs
- notification outbox
- notification provider events

No order, payment, delivery, stock, reservation, settlement, commission, wallet, withdrawal, refund, return, evidence, or notification state was changed by D3 verification.

## M. Assertion Result

- SQL boundary assertions: 51
- Passed: 51
- Failed: 0

D3 safe-read verification passed after the forward-only status-history idempotency fix.
