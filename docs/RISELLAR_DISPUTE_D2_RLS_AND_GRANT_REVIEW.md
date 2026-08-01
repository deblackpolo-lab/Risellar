# Risellar Dispute D2 RLS and Grant Review

## Default Posture

The D2 draft enables and forces RLS on:

- `public.order_disputes`
- `public.dispute_messages`
- `public.dispute_status_history`

It revokes all direct table privileges from:

- `public`
- `anon`
- `authenticated`

No direct browser `SELECT`, `INSERT`, `UPDATE`, or `DELETE` table access is granted.

## Read Access

Read access is through narrow safe RPCs only. The seven public safe-read RPC entry points are granted to `authenticated` because they enforce identity and role checks internally.

Internal role-resolution/helper functions are not granted directly to browser roles. They are called from the `SECURITY DEFINER` safe-read RPCs so raw profile, customer, supplier, reseller, admin, and finance-admin identifiers are not exposed as standalone callable functions.

Anonymous access is not granted for dispute reads.

## Mutation Access

D2 grants no mutation RPCs. Future mutations must be narrow and audited.

Direct table mutations remain blocked:

- no customer direct insert
- no supplier direct insert
- no reseller direct insert
- no admin direct table edit from browser
- no browser direct status-history insert

## Admin Authorization

D2 adds draft helpers:

- `current_dispute_admin_profile_id()`: active `support_staff`, `admin`, or `super_admin`.
- `current_dispute_finance_admin_profile_id()`: active `finance_staff` or `super_admin`.

This preserves finance/admin separation and does not rely on `profiles.primary_role = 'admin'` alone.

## Participant Boundaries

Customer:

- resolved through `current_dispute_customer_id()`
- requires active customer profile and customer row
- excludes active admin_staff profiles from customer mode

Supplier:

- resolved through `current_dispute_supplier_id()`
- requires active approved supplier owner
- excludes active admin_staff profiles from supplier mode

Reseller:

- resolved through `current_dispute_reseller_id()`
- requires active approved reseller
- excludes active admin_staff profiles from reseller mode

## SECURITY DEFINER Review

All D2 functions use:

`security definer set search_path = public`

The safe-read functions:

- resolve identity server-side
- validate filters
- cap pagination
- use explicit return columns
- avoid direct mutation
- avoid dynamic SQL
- avoid `SELECT *`

## Broad Grant Review

The migration does not grant direct table access to `authenticated`. It grants execute only on safe-read RPC entry points, not on internal helper functions.

No broad grant such as `grant all` or table-level `grant select` is introduced.

## Sensitive Field Review

Participant reads exclude:

- internal admin notes
- finance internals
- payout data
- settlement proof
- reseller wallet details
- raw evidence paths
- customer auth metadata
- private emails/phones outside approved order-safe fields

Admin detail includes finance context only for finance roles and only as high-level status.

## D3 Required Review

Before applying, D3 should dry-run and inspect:

- no direct table privileges to authenticated
- no missing `search_path`
- no `SELECT *`
- no unsafe `auth.uid()` assumptions
- no mutation of business tables
- old broad `disputes`/`returns` tables remain dormant
