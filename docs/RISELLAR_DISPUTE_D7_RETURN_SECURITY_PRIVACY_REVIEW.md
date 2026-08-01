# Risellar Dispute D7 Return Security Privacy Review

## Summary

D7 keeps returns server-controlled and role-scoped. All mutations run through narrow audited RPCs. No client-side or UI path was added.

## Access Model

Customer:

- can request a return only for their own eligible item-scoped dispute
- can mark only their own approved physical return as in transit
- sees customer-safe return fields only

Supplier owner:

- can receive and inspect only returns for their own active approved supplier
- cannot act through `supplier_inventory_manager`
- cannot accept, decline, complete, or approve returns

Support/admin/super admin:

- can approve/reject and final-review returns through active `admin_staff`
- finance-only staff cannot use D7 review RPCs

Reseller:

- can read only a safe return-impact label
- cannot see customer notes, supplier notes, admin notes, refund amounts, payout data, or commission details

## Privacy Controls

Safe reads omit:

- supplier private contact/payout data
- admin internal notes outside admin reads
- customer account metadata
- refund/settlement/commission/wallet/withdrawal details
- stock internals beyond safe inventory outcome recommendation

Audit rows intentionally store controlled status/action metadata only. Note bodies are stripped from audit `after_data`.

## RLS And Grants

`order_item_returns` and `return_actions` have RLS enabled and forced. Direct grants are revoked from `public`, `anon`, and `authenticated`.

Browser roles receive execute grants only for controlled RPCs. No service-role path was added to app/components.

## Secret And Scope Review

The D7 files contain no real Clerk/Supabase/service-role values, JWTs, cookies, passwords, bearer tokens, private row identifiers, or production data.

The only email-like values are `.example.test` fake fixture addresses inside rollback/dev-only scripts.

## Side Effects

Verified no changes to:

- orders
- order items
- stock reservations
- product variant stock counters
- inventory movements
- delivery arrangements
- supplier payment reports
- settlements
- commissions
- withdrawals
- legacy `returns`
- notification outbox
- provider events

## Production Boundary

D7 was applied only to the confirmed DEVELOPMENT project. Production remains blocked until a separate production review and approval.
