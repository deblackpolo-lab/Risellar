# Risellar Storage Boundary Tests

DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.

These scripts are for the confirmed development Supabase project named `Risellar` only. They use fake development records and fake storage object metadata. They do not upload real files, do not contain secrets, and must not be run against production data.

Do not run these scripts unless the user explicitly approves development-only storage boundary test execution.

## Files

- `storage-boundary-tests-dev-only.sql`: inserts fake supplier/product fixtures, exercises the `product-images` bucket policies through SQL against `storage.objects`, reports pass/fail assertions, then rolls back.

## Recommended Execution

Preferred method after explicit approval:

```bash
npx supabase db query --linked --file scripts/storage/storage-boundary-tests-dev-only.sql
```

Fallback method:

1. Open the confirmed development Supabase project only.
2. Paste `scripts/storage/storage-boundary-tests-dev-only.sql` into the SQL Editor.
3. Review every statement before running.
4. Run only after confirming the project is development-only.

## SQL-Only Coverage

The SQL script can test:

- bucket metadata is present and private
- anonymous SQL reads cannot see `product-images` objects
- supplier owner can insert object metadata only under own supplier path
- permitted supplier team member can insert object metadata under own supplier path
- supplier users cannot insert or update another supplier path
- sensitive proof bucket object inserts are blocked when no policy/bucket is available

## Manual Storage API Checklist

SQL cannot fully prove Storage HTTP/API behavior for binary uploads, signed URL generation, browser SDK behavior, or CDN/public URL exposure. After the SQL script passes, manually verify in the development project only:

- the browser/client never receives a service-role key
- anonymous public URLs for `product-images` do not expose unapproved/private objects
- a supplier owner can upload a fake development image only under `supplier_id/product_id/file_name`
- a permitted supplier team member can upload only under the same supplier path
- a supplier cannot overwrite another supplier path
- `settlement-proofs`, supplier verification files, dispute evidence, and return evidence remain private/deferred until explicit policies exist

## Safety Rules

- Do not use production credentials.
- Do not run against a production project.
- Do not use real files, real users, real emails, real phone numbers, real addresses, real payout details, or production data.
- Do not weaken storage policies to make tests pass.
- Do not run destructive reset commands.
- Do not commit `.env.local`.
- Do not run plain `supabase db push` from these scripts.
- Do not apply migrations from these scripts.
