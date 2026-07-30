# Risellar Checkout Phase C Development Order Data Preservation Plan

## Summary

This plan covers the 23 DEVELOPMENT `orders` rows that carry the unapproved Claude-era `orders.expires_at` value. It is planning-only and does not update or delete any rows.

## Aggregate Findings

Read-only aggregate query results:

- 23 orders have `expires_at` populated.
- All 23 are `order_status = placed_pending_confirmation`.
- All 23 are `customer_confirmation_status = pending`.
- 23 are expired relative to database `now()`.
- 0 have future `expires_at`.
- Minimum `expires_at`: `2026-07-24 20:44:56.639907+00`.
- Maximum `expires_at`: `2026-07-26 15:03:43.521023+00`.
- 0 have `confirmed_at` populated.
- 0 have `confirmation_source` populated.
- 0 have preparation/delivery/person fields populated.
- 0 are linked to stock reservations.
- 4 orders are linked to order items.
- 0 are linked to delivery quotes.
- 0 order items are linked to commissions.
- 0 are linked to settlements.

Tables checked:

- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `commissions`
- `settlements`

The `payments` and `withdrawal_requests` tables were not present in this development schema.

## Classification

Classification: useful development QA rows needing aggregate preservation, not production-looking data.

Reason:

- The project is confirmed DEVELOPMENT.
- The rows are in a pending/expired state.
- They have no payment, delivery, settlement, commission, stock-reservation, confirmation, or preparation side effects.
- Some rows have order items, so the records may still be useful as QA state/evidence.

No private row details were exposed or recorded.

## Expires_at Strategy Options

### Option A - Preserve `expires_at` as an approved generic order-expiry field

Data impact:

- Keeps all 23 values.

Complexity:

- Low, but it imports Claude-era confirmation semantics into approved schema unless a new spec defines order expiry.

Future consistency:

- Clean environments would need `orders.expires_at` added as approved schema, which is not currently in the Phase C planning target.

Recommendation:

- Do not choose now.

### Option B - Copy `expires_at` into a new approved field, then remove old column

Data impact:

- Preserves values under new semantics.

Complexity:

- Medium; requires a clearly approved new field.

Future consistency:

- Good only if Phase C explicitly needs a new order/reservation expiry field.

Recommendation:

- Do not choose now. Current approved design already uses `stock_reservations.expires_at` for reservation expiry.

### Option C - Archive aggregate evidence, then remove the column

Data impact:

- Loses per-row old expiry values from the active schema after backup.

Complexity:

- Medium; requires backup and a guarded cleanup migration.

Future consistency:

- Strong. Clean and contaminated environments converge without preserving unapproved order expiry semantics.

Recommendation:

- Recommended.

### Option D - Preserve column temporarily but remove old functions/indexes

Data impact:

- Keeps the 23 values temporarily.

Complexity:

- Low immediate risk, but prolongs schema drift.

Future consistency:

- Weaker. Existing DEVELOPMENT would keep a column absent from clean environments unless later cleaned.

Recommendation:

- Acceptable temporary fallback if the team wants more time to inspect QA orders without exposing row details.

### Option E - Replace the DEVELOPMENT project

Data impact:

- Discards the current QA state.

Complexity:

- Operationally higher due Clerk/Supabase re-linking and QA data recreation.

Future consistency:

- Strongest.

Recommendation:

- Fallback only.

## Selected Strategy

Recommended strategy: Option C - archive aggregate evidence, keep a development backup outside Git, then remove `orders.expires_at` through the approved cleanup migration.

Required condition:

- Revise the uncommitted Phase C Group 2 migration so it does not write `orders.expires_at`; reservation expiry should remain on `stock_reservations.expires_at`.

## Backup Requirements

Before future cleanup apply:

- Development database backup/export outside Git.
- Schema-only snapshot.
- Aggregate count snapshot from this plan plus a fresh pre-apply count.
- Migration-history export.
- Confirmation that production is not connected.
- Git checkpoint commit containing tombstone/cleanup design and migration files.

## Rollback Strategy

If cleanup behaves unexpectedly:

- Restore the development database backup.
- Do not recreate Claude-era RPCs through source migrations.
- Re-evaluate whether project rebuild is safer.

## Future Validation

After cleanup:

- `orders.expires_at` should be absent if Option C is approved.
- `stock_reservations.expires_at` should remain.
- No order/payment/stock/delivery/commission/settlement/withdrawal side effects should be created.
- Existing order row count should remain unchanged unless a separately approved data cleanup explicitly changes it.
