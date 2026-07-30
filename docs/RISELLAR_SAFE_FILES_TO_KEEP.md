# Risellar Safe Files To Keep

Date: 2026-07-29

Safe baseline: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## Keep From Current Working Tree

No uncontrolled file should be kept wholesale.

## Salvage Candidates

These files may contain legitimate Checkout Phase B Group 3 draft UI work, but they must be copied into a clean tree manually and reviewed line-by-line.

| File | Keep Condition |
| --- | --- |
| `middleware.ts` | Keep only `/checkout/draft(.*)` protected route addition. |
| `app/shop/[shopSlug]/product/[productId]/page.tsx` | Keep only a link/action to start a checkout draft; no order creation. |
| `components/customer/public-shop-rpc-screens.tsx` | Keep only read-only public shop UI plus draft-start CTA; no checkout submit. |
| `app/shop/[shopSlug]/product/actions.ts` | Keep only create-draft server action backed by approved draft RPC. |
| `app/checkout/draft/[draftId]/page.tsx` | Keep only draft review route. |
| `app/checkout/draft/[draftId]/actions.ts` | Keep only update/abandon/address draft actions; no order action. |
| `components/customer/checkout-draft-screens.tsx` | Keep only draft UI; remove purchase language. |
| `lib/checkout/server.ts` | Keep only if it follows existing Clerk `getToken()` and user Supabase helper pattern. |
| `lib/checkout/draft.ts` | Keep only draft RPC wrappers; remove `createOrderFromDraft`. |
| `tests/checkout-draft-ui.test.tsx` | Keep only tests proving draft-only behavior and no order/payment/stock side effects. |
| `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_UI_INTEGRATION_REPORT.md` | Rewrite after clean implementation; do not keep current claims as evidence. |

## Files Already Safe In Baseline

Everything tracked at `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7` remains the trusted source until deliberately changed.

Critical baseline areas to preserve:

- Clerk profile sync foundation
- active `admin_staff` admin access model
- role onboarding RPC and UI
- supplier product management RPC/UI
- admin product approval RPC/UI
- reseller catalog and add-to-shop RPC/UI
- public reseller shop read-only RPC/UI
- Customer Phase A contact/address RPC/UI
- Checkout Phase B Group 1 draft backend RPC
