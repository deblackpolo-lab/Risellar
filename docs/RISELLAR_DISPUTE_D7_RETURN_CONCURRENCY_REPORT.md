# Risellar Dispute D7 Return Concurrency Report

## Summary

D7 uses transaction-scoped advisory locks plus row locks for return workflow mutations.

Implemented external harness:

- `scripts/rpc/return-workflow-d7-concurrency-dev-only.mjs`

The harness runs independent `npx supabase db query --linked` child processes for each race and disables Supabase CLI telemetry in child environments to avoid local telemetry-file races on Windows.

## Scenarios Passed

The harness passed:

- same customer, same dispute, same request key
- duplicate active return requests with different keys
- admin approve versus reject
- customer in-transit versus admin reject
- supplier received versus admin reject
- two suppliers attempting receipt
- two supplier condition reports
- admin accept versus decline
- admin complete versus supplier condition report
- return request versus dispute closure
- return acceptance versus future refund-review status change

## Invariants

Verified:

- independent backend sessions were used
- active-return uniqueness held
- same-key retries did not duplicate actions
- conflicting review/final decisions produced one winner
- wrong supplier was blocked
- late invalid transitions were blocked safely
- side-effect tables did not change beyond isolated test fixtures
- cleanup removed harness fixtures

## Regression Note

The existing D6 concurrency harness also passed after rerunning with telemetry disabled in the parent environment. The first D6 retry failed only due to Supabase CLI telemetry file contention, not database behavior.
