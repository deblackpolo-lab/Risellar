# Risellar Clerk Real Auth QA Report

## A. Manual Test Sign-Up/Sign-In Result

Manual Clerk test-account sign-up/sign-in was completed by the user in a browser outside the agent-controlled sessions. Credentials, verification codes, and secret values were not printed, stored, or committed.

Agent-controlled browser sessions could not inspect that signed-in session afterward:

- the in-app browser had no open tabs to inspect;
- Chrome was reachable, but a fresh Chrome tab was not signed in and redirected to Clerk sign-in;
- therefore browser-visible post-login route rendering was not directly captured by the agent.

The development database result below confirms that the manual visit to `/auth/qa-profile-sync` created or found a recent Clerk-backed profile.

## B. QA Profile Sync Route Result

Route reviewed:

- `/auth/qa-profile-sync`

Result:

- the route is protected by Clerk middleware;
- unauthenticated direct requests receive Clerk development handshake/auth redirects;
- the route calls the existing server-only `getCurrentSyncedProfile()` helper;
- the route displays only safe profile-sync facts and does not print credentials or secrets;
- the route does not accept role input, form data, or search params;
- the route does not connect checkout, orders, products, settlements, commissions, or payments to live Supabase data.

## C. Supabase Profile Row Verification

A read-only linked Supabase query was run against the confirmed development project. It returned aggregate booleans/counts only, with no Clerk IDs, emails, names, credentials, or secret values printed.

Result for recent Clerk-backed profiles:

- recent profile count: `1`
- `clerk_user_id` exists: yes
- email exists: yes
- display name/full name exists: no
- customer role exists: yes
- privileged/business role self-assigned: no
- created timestamp exists: yes

Interpretation:

- the QA sync path created or found a `public.profiles` row in development;
- Clerk did not provide or persist a display name for this test profile;
- no admin, supplier, reseller, support, finance, or inventory-manager role was self-assigned.

## D. Default Role Verification

Runtime/database result:

- the recent Clerk-backed profile has `primary_role = 'customer'`.

Static helper review:

- `lib/auth/profile-sync-core.ts` defaults new profiles to `customer`;
- privileged roles are rejected by the profile sync helper;
- the QA route only invokes server-side sync and accepts no role field.

## E. Protected Route Behavior After Login

Routes checked by unauthenticated direct HTTP request:

- `/checkout/payment`
- `/customer/orders/rsr-20260713-00021`
- `/reseller/dashboard`
- `/supplier/dashboard`
- `/admin/dashboard`

Result:

- all returned Clerk development handshake/auth redirects without a browser session cookie;
- this confirms the routes are not publicly reachable by direct unauthenticated HTTP checks;
- post-login rendering could not be directly inspected because the manual signed-in browser session was unavailable to the agent-controlled browser tools.

## F. QA Route Development-Only Safety

The QA route was hardened to fail closed outside development unless explicitly enabled:

- enabled when `NODE_ENV === "development"`;
- optionally enabled by deliberate `RISELLAR_ENABLE_AUTH_QA=true`;
- otherwise returns `notFound()`.

This keeps the route useful for local/dev QA while preventing it from silently becoming a production-accessible profile sync tool.

## G. Issues/Fixes

Issues found:

1. No existing UI route safely triggered profile sync without entering business flows.
2. The initial QA route used Clerk exports not available in the installed package version.
3. The QA route was labeled development-only but not initially code-gated.
4. The agent could not inspect the manually signed-in browser session after user sign-in.

Fixes applied:

1. Added `/auth/qa-profile-sync`.
2. Protected `/auth/qa-profile-sync` in `middleware.ts`.
3. Switched the route to server-side `auth()` plus `getCurrentSyncedProfile()`.
4. Added a development-only/explicit-flag gate to the QA route.

## H. Commands Run/Results

- `git status --short`: working tree has expected uncommitted QA route/report/middleware changes.
- `git diff --check`: passed with the existing line-ending normalization warning for `middleware.ts`.
- `curl.exe` unauthenticated route checks: protected routes returned Clerk handshake/auth redirects.
- `npx supabase db query --linked "<aggregate profile verification SQL>"`: passed; returned one recent Clerk-backed customer profile and no privileged self-assignment.
- `npm test`: passed, 20 files / 93 tests.
- `npm run lint`: passed with `eslint . --max-warnings=0`.
- `npm run build`: passed.
- `npm run typecheck`: passed after build.

No migrations were applied. No destructive reset commands were run. No `npm audit fix --force` command was run.

## I. Secret Scan Result

Passed.

- `.env.local` exists, is ignored by Git, is not tracked, and is not staged.
- `supabase/.temp/` is ignored by Git.
- no high-confidence real Clerk/Supabase/service-role values were found in docs/source/scripts/tests.
- no client component imports `SUPABASE_SERVICE_ROLE_KEY`, `CLERK_SECRET_KEY`, `SUPABASE_DB_PASSWORD`, `createSupabaseAdminClient`, or the server-only profile sync helper.
- no bearer tokens, passwords, API secrets, or production data were detected by the value-suppressing scan.
- no files are staged.

## J. Current Git Status

- `M middleware.ts`
- `?? app/auth/`
- `?? docs/RISELLAR_CLERK_REAL_AUTH_QA_REPORT.md`

## K. Safe To Commit

Yes, safe to commit as a development-only auth QA/profile-sync verification update.

Remaining caveat:

- the agent did not directly inspect the user's manually signed-in browser session, but the development Supabase aggregate verification confirms the profile sync produced a recent Clerk-backed `customer` profile with no privileged self-assignment.

Safe next step:

- commit the QA route, middleware protection, and report when approved.

