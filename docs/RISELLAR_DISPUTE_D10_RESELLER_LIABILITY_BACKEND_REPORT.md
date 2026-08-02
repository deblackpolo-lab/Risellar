# Risellar Dispute D10 Reseller Liability Backend Report

## Summary

D10 adds backend-only controls for reseller liability and withdrawal recovery in the confirmed DEVELOPMENT Supabase project. It does not add UI, provider collection, payment/refund automation, stock mutation, settlement payout, commission payout, withdrawal payout, delivery mutation, notification sending, or production connectivity.

## Migrations

- `supabase/migrations/20260801200000_reseller_liability_and_recovery_core.sql`
- `supabase/migrations/20260801201000_reseller_liability_recovery_rpcs.sql`
- `supabase/migrations/20260801202000_fix_d10_non_finance_audit_actor.sql`
- `supabase/migrations/20260801203000_fix_d10_recovery_idempotency_and_notification_boundary.sql`

The forward patch migration preserves existing security boundaries and fixes two development verification issues: non-finance audit actor handling and same-key/different-commission future-offset idempotency conflict detection. It also normalizes withdrawal allocation audit actions so existing transactional email triggers do not enqueue new notification outbox rows for D10 allocation reservation events.

## RPC Boundary

D10 introduces controlled finance-only recovery behavior for paid-withdrawal liability records, manual recovery recording, future-earnings offset enablement, and allocation-safe withdrawal interaction. Paid withdrawals are not silently reversed. Recovery is tracked explicitly and idempotently, without guessing historical withdrawal-to-commission allocation.

## Development Verification

The D10 SQL suite passed with 49 rollback-scoped assertions. It verified finance authorization, immutable liability targets, duplicate recovery blocking, same-key/same-payload idempotency, same-key/different-payload conflicts, future offset disabled by default, finance-only offset enablement, direct table grant posture, no notification outbox change, and no order/payment/refund/stock side effects.

The D10 external concurrency harness passed all race scenarios, including same-key liability creation, same-scope different-key creation, two offsets against one liability, two withdrawals racing for one commission, and allocation dispute versus payout.

## Scope Protections

- No production Supabase connection was used.
- No service role was exposed in app or component code.
- No UI route, form, button, hook, or client fetcher was added.
- No provider collection, payment, refund, delivery, order, stock, settlement, commission payout, withdrawal payout, return, or notification mutation was added.
- `.env.local`, `.next`, `supabase/.temp`, and local dev logs remain ignored and were not staged.

## Status

D10 backend and regression verification are complete in development and safe to commit as backend/test/report work only.
