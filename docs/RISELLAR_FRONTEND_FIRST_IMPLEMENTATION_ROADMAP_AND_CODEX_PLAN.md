# Risellar Frontend-First Implementation Roadmap and Codex Plan

## 1. Document Purpose

This document converts Risellar's approved brand, product, business-rule, and security planning into a safe frontend-first build order. It exists so future Codex tasks can build the full UI/UX prototype with reusable components, correct routes, realistic mock data flows, PWA/mobile-first screens, desktop admin screens, and edge states before any backend integration begins.

This is a documentation and planning artifact only. It does not create UI code, backend code, database migrations, Supabase tables, Clerk integration, Resend integration, payments, storage buckets, or deployment.

## 2. Source Documents Reviewed

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`: mandatory UI source of truth, design tokens, component rules, PWA interpretation, responsive rules, visual QA, and anti-redesign constraints.
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`: maps each reference image to screen areas and confirms all phone mockups are mobile PWA/web references.
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`: confirms the brand guide is strict enough for implementation and highlights non-negotiables.
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`: defines marketplace rules, auth boundaries, pricing, stock reservation, settlements, commissions, risk, notifications, WhatsApp helpers, support, audit, and MVP limits.
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC_REPORT.md`: summarizes key business decisions, assumptions, and open questions.
- `docs/RISELLAR_FULL_PRD.md`: defines user roles, journeys, screen map, product scope, acceptance criteria, and MVP phases.
- `docs/RISELLAR_FULL_PRD_REPORT.md`: summarizes product requirements, out-of-scope items, and open questions.
- `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN.md`: defines future schema/security foundations, sensitive operations, data ownership, role boundaries, RLS expectations, and backend handoff concepts.
- `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN_REPORT.md`: summarizes schema/RLS decisions that frontend mock data must anticipate without implementing.

## 3. Frontend-First Strategy

Risellar will be built frontend-first because the owner needs the complete UI/UX approved before backend work begins. This reduces backend rework, reveals missing screens early, allows screenshot QA against the reference images, validates flows with mock data, and prevents Codex from mixing unfinished UI with backend complexity.

Frontend work must simulate the business logic with mock state only. Backend begins only after the frontend is visually approved, documented, and handed off with route, mock data, form, status, email, storage, and sensitive-operation inventories.

## 4. Approved Platform Architecture

Approved structure:

- One Next.js web/PWA project.
- Reseller: PWA/mobile-first web routes.
- Supplier: PWA/mobile-first web routes.
- Customer: mobile web checkout with account creation.
- Admin: desktop web dashboard.

Route group examples:

- `/`
- `/auth/*`
- `/reseller/*`
- `/supplier/*`
- `/shop/[shopSlug]/*`
- `/checkout/*`
- `/customer/*`
- `/admin/*`
- `/design-system`

Phone mockups in the reference images are PWA/mobile web references, not React Native, Expo, iOS, or Android requirements.

## 5. What Must Not Be Built Yet

Frontend phases must not include:

- real Supabase schema
- database migrations
- RLS policies
- backend services
- real Clerk auth integration
- real Resend integration
- real Paystack/Hubtel integration
- real MoMo integration
- WhatsApp Business API
- real file uploads to Supabase Storage
- production deployment
- native mobile apps

Use placeholders, static mock files, local mock state, and mock service functions only.

## 6. Design Source of Truth

Before any UI build phase, Codex must read:

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`

The reference images remain the visual source. No redesign is allowed. Any unavoidable deviation must be documented in that phase report before moving on.

## 7. Recommended Project Structure

Recommended Next.js structure, adaptable to the actual repo once the project exists:

```text
/app
  /(public)
  /auth
  /reseller
  /supplier
  /shop/[shopSlug]
  /checkout
  /customer
  /admin
  /design-system
/components
  /ui
  /layout
  /cards
  /forms
  /badges
  /navigation
  /reseller
  /supplier
  /customer
  /admin
  /empty-states
/lib
  /mock
  /types
  /utils
  /constants
  /status
  /pricing
  /routes
/docs
/styles
```

## 8. Frontend Technology Assumptions

- Next.js App Router.
- TypeScript.
- Tailwind CSS.
- PWA-friendly responsive design.
- Mock data in TypeScript files.
- No backend calls during frontend-first phases.
- `lucide-react` or similar icons may be used.
- `shadcn/ui` may be used only if heavily customized to match the Risellar guide.
- Simple mock chart components are acceptable; avoid heavy chart dependencies until needed.

## 9. Mock Data Strategy

Mock datasets:

- users/profiles
- customers
- resellers
- reseller shops
- suppliers
- inventory managers
- products
- product variants
- stock and stock movements
- reseller listings
- orders
- delivery quotes
- settlements
- commissions
- withdrawals
- promotions
- risk scores
- disputes
- email logs
- WhatsApp templates
- admin queues
- audit logs

Mock data rules:

- Use GH₵ amounts.
- Use Ghana locations such as Accra, Kumasi, Madina, Legon, UPSA, KNUST, Tamale, Takoradi, and East Legon.
- Use realistic supplier, reseller, and customer names.
- Use status strings from the business rules and PRD.
- Include price breakdown examples: supplier base price, platform margin, reseller cost, reseller margin, customer price, and delivery cost.

Mock actions are UI-only:

- add product to shop
- set selling price
- place order
- confirm order
- approve delivery quote
- mark supplier preparing
- submit settlement proof
- verify settlement
- release commission
- request withdrawal
- boost product
- restock product
- invite inventory manager
- open dispute

## 10. Design-System-First Workflow

Phase 1 must create tokens, base components, and a `/design-system` gallery before app screens. The gallery must be approved before broad screen building begins.

The gallery must show:

- buttons
- inputs
- cards
- product cards
- order cards
- price breakdowns
- settlement cards
- badges
- wallet cards
- delivery option cards
- payment method cards
- admin metrics
- admin tables
- admin queues
- empty states
- modal/drawer patterns
- status variants

## 11. Component Library Plan

Core UI:

- `Button`
- `Input`
- `Select`
- `Textarea`
- `Checkbox`
- `RadioCard`
- `FileUploadCard`
- `SearchBar`
- `Tabs`
- `Modal` / `Drawer`
- `Toast` / `Alert`
- `Card`
- `Badge`
- `Avatar`
- `EmptyState`
- `ErrorState`
- `LoadingState`

Marketplace:

- `ProductCard`
- `ProductListItem`
- `ProductDetailHero`
- `PriceBreakdownCard`
- `ProfitCalculatorCard`
- `StockStatusCard`
- `OrderCard`
- `OrderTimeline`
- `DeliveryOptionCard`
- `PaymentMethodCard`
- `SettlementCard`
- `CommissionCard`
- `WalletCard`
- `PromotionCard`
- `TrendingInsightCard`
- `RiskScoreCard`

Admin:

- `AdminSidebar`
- `AdminTopbar`
- `AdminMetricCard`
- `AdminTable`
- `AdminFilterBar`
- `AdminQueueCard`
- `AdminDetailPanel`
- `AuditLogItem`
- `ManualOverridePanel`
- `WhatsAppTemplateCard`

## 12. Design-System Gallery Plan

The `/design-system` route is an internal review surface, not a marketing page. It should include:

- brand colors
- typography examples
- spacing samples
- buttons
- forms
- badges
- cards
- mobile components
- admin components
- status examples
- empty states
- financial breakdown examples
- mock data examples

Purpose: approve the UI system before screen build.

## 13. Visual QA Strategy

Every UI batch must:

- compare against the reference images
- check buttons, cards, spacing, fonts, icons, and status badges
- run screenshot QA where possible
- create a phase report
- fix inconsistencies before moving to the next batch

Visual QA checklist:

- primary green matches the guide
- amber accents are consistent
- buttons use consistent height/radius
- cards use consistent padding/radius
- badges match the status system
- admin tables are readable
- mobile screens use correct 16px base padding
- no random colors
- no one-off UI
- empty states are helpful
- financial breakdowns are visible

## 14. Routing and Navigation Plan

Public/Auth:

- `/`
- `/how-it-works`
- `/become-a-reseller`
- `/become-a-supplier`
- `/delivery-info`
- `/faq`
- `/contact`
- `/auth/login`
- `/auth/register`
- `/auth/role`
- `/auth/pending`
- `/auth/restricted`

Reseller:

- `/reseller/dashboard`
- `/reseller/products`
- `/reseller/products/[id]`
- `/reseller/products/[id]/price`
- `/reseller/shop`
- `/reseller/shop/edit`
- `/reseller/my-products`
- `/reseller/orders`
- `/reseller/orders/[id]`
- `/reseller/wallet`
- `/reseller/withdraw`
- `/reseller/transactions`
- `/reseller/trending`
- `/reseller/promotions`
- `/reseller/settings`
- `/reseller/support`

Supplier:

- `/supplier/dashboard`
- `/supplier/products`
- `/supplier/products/new`
- `/supplier/products/[id]`
- `/supplier/products/[id]/edit`
- `/supplier/inventory`
- `/supplier/inventory/[productId]`
- `/supplier/orders`
- `/supplier/orders/[id]`
- `/supplier/settlements`
- `/supplier/settlements/[id]`
- `/supplier/team`
- `/supplier/team/invite`
- `/supplier/promotions`
- `/supplier/settings`
- `/supplier/support`

Customer:

- `/shop/[shopSlug]`
- `/shop/[shopSlug]/product/[productId]`
- `/checkout/cart`
- `/checkout/account`
- `/checkout/delivery`
- `/checkout/payment`
- `/checkout/review`
- `/checkout/success`
- `/customer/orders`
- `/customer/orders/[id]`
- `/customer/orders/[id]/confirm`
- `/customer/orders/[id]/delivery-quote`
- `/customer/support`

Admin:

- `/admin/dashboard`
- `/admin/operations`
- `/admin/orders`
- `/admin/orders/[id]`
- `/admin/customers`
- `/admin/resellers`
- `/admin/resellers/[id]`
- `/admin/suppliers`
- `/admin/suppliers/[id]`
- `/admin/products`
- `/admin/products/[id]`
- `/admin/inventory`
- `/admin/settlements`
- `/admin/settlements/[id]`
- `/admin/commissions`
- `/admin/withdrawals`
- `/admin/promotions`
- `/admin/disputes`
- `/admin/risk`
- `/admin/audit-logs`
- `/admin/settings`

## 15. Screen Build Order

1. Design-system gallery.
2. Three pilot screens.
3. Reseller core.
4. Customer checkout core.
5. Supplier core.
6. Inventory/settlements.
7. Admin core.
8. Admin operations/risk.
9. Promotions/insights.
10. Team/permissions.
11. Empty states/edge cases.
12. Final QA polish.

## 16. Reseller PWA Build Plan

Screens:

- onboarding
- dashboard
- catalog/product list
- product detail
- selling price calculator
- add-to-shop success
- my shop
- orders
- order detail
- wallet
- withdraw
- transactions
- trending/promotions entry
- settings/support

Components:

- `ProductCard`, `ProductDetailHero`, `ProfitCalculatorCard`, `OrderCard`, `WalletCard`, `CommissionCard`, `PromotionCard`, bottom nav.

Mock data:

- reseller profile, shop, products, listings, commission states, orders, withdrawals, trends.

Mock actions:

- add product to shop, set price, share product, request withdrawal.

Acceptance:

- reseller cost/profit is clear, GH₵ amounts are visible, pending vs available commission is unmistakable, no supplier private contact is displayed.

QA:

- mobile-first at 360px through 414px, bottom nav matches references, buttons remain consistent.

## 17. Supplier PWA Build Plan

Screens:

- supplier onboarding
- dashboard
- products
- add product
- edit product
- product detail
- orders
- order detail
- prepare order
- settings/support

Components:

- `ProductListItem`, `StockStatusCard`, `OrderTimeline`, `SettlementCard`, `FileUploadCard`, supplier bottom nav.

Mock data:

- supplier workspace, verification state, products, orders, payout placeholder, settlement summary.

Mock actions:

- add/edit product, mark preparing, mark ready, update settings placeholder.

Acceptance:

- supplier keeps base price visible where appropriate, operational numbers are clear, verification/approval states are visible.

QA:

- mobile operational cards remain readable; no desktop admin table patterns forced into supplier mobile screens.

## 18. Customer Checkout Build Plan

Screens:

- reseller shop page
- product page
- cart
- account placeholder
- delivery details
- delivery options
- payment method
- review
- success
- order confirmation
- delivery quote approval
- tracking
- customer support

Components:

- `ProductCard`, `DeliveryOptionCard`, `PaymentMethodCard`, `PriceBreakdownCard`, `OrderTimeline`, `Alert`.

Mock data:

- customer profile, address, cart, order, delivery estimate, delivery quote, confirmation status.

Mock actions:

- place order, confirm order, approve delivery quote, request help.

Acceptance:

- Pay on Delivery is default/trust-forward, product price and delivery cost remain separate, account creation is shown without real Clerk.

QA:

- small mobile widths are smooth; no bottom tab nav in checkout; sticky CTA only where useful.

## 19. Admin Dashboard Build Plan

Screens:

- admin layout
- overview dashboard
- orders
- order detail
- products
- suppliers
- supplier detail
- resellers
- reseller detail
- customers
- inventory summary

Components:

- `AdminSidebar`, `AdminTopbar`, `AdminMetricCard`, `AdminTable`, `AdminFilterBar`, `AdminDetailPanel`.

Mock data:

- orders, customers, resellers, suppliers, product approvals, metrics, activities.

Mock actions:

- filter tables, view detail, approve/reject placeholder, update status placeholder.

Acceptance:

- admin is desktop-first, dense but readable, all money/status actions feel controlled and auditable.

QA:

- test 1280px and 1440px; ensure tables do not collapse into weak mobile cards.

## 20. Auth/Onboarding UI Build Plan

Screens:

- splash/welcome
- choose role
- login placeholder
- register placeholder
- pending approval
- restricted account
- reseller profile/setup
- supplier business profile
- supplier verification upload placeholder
- customer profile/address setup
- admin login placeholder

Components:

- auth card, role selector, onboarding stepper, form inputs, status panels.

Mock data:

- role options, pending/restricted states, sample user profiles.

Mock actions:

- select role, continue onboarding, submit placeholder form.

Acceptance:

- clearly states auth is mock/placeholder; does not connect Clerk yet.

QA:

- forms are short on mobile and use consistent controls.

## 21. Empty States and Edge Cases Build Plan

States:

- reseller empty shop
- no orders yet
- pending commission
- withdrawal failed
- notifications empty
- customer awaiting confirmation
- delivery quote pending
- order cancelled
- delivery failed
- supplier no products
- out of stock
- low stock
- supplier settlement overdue
- verification pending/rejected
- supplier suspended/restricted
- admin no orders today
- no product approvals
- support inbox empty

Components:

- `EmptyState`, `ErrorState`, `Alert`, status-specific CTA patterns.

Acceptance:

- each state has helpful heading, short explanation, primary action, and secondary action where useful.

## 22. Promotions/Insights UI Build Plan

Screens:

- reseller trending products
- top-selling list
- product insights detail
- growth hub
- WhatsApp caption card
- Pro insights locked state
- supplier boost request
- admin promotion approvals

Components:

- `PromotionCard`, `TrendingInsightCard`, `WhatsAppTemplateCard`, locked-feature panel.

Mock actions:

- boost product, copy caption, upgrade placeholder, approve/reject promotion placeholder.

Acceptance:

- Pro-locked UI does not block core selling; captions do not make false claims.

## 23. Inventory/Stock UI Build Plan

Screens:

- supplier inventory dashboard
- products list with stock badges
- variant stock detail
- restock form
- stock movement history
- price change request
- low/out-of-stock states
- inventory manager activity

Components:

- `StockStatusCard`, `ProductListItem`, variant table/list, movement timeline.

Mock actions:

- restock product, update low threshold, request price change.

Acceptance:

- total, reserved, available, sold, low threshold, and stock movement history are visible.

## 24. Supplier Settlement UI Build Plan

Screens:

- supplier settlement dashboard
- settlement detail
- upload proof placeholder
- overdue settlement
- partial settlement
- settlement history
- trust/restriction state

Components:

- `SettlementCard`, `PriceBreakdownCard`, `FileUploadCard`, `RiskScoreCard`, restriction alert.

Mock actions:

- submit settlement proof, view details, filter settlement history.

Acceptance:

- overdue and restriction states are impossible to miss; reseller commission release remains tied to verification.

## 25. Admin Operations/Risk UI Build Plan

Screens:

- operations hub
- customer confirmation queue
- supplier/product approval queues
- settlement due queue
- proof verification queue
- delivery/support queues
- commission release queue
- risk dashboard
- audit logs
- manual override panel

Components:

- `AdminQueueCard`, `AdminTable`, `RiskScoreCard`, `AuditLogItem`, `ManualOverridePanel`.

Mock actions:

- assign queue item, approve placeholder, reject placeholder, write manual override reason.

Acceptance:

- queue counts, priority, status, quick actions, filters, and audit trail context are visible.

## 26. Team Members/Permissions UI Build Plan

Screens:

- supplier team members
- invite inventory manager
- role permissions detail
- edit team member permissions
- access denied
- team activity log
- admin/owner permissions matrix

Components:

- team member card, permission toggle list, permissions matrix table, access denied panel.

Mock actions:

- invite team member, toggle permission placeholder, request access.

Acceptance:

- inventory manager limitations are explicit; sensitive owner-only actions are visually clear.

## 27. Support/Disputes UI Build Plan

Screens:

- support center
- support ticket list
- dispute detail
- evidence placeholder
- return/refund states
- failed delivery flow
- contact support placeholder

Components:

- ticket card, dispute detail panel, upload placeholder, status timeline, support CTA.

Mock actions:

- open dispute, add note, upload evidence placeholder, mark resolved placeholder.

Acceptance:

- dispute states can hold commission/settlement visually without implementing backend rules.

## 28. Frontend State and Mock Actions Plan

Allowed frontend state:

- local React state
- static mock files
- URL params
- simple mock service functions

No backend calls.

Mock functions:

- `createMockOrder()`
- `confirmMockOrder()`
- `approveMockDeliveryQuote()`
- `reserveMockStock()`
- `releaseMockStock()`
- `markMockSupplierPreparing()`
- `submitMockSettlementProof()`
- `verifyMockSettlement()`
- `releaseMockCommission()`
- `requestMockWithdrawal()`
- `restockMockProduct()`
- `createMockPromotion()`
- `inviteMockTeamMember()`

Each function name must include `Mock` and live under mock-only modules so future backend work can replace them deliberately.

## 29. Frontend QA Checklist

- TypeScript passes.
- Lint passes if configured.
- App builds if safe.
- All routes load.
- No broken links.
- Responsive screens are tested.
- Mock flows work.
- No backend imports.
- No env/secrets required.
- No random design drift.
- Screenshots checked for visual phases.

## 30. Accessibility Checklist

- Keyboard navigation works.
- Icon buttons have accessible labels.
- Focus states are visible.
- Touch targets meet mobile sizing rules.
- Text/background contrast is sufficient.
- Form controls have labels.
- Error messages are clear.
- Status is not communicated by color alone.
- Admin tables remain readable and navigable.

## 31. Performance and PWA Checklist

- Mobile-first routes load quickly with mock data.
- Images/placeholders are optimized.
- Avoid heavy dependencies.
- Split admin-heavy components from mobile PWA surfaces where possible.
- Loading skeletons exist for key list/detail screens.
- PWA manifest is later.
- Service worker is later/optional.

## 32. Responsive Testing Plan

Test widths:

- 360px
- 390px
- 414px
- 768px
- 1024px
- 1280px
- 1440px

Reseller, supplier, and customer surfaces prioritize mobile. Admin prioritizes desktop and should be checked at 1280px and 1440px first.

## 33. File/Folder Naming Conventions

- Route folders: lowercase.
- Docs: uppercase Risellar artifact names or kebab-case supporting docs, matching existing docs style.
- Components: PascalCase.
- Utilities/functions: camelCase.
- Mock files: domain-based names such as `products.mock.ts`, `orders.mock.ts`, `settlements.mock.ts`.
- Status constants: centralized under `lib/status` or equivalent.
- Do not duplicate raw status strings across screens.

## 34. Reporting Requirements Per Phase

Every build phase must create a report in `docs/`.

Examples:

- `RISELLAR_PHASE_1_DESIGN_SYSTEM_REPORT.md`
- `RISELLAR_PHASE_2_COMPONENT_GALLERY_REPORT.md`
- `RISELLAR_PHASE_3_PILOT_SCREENS_REPORT.md`

Each report includes:

- A. Summary
- B. Screens/components built
- C. Source docs used
- D. Visual reference used
- E. Mock data added
- F. Files changed
- G. Commands run
- H. QA results
- I. Known gaps
- J. Git status
- K. Next step

## 35. Git/Commit Strategy

- Keep docs committed separately from implementation.
- Use one focused commit per phase.
- Do not commit env files.
- Do not introduce secrets.
- Check git status at the end of each phase.
- Do not mix backend work into frontend phases.
- Prefer branch names with the `codex/` prefix unless the user requests otherwise.

## 36. Codex Phase-by-Phase Build Plan

Phase 0: Source Doc Lock

- Confirm required docs exist.
- Confirm approved PWA/web direction.
- Confirm no build begins in this phase.

Phase 1: Project Setup + Design Tokens

- Set up Next.js/Tailwind if needed.
- Create Risellar tokens.
- Create base layout shell.
- Create only `/design-system`, no real app screens.

Phase 2: Component Library + Design-System Gallery

- Build base UI and marketplace/admin components.
- Populate `/design-system`.
- Run visual QA against references.
- Create phase report.

Phase 3: Pilot Screens

- Build only reseller dashboard, product detail/profit calculator, and customer checkout payment/Pay on Delivery screen.
- QA those screens before expanding.

Phase 4: Reseller PWA Core

- Build reseller onboarding, dashboard, catalog, product detail, set price, shop, orders, and wallet.

Phase 5: Customer Checkout Core

- Build shop page, product page, cart, account placeholder, delivery, payment, review, success, confirmation, delivery quote approval, and tracking.

Phase 6: Supplier PWA Core

- Build supplier onboarding, dashboard, products, add/edit product, orders, prepare order, and settings.

Phase 7: Inventory + Stock UI

- Build inventory dashboard, product stock detail, restock, variants, stock movement, price change request, and low/out-of-stock states.

Phase 8: Supplier Settlements UI

- Build settlement dashboard, settlement detail, upload proof placeholder, overdue, partial settlement, history, and restrictions.

Phase 9: Admin Core Dashboard

- Build admin layout, overview, orders, order detail, products, suppliers, resellers, and customers.

Phase 10: Admin Operations/Risk

- Build operations queues, risk dashboard, settlement queues, delivery quote queue, commission release queue, audit logs, and manual override.

Phase 11: Promotions/Insights

- Build supplier boost request, admin promotion approvals, reseller trending/top-selling, sponsored cards, and Pro insights locked state.

Phase 12: Team/Permissions

- Build supplier team members, invite inventory manager, permissions matrix, access denied, and activity logs.

Phase 13: Support/Disputes/Returns

- Build support center, dispute detail, evidence placeholder, return/refund states.

Phase 14: Empty States + Edge Cases

- Build all empty/error/restricted/suspended states, no-data states, failed delivery, customer refused, and payment failed placeholder.

Phase 15: Full Frontend QA Polish

- Run route audit, visual consistency review, responsive testing, accessibility pass, and final phase report.

Phase 16: Frontend Approval + Backend Handoff

- Create final frontend summary.
- List backend integration points.
- List schema dependencies.
- Do not build backend yet.

## 37. Phase Exit Criteria

Each phase exits only when:

- source docs were read
- no redesign occurred
- typecheck passes where available
- lint passes where available
- build passes where safe
- report was created
- git status was reported
- visual QA was done for UI phases
- no backend work was accidentally added

## 38. Backend Handoff Requirements

After frontend approval, create:

- list of mock data objects used
- list of mock actions
- list of routes needing backend
- list of forms needing persistence
- list of status transitions
- list of email events
- list of storage uploads
- list of security-sensitive operations

This becomes backend implementation input.

## 39. What Backend Work Comes Later

Later backend phases:

- Clerk integration
- Supabase schema/migrations
- RLS policies
- stock reservation RPC
- order creation server action
- supplier settlement ledger
- commission lifecycle
- Resend email integration
- storage buckets
- audit logs
- admin permissions
- QA/security tests

## 40. Risks and How to Avoid Them

Risks:

- Codex redesigns UI.
- Spacing becomes inconsistent.
- Too many one-off components appear.
- Backend starts too early.
- Fake mock flows become real by accident.
- Screens are skipped.
- Admin dashboard becomes weak.
- Customer checkout becomes too complicated.
- Supplier settlement is unclear.

Controls:

- brand guide mandatory before every UI phase
- design-system gallery first
- pilot screens before full build
- reports per phase
- visual QA
- no backend in frontend phases
- central status constants
- reusable components only

## 41. Final Frontend Approval Checklist

- all source docs read
- design system built
- design gallery approved
- reseller PWA complete
- supplier PWA complete
- customer checkout complete
- admin dashboard complete
- inventory screens complete
- settlement screens complete
- promotion screens complete
- team/permissions complete
- support/dispute screens complete
- empty states complete
- all mock flows work
- no backend dependency
- responsive tested
- visual QA done
- reports complete

## 42. Recommended Next Step

The first real build prompt after this document should be Phase 1: project setup, design tokens, component library skeleton, and `/design-system` gallery shell. No app screens, backend code, Clerk, Resend, Supabase, payments, storage, or production deployment should be included in that first build.
