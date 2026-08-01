# Risellar Dispute D6 Admin Authorization Security Review

## Authority Source

D6 support/admin authority uses active `public.admin_staff` rows, not `profiles.primary_role` alone.

Allowed support mutation roles:

- `support_staff`
- `admin`
- `super_admin`

Blocked:

- anonymous
- customer
- supplier
- reseller
- inactive admin staff
- suspended admin profile
- finance_staff-only profile
- profile with no active `admin_staff` row

## Finance Separation

`finance_staff` is intentionally not accepted by the D6 support mutation helper. Finance-only accounts can continue to use separately approved finance visibility paths, but cannot assign, request information, change support statuses, record non-financial resolutions, or close cases through D6 RPCs.

## Direct Grants And RLS

Browser roles have no direct table grants for:

- `order_disputes`
- `dispute_messages`
- `dispute_status_history`
- `dispute_admin_actions`

D6 grants only `execute` on the explicit RPCs to `authenticated`. RLS remains enabled and forced on dispute tables. The new `dispute_admin_actions` table has RLS enabled and forced and no direct browser grants.

## Privacy Checks

Public admin messages use targeted visibility:

- customer request: `customer_and_admin`
- supplier request: `supplier_and_admin`
- public status/closure notes: `all_case_participants`
- internal notes: `admin_only`

Customer and supplier safe reads do not show `admin_only` notes. Reseller safe read remains impact-only.

Audit metadata records safe facts only. It does not store message bodies, internal notes, contact details, payout data, evidence paths, refund values, settlement values, commission values, wallet values, or secrets.

## Static Security Review

Reviewed for:

- no generic `update_dispute` RPC
- no arbitrary status edit RPC
- no caller-supplied actor authority
- no `profiles.primary_role`-only admin gate
- no finance_staff overreach
- no direct browser grants
- no service role exposure in app/components
- no settlement, commission, wallet, withdrawal, payment, stock, return, refund, or notification mutation in D6 SQL
- no support mutation authority for finance_staff-only profiles
- no concurrent participant response after terminal closure
- no concurrent conflicting non-financial resolution overwrite

Result: no D6 scope violations found.

## External Concurrency Authorization Result

The external two-session D6 harness used simulated authenticated support/customer/supplier sessions in separate database backend sessions. It verified that:

- same-key admin retries are idempotent without duplicate action rows
- competing support actions remain serialized and audited
- supplier response races still respect affected-supplier scope
- late customer and supplier responses are blocked after terminal closure
- finance-only staff remain excluded by the main SQL boundary suite

The harness used temporary development coordination objects only and dropped them after cleanup. No application table grants or RLS policies were broadened.
