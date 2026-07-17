# Risellar RLS Boundary Test Scaffolding

DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.

These files are scaffolding for testing RLS boundaries against the confirmed development Supabase project named `Risellar`.

Do not run these scripts unless the user explicitly approves development-only fixture insertion/testing.

## Files

- `rls-fixtures-dev-only.sql`: fake development fixture plan and insert scaffolding.
- `rls-boundary-test-plan.sql`: SQL boundary test scaffolding using fake JWT subjects and expected result notes.

## Safe Execution Options

Option A: Supabase SQL Editor

1. Open the confirmed development project only.
2. Paste a script.
3. Review every statement.
4. Run only after confirming no production data is present.

Option B: Supabase CLI remote query

```bash
npx supabase db query --linked --file scripts/rls/rls-fixtures-dev-only.sql
npx supabase db query --linked --file scripts/rls/rls-boundary-test-plan.sql
```

Option C: psql

Install PostgreSQL client tools, connect only to the development database, and run:

```bash
psql "<development database url>" -f scripts/rls/rls-fixtures-dev-only.sql
psql "<development database url>" -f scripts/rls/rls-boundary-test-plan.sql
```

## Warnings

- Do not use production credentials.
- Do not run against a production project.
- Do not use real users, real orders, real phone numbers, real payout details, or production data.
- Do not weaken RLS policies to make tests pass.
- Do not run destructive reset commands.
- Do not commit `.env.local`.
