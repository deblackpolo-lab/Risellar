# Risellar Disputes D9 Finance Security and Privacy Review

## Authorization

Mutating D9 finance RPCs require active `admin_staff` membership with `finance_staff` or `super_admin`. General admin, support-only admin, customer, supplier, reseller, inactive finance staff, suspended profiles, anonymous, and direct table callers are blocked where applicable.

Support users can access only the dispute finance review summary, not full finance hold or adjustment ledgers.

## RLS and Grants

The new tables have RLS enabled and forced:

- `finance_holds`
- `finance_adjustments`
- `finance_actions`

Direct grants are revoked from `public`, `anon`, and `authenticated`. Access is through security-definer RPCs and safe reads only.

## Privacy

Audit metadata records state, amounts, public-safe flags, and action status without storing internal note bodies, payout details, raw account data, tokens, or credentials.

Supplier and reseller safe reads expose only role-appropriate summary fields.

## Side Effects

D9 verification confirmed:

- No stock mutation.
- No inventory movement.
- No notification outbox mutation from D9 finance actions.
- No provider payment/refund integration.
- No order status corruption beyond explicit settlement verification fixture.
- No paid withdrawal mutation.

## Security Scan Scope

Final scan checks include:

- `.env.local` ignored and unstaged.
- `supabase/.temp` ignored.
- `.next` ignored.
- `.codex-dev-server.*.log` ignored.
- No service role imports in `app` or `components`.
- No bearer tokens, passwords, API secrets, production data, or real credentials in docs/source.
- No D9 UI/client activation.
