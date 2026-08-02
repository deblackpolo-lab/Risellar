# Risellar Dispute D12 End-to-End QA Report

Date: 2026-08-02

## Summary

D12 verified the disputes, returns, refunds, finance holds, reseller liability, withdrawal recovery, settlement, withdrawal, finance-history, and notification backend boundaries against the confirmed DEVELOPMENT Risellar Supabase project. The SQL regression batch passed after one development-only test-harness repair in `scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql`.

The module is not MVP-release ready as a full browser product. Several dispute/return/refund/support routes still render preserved mock-only Phase 13 UI, no active support/dispute-admin or super-admin QA account bucket was available in development, and the deployed Vercel home page still presents a Phase 1 design-shell message. These are release blockers, not backend security regressions.

## Baseline

- Branch: `main`
- Baseline HEAD before D12 changes: `bb144e01fc8429f9df8528c1aba8fbf10021fd4b`
- `origin/main`: matched baseline HEAD before D12 changes
- Working tree before D12 change: clean
- Production URL checked: `https://risellar.vercel.app`
- Linked database: confirmed DEVELOPMENT Risellar project by linked migration alignment
- Production Supabase: not connected

## Backend Verification

Passed DEVELOPMENT SQL suites:

- Dispute core schema and safe reads: passed after fixture-scope harness repair
- Customer dispute open/respond: passed
- Supplier item scoping: passed
- Supplier dispute response: passed
- Admin investigation and non-financial resolution: passed
- Return workflow: passed
- Refund workflow: passed
- Finance holds and settlement interaction: passed
- Reseller liability and withdrawal recovery: passed
- Dispute notifications: passed
- Admin settlement verification: passed
- Reseller withdrawal: passed
- Finance-history safe reads: passed

Passed external concurrency runners:

- D6 admin investigation concurrency: 12 scenarios, 85 invariant checks
- D7 return workflow concurrency: all scenarios, side-effect checks, and cleanup passed
- D8 refund workflow concurrency: all scenarios, side-effect checks, and cleanup passed
- D9 finance hold concurrency: all scenarios passed with extended timeout
- D10 reseller liability/withdrawal recovery concurrency: all scenarios passed
- D11 notification concurrency: 10 scenarios, 13 invariant checks

## Browser/Production Result

Production responded HTTP 200 for `/`, `/sign-in`, `/sign-up`, and the tested public shop unavailable route. API blocking checks passed for notification processor and Resend webhook unsigned/unauthorized calls.

Production blocker: the home page still displays a Phase 1 design foundation shell stating that role routes and backend routes are not built. Signed-out protected route HEAD checks returned safe non-content responses, but they did not prove the expected Clerk redirect behavior for full production activation.

## D12 Decision

Classification: **B. Backend and partial UI complete, more UI required.**

The backend is ready for the next UI activation planning pass. The dispute/return/refund system is not MVP-release ready until live UI routes replace mock-only Phase 13 screens, a real support/dispute-admin QA account is available, and the production deployment is verified against the latest activated application surface.
