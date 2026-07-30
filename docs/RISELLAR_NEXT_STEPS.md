# Risellar Next Steps

Date: 2026-07-29

## Immediate Recommendation

Do not commit the current working tree.

The next action should be an explicit recovery cleanup prompt, not feature development.

## Exact Safe Recovery Prompt

Use this prompt when ready:

```text
Recover Risellar to the verified safe baseline 94f6eb69ca1d22c475997f52d4d7729d52dfd0b7.

Do not apply migrations.
Do not connect production Supabase.
Do not print secrets.
Do not commit .env.local.
Do not run destructive reset commands.
Do not use git reset --hard.
Do not delete files outside C:\Users\Nana Kwadwo\Documents\Risellar.

Use the forensic reports in docs/:
- RISELLAR_FORENSIC_CHANGE_AUDIT.md
- RISELLAR_AUTHENTICATION_AUDIT.md
- RISELLAR_BUILD_FAILURE_REPORT.md
- RISELLAR_CHECKOUT_SCOPE_AUDIT.md
- RISELLAR_RECOVERY_PLAN.md
- RISELLAR_SAFE_FILES_TO_KEEP.md
- RISELLAR_FILES_TO_REVERT.md
- RISELLAR_NEXT_STEPS.md

Restore package/config/auth/routing files from the safe baseline.
Delete only the untracked files classified DELETE in RISELLAR_FILES_TO_REVERT.md.
Do not delete .env.local.
Do not keep unapproved migrations.
Do not keep order/delivery/payment/settlement APIs.
After cleanup, run:
git status --short
git diff --check
npm test
npm run lint
npm run build
npm run typecheck

Run a secret/scope scan and report results.
Do not commit unless asked.
```

## After Cleanup

If cleanup verifies cleanly:

1. Commit the recovery cleanup.
2. Start a new Checkout Phase B Group 3 draft UI task.
3. Rebuild draft UI from scratch or salvage only reviewed draft-safe fragments.
4. Keep order creation for a later approved phase.

## Do Not Do Next

- Do not run `supabase db push`.
- Do not run `supabase db reset --linked`.
- Do not run `npm audit fix --force`.
- Do not install or upgrade dependencies.
- Do not keep session/debug artifacts.
- Do not start order/payment/delivery/settlement implementation.
