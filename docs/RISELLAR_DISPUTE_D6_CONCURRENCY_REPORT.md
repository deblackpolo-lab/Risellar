# Risellar Dispute D6 Concurrency Report

## Implemented Controls

D6 mutations use transaction-scoped advisory locks and row locks:

- assignment locks by actor, dispute, and idempotency key
- information requests lock by actor, dispute, and idempotency key
- status transitions lock by actor, dispute, and idempotency key
- resolution recording locks by dispute
- closure locks by dispute

Each D6 mutation uses durable idempotency through `public.dispute_admin_actions`, scoped by dispute ID, actor profile, action type, and idempotency key.

Same-key/same-payload retries return existing results. Same-key/different-payload attempts raise `IDEMPOTENCY_CONFLICT`.

## Verified In Development SQL Suite

The D6 boundary suite verified:

- assignment retry creates one action log and one audit row
- assignment same-key/different-target conflict
- information-request retry creates no duplicate message/history/audit
- status-transition retry creates no duplicate transition
- resolution retry creates no duplicate resolution action/history/audit
- resolution same-key/different-payload conflict
- closure retry creates no duplicate closure/history/audit
- terminal/closed states block inappropriate actions

Result: 103 assertions passed.

## External Two-Session Harness

Added and ran:

- `scripts/rpc/admin-dispute-d6-concurrency-dev-only.mjs`

The harness uses two independent `npx supabase db query --linked` child processes for every race scenario. Each process opens its own database backend session, records a distinct backend PID, waits inside its transaction, executes the target RPC, and records safe result codes only. Verification asserts distinct backend sessions and overlapping call windows for each scenario.

Result: 12 scenarios passed with 61 invariant checks.

## Race Results

| Scenario | Starting state | Competing actions | Observed result |
| --- | --- | --- | --- |
| Same-key assignment | `open` | two identical `admin_assign_dispute` calls | one action/audit row, both calls compatible |
| Competing assignees | `open` | two different authorised assignees | serialized last-committed assignment, two audited actions, final assignee authorised |
| Customer request vs response | `open` | customer information request and customer response | request and response preserved, final flags consistent |
| Supplier request vs response | `open` | supplier information request and supplier response | request and response preserved, supplier scope enforced, final flags consistent |
| Competing status transitions | `under_review` | `return_review` vs `refund_review` | one transition won, the other received a safe blocked result |
| Competing resolutions | `under_review` | customer-favoured vs supplier-favoured | one resolution won, no silent overwrite |
| Resolution vs closure | `under_review` | resolution and close | no closed dispute without prior resolution |
| Closure vs customer response | `resolved_customer` | close and customer response | closure won, late response blocked |
| Closure vs supplier response | `resolved_supplier` | close and supplier response | closure won, late supplier response blocked |
| Same-key information request | `open` | two identical customer requests | one public request, one internal note, one history row |
| Different-key information requests | `open` | customer request and supplier request | both distinct requests preserved, final flags consistent |
| Same-key resolution retry | `under_review` | two identical resolutions | one resolution/action/history set, both calls compatible |

## Cleanup And Side Effects

The harness created isolated DEVELOPMENT-only profiles, admin staff, supplier, reseller, product/listing, order/item, and dispute fixtures under one run marker. It removed all fixture rows, D6 messages, status history, audit rows, and admin idempotency rows after verification.

After cleanup, the harness verified no count changes for orders, order items, stock reservations, delivery arrangements, supplier payment reports, settlements, commissions, withdrawals, returns, notification outbox, or notification provider events.

No return, refund, finance hold, settlement, commission, wallet, withdrawal, stock, reservation, order-status, payment-status, notification, or UI behavior was introduced.
