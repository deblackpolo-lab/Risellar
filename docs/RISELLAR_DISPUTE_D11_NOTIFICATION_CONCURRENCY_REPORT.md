# Risellar Disputes D11 Notification Concurrency Report

## Summary

The D11 concurrency harness verifies durable notification deduplication across independent database sessions. It exercises outbox event-key uniqueness, processor claim locking, webhook replay idempotency, rollback safety, and recipient isolation.

## Harness

Script:

- `scripts/rpc/dispute-notifications-d11-concurrency-dev-only.mjs`

Result:

- 10 concurrency scenarios passed
- 13 invariant checks passed

## Scenarios Covered

- same audit event processed twice creates one outbox row
- same logical business retry creates one notification
- two valid dispute responses create separate notifications without event-key collision
- refund verification retry creates one customer notification
- finance hold retry keeps one notification per intended role
- withdrawal blocked retry keeps reseller and finance events distinct
- concurrent processor claims do not duplicate rows
- webhook replay stores one provider event
- rolled-back notification work creates no orphan outbox row
- multi-role recipient isolation avoids unrelated recipient profiles

## Notes

The harness pins its own processor-claim fixture rows to older timestamps so it does not claim unrelated pending development notifications. Cleanup removes only harness-owned outbox/provider/profile rows and clears only harness-owned processing locks.

No business tables are mutated by the D11 concurrency harness except rollback-scoped or cleaned test fixtures.
