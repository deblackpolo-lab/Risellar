# Risellar Dispute D5-A Concurrency Report

## Summary

D5-A protects dispute creation with target-aware advisory locks plus a target-aware partial unique index.

## Runtime Protections

The customer-open RPC locks both:

- opener/idempotency key
- opener/order/scope/supplier/item/category/reason/outcome fingerprint

The active duplicate index includes:

- `order_id`
- `opened_by_profile_id`
- `scope_type`
- `affected_supplier_id`
- `affected_order_item_id`
- `dispute_category`
- `reason_code`
- `requested_outcome`

This lets separate supplier and item cases coexist while blocking exact active duplicates.

## Verified In Development

The rollback-scoped D5-A SQL suite verified:

- exact target retry returns the existing dispute
- same idempotency key with a different item conflicts
- exact active duplicate is blocked
- separate item disputes are allowed
- separate supplier disputes are allowed
- supplier safe reads remain isolated after second-supplier case creation
- no business-side effects occur

## Limitation

No separate two-session dispute concurrency runner exists in this repository. The D5-A result is therefore database-protected and invariant-tested, not a new independent two-session race harness.

## Result

The D5-A database constraints and RPC locks are sufficient for the supplier/item scoping foundation. Supplier response implementation may build on this model.
