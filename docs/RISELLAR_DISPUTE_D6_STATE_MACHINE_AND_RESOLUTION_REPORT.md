# Risellar Dispute D6 State Machine And Resolution Report

## Controlled Status RPC

`admin_change_dispute_status(...)` allows only:

- `open`
- `awaiting_customer`
- `awaiting_supplier`
- `under_review`
- `return_review`
- `refund_review`
- `rejected`
- `cancelled`

It cannot set `resolved_customer`, `resolved_supplier`, `partially_resolved`, or `closed`.

## Transition Matrix

| From | To |
| --- | --- |
| `open` | `awaiting_customer`, `awaiting_supplier`, `under_review`, `rejected`, `cancelled` |
| `awaiting_customer` | `under_review`, `awaiting_supplier`, `rejected`, `cancelled` |
| `awaiting_supplier` | `under_review`, `awaiting_customer`, `rejected`, `cancelled` |
| `under_review` | `awaiting_customer`, `awaiting_supplier`, `return_review`, `refund_review`, `rejected`, `cancelled` |
| `return_review` | `awaiting_customer`, `awaiting_supplier`, `under_review`, `rejected`, `cancelled` |
| `refund_review` | `awaiting_customer`, `awaiting_supplier`, `under_review`, `rejected`, `cancelled` |

Supplier-targeted information requests and `awaiting_supplier` transitions require an explicit affected supplier. Ambiguous multi-supplier order-wide supplier requests are blocked.

## Resolution Mapping

| Resolution code | D6 status |
| --- | --- |
| `customer_favoured` | `resolved_customer` |
| `supplier_favoured` | `resolved_supplier` |
| `partial_resolution` | `partially_resolved` |
| `replacement_agreed` | `partially_resolved` |
| `redelivery_agreed` | `partially_resolved` |
| `no_action` | `resolved_supplier` |
| `case_rejected` | `rejected` |
| `case_cancelled` | `cancelled` |
| `accounting_correction_required` | `partially_resolved` |
| `return_process_required` | `partially_resolved` |
| `refund_review_required` | `partially_resolved` |

Codes that mention replacement, redelivery, accounting, return, or refund record intent only. They do not execute those flows.

## Closure

`admin_close_dispute(...)` can close only `resolved_customer`, `resolved_supplier`, `partially_resolved`, `rejected`, and `cancelled`.

D6 does not implement reopening.

## Concurrency Verification

The external D6 harness verified the state machine under independent concurrent sessions:

- competing `return_review` and `refund_review` transitions from `under_review` produced one winner and one safe blocked result
- competing customer-favoured and supplier-favoured resolutions produced one winner and no silent overwrite
- resolution racing closure never produced a closed dispute without a prior valid resolution
- closure racing customer/supplier responses blocked late participant responses after terminal closure
- same-key resolution retry produced one resolution action and one status-history row

No duplicate transition histories, duplicate resolution audits, orphan messages, or inconsistent action-required flags were observed.
