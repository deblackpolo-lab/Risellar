# Risellar D13-A QA Account Setup Report

Date: 2026-08-02

## Summary

D13-A audited the DEVELOPMENT role population without printing account identifiers, emails, profile IDs, Clerk IDs, tokens, cookies, project refs, or environment values.

The development database contains active customer, supplier_owner, reseller, and finance_staff role buckets. It does not currently expose an active support_staff, admin, or super_admin bucket in public.admin_staff through the safe aggregate audit.

No QA account was created in this phase because no verified Clerk primary email was supplied for a support/dispute-admin or super-admin browser account, and creating a database-only authority without a verified Clerk login would violate the D13-A requirements.

## Development Project Confirmation

- Branch: main
- Baseline commit: f18ad3dd8ea82997d056aa6f5d33eee4b9d6408c
- Supabase CLI: present
- Linked Supabase project: confirmed development Risellar by prior migration alignment and safe linked queries
- Vercel production: https://risellar.vercel.app returned HTTP 200
- .env.local: present, ignored, and not staged
- supabase/.temp: ignored

No production Supabase connection, migration repair, or destructive command was used.

## QA Role Readiness Matrix

| Role | Account exists | Active status | Verified Clerk primary email | Profile mapping valid | Role mapping valid | admin_staff valid | Ready for browser QA |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Customer A | Yes | Yes | Previously QA-verified | Yes | Yes | Not required | Yes |
| Customer B | Yes | Yes | Not proven in this pass | Yes | Yes | Not required | Partially, needs browser login proof |
| Supplier A | Yes | Yes | Previously QA-verified | Yes | Yes | Not required | Yes |
| Supplier B | Yes | Yes | Not proven in this pass | Yes | Yes | Not required | Partially, needs browser login proof |
| Reseller A | Yes | Yes | Previously QA-verified | Yes | Yes | Not required | Yes |
| Reseller B | Yes | Yes | Not proven in this pass | Yes | Yes | Not required | Partially, needs browser login proof |
| Support/dispute-admin | No active bucket found | Blocked | Not proven | Blocked | Blocked | No active support_staff bucket found | No |
| Finance admin | Yes | Yes | Previously QA-verified | Yes | Yes | Active finance_staff bucket found | Yes |
| Super admin | No active bucket found | Blocked | Not proven | Blocked | Blocked | No active super_admin bucket found | No |
| Inactive admin | Not proven | Not proven | Not proven | Not proven | Not proven | Not proven | No |
| Suspended customer | Not proven | Not proven | Not proven | Not proven | Not proven | Not required | No |
| Suspended supplier | Not proven | Not proven | Not proven | Not proven | Not proven | Not required | No |
| Unapproved supplier | Not proven | Not proven | Not proven | Not proven | Not proven | Not required | No |

## Support/Dispute-Admin Result

Support/dispute-admin browser QA remains blocked.

Safe aggregate development audit found no active support_staff admin_staff bucket. The existing backend model recognizes support authority through public.admin_staff roles including support_staff, admin, or super_admin for dispute support functions, but D13-A requires a real Clerk account with verified primary email before browser readiness can be claimed.

No database-only support account was created.

## Support Permission Boundary

Planned support/dispute-admin permissions:

- May list and open support-scoped disputes through support/admin safe-read RPCs.
- May perform D6 non-financial support actions through audited RPCs.
- Must not approve monetary refunds.
- Must not create or release finance holds.
- Must not verify refunds.
- Must not apply reseller recoveries.
- Must not mark withdrawals paid.
- Must not record payouts.

## Finance Admin Result

Finance admin coverage exists through active finance_staff admin_staff rows. Existing finance routes should continue using finance-specific helpers such as settlement, withdrawal, finance dashboard, refund, finance hold, and liability RPCs.

## Super-Admin Result

Super-admin browser QA remains blocked.

Safe aggregate development audit found no active super_admin admin_staff bucket. D13-A did not create a database-only super-admin row because the requirement demands a usable verified Clerk login. Super admin must still use controlled RPCs and must not bypass refund caps, idempotency, finance holds, RLS, or audit logging.

## External Blocker

To complete real browser-ready support and super-admin setup, the project needs either:

1. A verified Clerk development support/dispute-admin account email and approval to bootstrap only that account into admin_staff as support_staff.
2. A verified Clerk development super-admin account email and approval to bootstrap only that account into admin_staff as super_admin.

The bootstrap must keep profiles.primary_role as a non-admin browser role and must grant authority only through public.admin_staff.

## Commands And Results

- git status --short: clean at precheck.
- git branch --show-current: main.
- git rev-parse HEAD: f18ad3dd8ea82997d056aa6f5d33eee4b9d6408c.
- git diff --check: clean.
- curl https://risellar.vercel.app: HTTP 200.
- npx supabase migration list --linked: local and remote migrations aligned.
- npx supabase db query --linked aggregate role audit: customer, reseller, supplier_owner, and finance_staff buckets present; no active support_staff or super_admin bucket returned.
- npm test: passed, 48 test files and 292 tests.
- npm run lint: passed.
- npm run build: passed.
- npm run typecheck: passed.
- npx tsc --noEmit: passed.

## Security Notes

- No secrets or identifiers were printed.
- No .env.local values were printed.
- No production data was used.
- No emails were sent.
- No business records were modified.
- No migrations were created or applied.
