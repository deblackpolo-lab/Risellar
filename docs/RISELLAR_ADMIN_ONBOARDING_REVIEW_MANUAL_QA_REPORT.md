# Risellar Admin Onboarding Review Manual QA Report

## A. Admin Login/Access Result

The development admin test profile was bootstrapped through `public.admin_staff` before this QA:

- Admin test profile id: `50c02a70-be36-4d58-a206-103b44da7aef`
- Masked admin email: `ex***@gmail.com`
- `profiles.primary_role`: `customer`
- Active `admin_staff.admin_role`: `admin`
- `public.has_admin_role('admin')`: `true` under a safe simulated user-context claim

Important limitation: Codex did not have a callable browser-control surface that could reuse the in-app browser's signed-in Clerk session. Therefore, signed-in UI clicking was not directly automated by Codex. The admin route build, auth protection, pending data visibility, and audited RPC approve/reject behavior were verified. The actual browser click-through should still be spot-checked manually using the signed-in admin test account.

## B. Pending Request Visibility

Read-only development Supabase verification found two pending development requests before review:

| Request | Status Before | Requested Role | Requester | Business Name | Contact | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `746fa658-61c7-42fb-b329-19d179023e9b` | `pending` | `reseller` | `de***@gmail.com` | `Dev Native QA Reseller native-qa-reseller-1784336427244` | provided | provided |
| `3ba07930-0e7d-4d34-ad02-9df00b818586` | `pending` | `supplier_owner` | `de***@gmail.com` | `Dev Native QA Supplier native-qa-supplier-1784336521335` | provided | provided |

Both requests belonged to the same customer test profile. To avoid approving two role changes for the same profile, the supplier request was rejected first and the reseller request was approved second.

## C. Approval Result

The reseller request was approved through the audited `review_role_onboarding_request` RPC under the confirmed admin test user context.

- Request id: `746fa658-61c7-42fb-b329-19d179023e9b`
- Requested role: `reseller`
- Final status: `approved`
- `reviewed_by`: admin test profile
- `reviewed_at`: set
- Requester final role: `reseller`

## D. Rejection Result

The supplier request was rejected through the audited `review_role_onboarding_request` RPC under the confirmed admin test user context.

- Request id: `3ba07930-0e7d-4d34-ad02-9df00b818586`
- Requested role: `supplier_owner`
- Final status: `rejected`
- `reviewed_by`: admin test profile
- `reviewed_at`: set
- Requester final role remained `reseller` after the approved reseller request; it did not become `supplier_owner`.

## E. Supabase Row Verification

Read-only verification after review confirmed:

| Request | Final Status | reviewed_by Admin | reviewed_at Set | Audit Logs | Requester Final Role |
| --- | --- | --- | --- | --- | --- |
| Reseller request | `approved` | yes | yes | `1` | `reseller` |
| Supplier request | `rejected` | yes | yes | `1` | `reseller` |

No `profiles.primary_role` direct update was run from UI or app code. The requester profile role changed only through the approved audited RPC.

## F. Audit Log Verification

Each reviewed request has one `public.audit_logs` row with:

- `target_entity_type = role_onboarding_requests`
- `target_entity_id` matching the reviewed request id
- `action = review_role_onboarding_request`

## G. Non-Admin Block Result

Unauthenticated HTTP request to `/admin/onboarding-requests` returned Clerk signed-out protection headers:

- `x-clerk-auth-status: signed-out`
- `x-clerk-auth-reason: protect-rewrite, dev-browser-missing`

The route remains under the existing `/admin(.*)` Clerk protection and the server-side page/action gate uses `public.has_admin_role('admin')`.

## H. Security Checks

- Admin access is granted through `public.admin_staff`, not `profiles.primary_role`.
- `profiles.primary_role` for the admin test profile remains `customer`.
- The admin page/action use `review_role_onboarding_request`.
- No direct `.from("profiles").update` path exists in the admin UI/action.
- No service role import exists in app/components.
- No admin self-promotion UI was added.
- No checkout, orders, products, settlements, commissions, payments, or inventory live integration was touched.
- No migrations were applied.
- No destructive reset commands were run.

## I. Issues/Fixes

Issue: Codex could not automate the signed-in browser click-through because the current thread did not expose a browser-control tool that could reuse the in-app Clerk session.

Mitigation:

- Verified the admin page route builds.
- Verified unauthenticated/non-admin route protection path.
- Verified pending request data directly in development Supabase.
- Verified approve/reject through the same audited RPC that the admin UI action calls, under a simulated admin user context.

Remaining manual spot-check:

- With the admin test account signed into the browser, open `/admin/onboarding-requests` and confirm the page now shows the post-review empty state or no pending requests.

## J. Commands Run/Results

- `git status --short`
  - Only prior bootstrap docs were dirty before this report.
- `npx supabase --version`
  - `2.109.1`
- `npx supabase projects list`
  - Linked project: `Risellar`, `ACTIVE_HEALTHY`.
- `curl.exe -I -s http://localhost:400/admin/onboarding-requests`
  - Confirmed signed-out Clerk protection headers.
- Read-only pending request query
  - Found reseller and supplier_owner pending development requests for the same test requester.
- Audited RPC review query
  - Rejected supplier request.
  - Approved reseller request.
  - Admin context matched and `has_admin_role('admin')` was true.
- Read-only post-review verification query
  - Confirmed statuses, reviewer fields, requester final role, and audit logs.
- `npm test`
  - Passed: 21 test files, 109 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.
- `npm run typecheck`
  - Passed.

Final verification commands were rerun after this report was created.

## K. Secret Scan Result

- `.env.local` ignored: yes
- `.env.local` tracked: no
- `.env.local` staged: no
- `supabase/.temp/` ignored: yes
- Service-role imports in app/components: no
- Secret-pattern matches in source/docs/scripts: `0`
- No real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, or production data were added.

## L. Current Git Status

- Modified: `docs/RISELLAR_ADMIN_ONBOARDING_REVIEW_UI_REPORT.md`
- Modified: `docs/RISELLAR_ADMIN_TEST_PROFILE_BOOTSTRAP_PLAN.md`
- Untracked: `docs/RISELLAR_ADMIN_ONBOARDING_REVIEW_MANUAL_QA_REPORT.md`
- Untracked: `docs/RISELLAR_ADMIN_TEST_PROFILE_BOOTSTRAP_EXECUTION_REPORT.md`
- No files staged.

## M. Whether Safe To Commit

Safe to commit after final verification remains green and the secret scan remains clean.
