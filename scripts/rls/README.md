# Risellar RLS Boundary Tests

DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.

These scripts are for the confirmed development Supabase project named `Risellar` only. They use fake development records, do not contain secrets, and must not be run against production data.

Do not run these scripts unless the user explicitly approves development-only RLS test execution.

## Files

- `rls-fixtures-dev-only.sql`: inserts a small fake fixture graph, validates the fixture shape, and rolls back. Use this as a fixture smoke check only.
- `rls-boundary-tests-dev-only.sql`: inserts fake fixtures, runs pass/fail RLS boundary assertions under simulated `anon` and `authenticated` request contexts, reports results, then rolls back.
- `rls-boundary-test-plan.sql`: legacy review plan kept for traceability. Use `rls-boundary-tests-dev-only.sql` for runnable pass/fail testing.

## Recommended Execution

Preferred method after explicit approval:

```bash
npx supabase db query --linked --file scripts/rls/rls-boundary-tests-dev-only.sql
```

Fallback method:

1. Open the confirmed development Supabase project only.
2. Paste `scripts/rls/rls-boundary-tests-dev-only.sql` into the SQL Editor.
3. Review every statement before running.
4. Run only after confirming the project is development-only.

If the execution environment cannot simulate request roles with `set local role` and `request.jwt.claims`, use `psql` or Supabase CLI linked query from a development-only connection. Do not use production credentials.

## Safety Rules

- Do not use production credentials.
- Do not run against a production project.
- Do not use real users, real orders, real emails, real phone numbers, real addresses, real payout details, or production data.
- Do not weaken RLS policies to make tests pass.
- Do not run destructive reset commands.
- Do not commit `.env.local`.
- Do not run plain `supabase db push` from these scripts.
- Do not apply migrations from these scripts.

## Expected Behavior

The runnable test script raises an exception at the end if any boundary fails. A failure is useful evidence and must be fixed in schema/RLS code, grants, or test setup after review. Do not treat a failed RLS boundary test as permission to loosen policies without a security review.
