# Risellar Checkout Phase C C4 Planning Report

## A. Summary

Checkout Phase C C4 completed planning for customer order-confirmation UI and server-action integration. No source code, migrations, RPCs, policies, or live data operations were changed.

## B. Baseline Confirmation

- Branch: `main`
- Required baseline commit: `90c94d2fa7d561bc6208e56d97c3440263177c7c`
- Backend `create_order_from_checkout_draft(uuid,text)` exists.
- Single-session boundary verification previously passed.
- R7 true two-session concurrency verification previously passed.
- Final checkout UI remains disabled.

## C. Current UI Audit

The current `/checkout/draft/[draftId]` page remains draft-only:

- loads draft through server-only helper
- allows saved address/contact attachment
- allows abandon
- shows product and price snapshot
- displays disabled final confirmation copy
- does not create orders or reserve stock from the UI

The current `/customer/orders`, `/customer/orders/[id]`, and `/checkout/success` routes remain placeholder/mock surfaces and should not be treated as live order read UI.

## D. Confirmation-Flow Decision

C4 decision: do not enable the final order confirmation button yet.

Future implementation should use a server action that accepts only:

- checkout draft id
- acknowledgement flag
- optional idempotency key

The action should call only:

`create_order_from_checkout_draft(uuid,text)`

## E. Customer Order Read Model

The backend has `checkout_order_safe_row(uuid)`, which returns a single safe order row for participants or support admin access. However, the app does not yet have a customer order read helper or live customer order pages.

C5 is required before enabling final UI:

- confirm or wrap the single-order read contract
- add tests for customer-only read access
- decide whether a list RPC/helper is needed for `/customer/orders`
- prevent sensitive supplier/reseller/admin/finance field exposure

## F. Planned UX States

Current disabled CTA:

`Order confirmation coming next`

Future enabled CTA:

`Place order and reserve stock`

Required acknowledgement:

`I understand this places my order, reserves available stock, and I will pay on delivery after the seller confirms the order process.`

Success copy must state that the order was placed and stock was reserved, while payment collection, delivery quote/tracking, supplier preparation, commission, settlement, and withdrawal flows remain deferred.

## G. Security And Scope Protections

Preserved controls:

- no source changes
- no migrations
- no Supabase db push
- no migration repair
- no RPC boundary tests rerun
- no concurrency test rerun
- no production Supabase connection
- no service role in customer UI plan
- no direct table mutations from client
- no payment, delivery, commission, settlement, withdrawal, refund, or supplier-preparation integration

## H. Documents Created

- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_ORDER_CONFIRMATION_UI_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_CUSTOMER_ORDER_READ_MODEL_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_UI_COPY_AND_STATES.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_TEST_AND_BROWSER_QA_PLAN.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_RISK_REGISTER.md`
- `docs/RISELLAR_CHECKOUT_PHASE_C_C4_PLANNING_REPORT.md`

## I. Commands Run And Results

- `git status --short`: showed the seven new C4 planning docs as untracked, plus pre-existing no-content-diff metadata entries for supplier order/package/type configuration files.
- `git rev-parse HEAD`: confirmed `90c94d2fa7d561bc6208e56d97c3440263177c7c`.
- `git branch --show-current`: confirmed `main`.
- `git diff --name-status`: no tracked file content diff.
- `git diff --check`: passed.
- `npm test`: passed, 30 test files and 158 tests.
- `npm run lint`: passed with `--max-warnings=0`.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## J. Secret And Scope Scan

- `.env.local`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `.next`: ignored.
- `supabase/.temp`: ignored.
- `.codex-dev-server.*.log`: ignored.
- New C4 docs: no sensitive values, tokens, DB URLs, Supabase project URLs, Clerk account URLs, or UUID-like private identifiers found.
- App/components scan: no service-role import or service-role key usage found.
- Scope scan: no tracked app/source/migration/RPC content diff was present.
- Final confirmation remains disabled.

## K. Current Git Status

Final status before response:

```text
 M app/supplier/orders/[id]/page.tsx
 M app/supplier/orders/page.tsx
 M next-env.d.ts
 M package-lock.json
 M package.json
 M tsconfig.json
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_CUSTOMER_ORDER_READ_MODEL_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_IMPLEMENTATION_GROUPS.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_ORDER_CONFIRMATION_UI_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_PLANNING_REPORT.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_RISK_REGISTER.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_TEST_AND_BROWSER_QA_PLAN.md
?? docs/RISELLAR_CHECKOUT_PHASE_C_C4_UI_COPY_AND_STATES.md
```

The existing modified entries above have no tracked content diff in `git diff --name-status`; they appear to be pre-existing workspace metadata/no-content-diff state. The only new content from this C4 task is the seven untracked planning docs.

## L. Whether Safe To Begin Next Group

Safe next group: C5 customer order-read boundary planning/implementation only.

Do not begin C6 final confirmation server-action/UI wiring until C5 confirms the customer-safe read path.
