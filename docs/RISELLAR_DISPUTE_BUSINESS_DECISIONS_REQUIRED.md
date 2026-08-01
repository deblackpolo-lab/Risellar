# Risellar Dispute Business Decisions Required

These decisions require user/business approval before implementation.

| # | Decision | Recommended Ghana-MVP default |
| --- | --- | --- |
| 1 | Customer dispute window after delivery | 72 hours for non-delivery; 48 hours for wrong/damaged/incomplete item. |
| 2 | Return window | 3 days after delivered for returnable categories. |
| 3 | Non-returnable product categories | Perishables and opened hygiene/beauty items are non-returnable unless wrong/damaged/defective. |
| 4 | Who pays return delivery | Supplier pays when supplier fault; customer pays for customer preference; platform/shared only by admin exception. |
| 5 | Customer cancellation before supplier acceptance | Allow before supplier acceptance or reservation expiry; release stock once. |
| 6 | Customer cancellation after supplier acceptance | Require support/admin review. |
| 7 | Reseller commission when supplier is at fault | Hold or reverse only if order refund/adjustment reduces commission and commission is traceable. |
| 8 | Commission already withdrawn | Do not silently reverse; create recoverable liability only if approved. |
| 9 | Platform goodwill refunds | Allow admin/super admin approval with explicit platform responsibility and audit. |
| 10 | Supplier refunds customer directly | Default yes for Pay on Delivery, with proof and admin verification. |
| 11 | Refund proof upload required | Require for supplier/platform manual refunds; text-only fallback only for initial internal QA. |
| 12 | Admin verification for every refund | Yes for MVP. |
| 13 | Partial refunds | Allow, but require reason and snapshot max enforcement. |
| 14 | Appeals in MVP | Defer to Phase 2 unless required by policy; plan one appeal per case. |
| 15 | Text-only evidence for initial release | Accept for first backend group; private upload can be separate phase. |
| 16 | Settlement verification while dispute is open | Block if dispute affects payment, delivery, item condition, or refund amount. |
| 17 | Return inspection authority | Supplier owner/inventory role for own supplier items; admin can verify/override with audit. |
| 18 | Whether order status should move to `disputed` | Default no; keep separate dispute state and use safe labels. |
| 19 | Whether customer must accept resolution | Default no for clear admin decisions; allow appeal window if approved. |
| 20 | Liability for delivery partner fault | Manual admin classification only until a delivery partner system exists. |

## Decisions That Block Refund Implementation

- Refund responsibility rules.
- Paid withdrawal recovery/liability rule.
- Whether partial refunds are supported in MVP.
- Whether evidence upload is mandatory.
- Whether platform can fund goodwill refunds.

## Decisions That Block Return Inventory Implementation

- Returnability by category.
- Who pays return delivery.
- Who can classify returned item condition.
- Whether sellable restock requires admin verification in addition to supplier inspection.
