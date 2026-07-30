# Risellar Supplier Order Risk Register

| Risk | Likelihood | Impact | Prevention | Detection | Recovery |
| --- | --- | --- | --- | --- | --- |
| Supplier reads another supplier's order | Medium | High | Resolve supplier server-side; join through `order_items.supplier_id`; return no rows for unauthorized | Cross-supplier SQL boundary tests | Revoke grants, patch RPC predicate, audit affected reads |
| Customer data overexposure | Medium | High | Fixed return columns; only fulfilment snapshots | Field-denylist tests and browser QA | Patch read RPC and rotate/redact exposed logs if needed |
| Reseller private-contact leak | Medium | High | Do not join reseller profile/contact into supplier reads | Sensitive-field absence tests | Patch RPC and report exposure scope |
| Double stock release | Medium | High | Lock order, reservation, variant; release only `reserved`; idempotent terminal decision | Duplicate reject and concurrency tests | Correct counters through audited admin repair plan |
| Reserved stock becomes negative | Low | High | Check reserved quantity before decrement; preserve variant constraint | Boundary tests and DB constraints | Roll back failed transaction; audited correction if already committed |
| Accept/reject race | Medium | High | `FOR UPDATE` order lock and one terminal decision | Two-session concurrency test | Treat loser as idempotent/not-actionable |
| Expired reservation accepted | Medium | Medium | Check `expires_at > now()` before accept | Expiry assertion | Block accept and require customer/admin restart path |
| Supplier changes commercial snapshot | Low | High | Inputs exclude price/margin fields; no direct write grants | Tests search for forbidden inputs and direct mutation | Revoke grants, patch RPC, audit affected rows |
| Supplier marks payment collected early | Low | High | Decision RPC does not touch payment fields | Side-effect assertions | Patch RPC and reverse unauthorized state through audited flow |
| Supplier action bypasses ownership | Medium | High | Server-side supplier resolver and order-item ownership checks | Other-supplier decision tests | Patch predicate and revoke execute until fixed |
| Rejected order still appears confirmed | Low | Medium | Single source of truth; customer-safe read labels updated | UI and RPC status assertions | Patch label/read contract |
| Customer status not updated | Medium | Medium | Extend `get_customer_order_safe` labels when enum added | Customer read tests after supplier action | Add read-contract patch migration |
| Audit gap | Medium | Medium | Required audit events in both decision RPCs | Audit assertions | Patch RPC to write missing audit events |
| Stale UI after idempotent retry | Medium | Low | Return current safe summary after duplicate action | Browser retry QA | Refresh from RPC result and show stable terminal status |

## Highest-Risk Areas

The top risks are cross-supplier leakage, double stock release, and unauthorized status/payment mutation. These require SQL boundary tests before browser UI work.
