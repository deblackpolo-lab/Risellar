# Risellar RLS Runnable Tests Preparation Report

Date: 2026-07-17

## A. What Was Made Runnable

- Converted `scripts/rls/rls-fixtures-dev-only.sql` from commented scaffolding into a development-only fixture smoke script.
- Added `scripts/rls/rls-boundary-tests-dev-only.sql` as the runnable pass/fail RLS boundary test script.
- Updated `scripts/rls/README.md` with execution guidance and safety rules.
- Replaced `scripts/rls/rls-boundary-test-plan.sql` with a traceability stub that points reviewers to the runnable test file.

The runnable test script now:

- Creates fake development-only fixture rows inside a transaction.
- Simulates `anon` and `authenticated` request contexts with `set local role` and `request.jwt.claims`.
- Records pass/fail results in a temporary table.
- Converts previously comment-only negative tests into executable assertions.
- Rolls back at the end so fixture data is not retained.
- Raises an exception if any boundary fails.

## B. What Still Cannot Be Tested Yet

The SQL has not been executed yet by request. These items remain unproven until approved development execution:

- Whether the linked Supabase execution context can run `set local role anon` and `set local role authenticated`.
- Whether `request.jwt.claims` role simulation matches Supabase/PostgREST behavior in the linked development project.
- Whether the development database grants allow `anon` and `authenticated` to reach the tables before RLS evaluates policies.
- Whether every assertion passes against the applied development schema.

The script intentionally includes a staff-permission visibility assertion for `supplier_inventory_manager`. If current table-level RLS allows inventory managers to read `supplier_team_members.permissions`, that assertion should fail and must be treated as a real boundary finding, not as permission to weaken RLS.

## C. Role Simulation Handling

Role simulation is handled in SQL with:

- `set local role anon`
- `set local role authenticated`
- `set local "request.jwt.claims" = '{"sub":"dev_clerk_..."}'`

The migration helper `public.current_profile_id()` derives identity from `auth.jwt() ->> 'sub'`, so each simulated authenticated block uses a matching fake `clerk_user_id`.

If the execution environment cannot set roles or request JWT claims, then SQL Editor-only execution may not be sufficient. In that case, use Supabase CLI linked query or `psql` against the development database after explicit approval.

## D. Exact Execution Method Recommended

After explicit approval only:

```bash
npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql
```

Do not run against production. Do not run with production credentials. Do not apply migrations as part of this test run.

## E. Whether SQL Editor Can Run It

Likely yes if the SQL Editor session has enough privilege to insert fake fixtures and run `set local role`.

If SQL Editor rejects role simulation or custom request claims, use the CLI linked query method instead.

## F. Whether `npx supabase db query --linked --file` Can Run It

The installed Supabase CLI exposes:

```bash
npx supabase db query --linked --file <path>
```

The command was checked with help output only. The RLS scripts were not executed.

## G. Safety Notes

- Scripts are marked `DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION`.
- Scripts use fake names, fake emails, fake phone placeholders, fake storage paths, and fake order numbers.
- Scripts do not contain secrets.
- Scripts do not disable RLS.
- Scripts do not drop or truncate tables.
- Scripts do not apply migrations.
- Scripts use transaction rollback for inserted fixture data.
- `.env.local` must remain ignored and unstaged.

## H. Commands Run/Results

Pre-report commands:

- `git status --short` - showed modified RLS scripts and one new runnable test script.
- `git diff --check` - passed; line-ending warnings only.
- `npx supabase db --help` - passed; showed `query` subcommand exists.
- `npx supabase db query --help` - passed; showed `--linked` and `--file` flags exist.

Final verification commands are recorded after execution below.

## I. Secret Scan Result

Initial scan found no secret values in the changed RLS scripts. Hits were safety-language false positives such as “do not use secrets” and migration comments warning not to store secrets.

Final secret scan result is recorded after execution below.

## J. Files Changed

- `scripts/rls/README.md`
- `scripts/rls/rls-boundary-test-plan.sql`
- `scripts/rls/rls-fixtures-dev-only.sql`
- `scripts/rls/rls-boundary-tests-dev-only.sql`
- `docs/RISELLAR_RLS_RUNNABLE_TESTS_PREP_REPORT.md`

## K. Current Git Status

Recorded after final verification below.

## Final Verification Results

Final commands:

- `git status --short` - working tree contains only the RLS script/report changes listed below.
- `git diff --check` - passed; Git reported line-ending normalization warnings only.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed with `--max-warnings=0`.
- `npm run build` - passed; Next.js generated 160 static pages.
- Secret/env scan - passed:
  - `.env.local` is ignored.
  - `.env.local` is not staged.
  - `supabase/.temp/` is ignored.
  - No tracked secret-pattern findings were found.

Current git status:

```text
 M scripts/rls/README.md
 M scripts/rls/rls-boundary-test-plan.sql
 M scripts/rls/rls-fixtures-dev-only.sql
?? docs/RISELLAR_RLS_RUNNABLE_TESTS_PREP_REPORT.md
?? scripts/rls/rls-boundary-tests-dev-only.sql
```

RLS scripts were not executed. No production Supabase connection was used. No migrations were applied.
