# Risellar Brand UI System Guide

## 1. Document Purpose

This guide is the permanent UI source of truth for Risellar. Future Codex tasks must read it before building any page, component, or feature.

This document does not define product requirements, database schema, or page implementation. It defines the visual system and UI rules that keep every Risellar surface consistent across the reseller PWA, supplier PWA, customer checkout, and admin dashboard.

If a future task must deviate from this guide, document the reason in that task before implementing the deviation.

## 2. Reference Images Used

The reference images were reviewed from the user's Downloads folder and the visible attachments in this thread. The canonical named files exist for the master brand, reseller PWA, customer checkout, supplier PWA, admin dashboard, and onboarding flows. The later specialty references were available as dated `ChatGPT Image...png` files and are documented in `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`.

Treat every phone screen in these references as a mobile PWA/web screen, not as native iOS, Android, Expo, or React Native implementation guidance. Labels inside images that say "iOS / Android" describe the mockup frame only; future implementation remains Next.js PWA/web.

Referenced images:

- `risellar_product_and_app_design_showcase.png`
- `risellar_mobile_app_mockup_ui_design.png`
- `customer_checkout_flow_steps_overview.png`
- `risellar_supplier_app_ui_showcase.png`
- `risellar_admin_dashboard_mockup.png`
- `risellar_app_onboarding_flow_design.png`
- `risellar_ui_design_system_overview.png`
- `supplier_inventory_management_ui_design.png`
- `a_clean_high_resolution_ui_ux_dashboard_concept_a.png`
- `a_clean_high_resolution_ux_showcase_dashboard_moc.png`
- `risellar_admin_operations_control_panel.png`
- `modern_app_ui_product_dashboard_mockup.png`
- `mobile_app_admin_dashboard_design.png`

## 3. Risellar Brand Personality

Risellar is a Ghana reseller marketplace with ecommerce, fintech, and operations qualities. It should feel trustworthy enough for customers buying through reseller links, practical enough for everyday resellers and suppliers, and controlled enough for admin teams handling money, orders, delivery, settlements, disputes, and risk.

Brand personality:

- Trustworthy: every price, delivery, order, and settlement state is clear.
- Clean: screens are calm, organized, and easy to scan.
- Premium: the UI feels polished and serious, not decorative or cheap.
- Ghana-friendly: examples, copy, addresses, payment references, and market behaviors feel local.
- Operational: admin, supplier, and settlement flows expose enough detail to support real work.
- Encouraging: reseller flows should make selling feel possible and transparent.
- Firm when needed: overdue settlement, suspension, failed withdrawal, rejected verification, and risk states must be unmistakable.

Visual tone:

- Deep emerald green, soft cream, clean white surfaces, light borders, and restrained amber accents.
- Rounded cards and controls with subtle shadows.
- Mobile-first PWA layouts for reseller, supplier, and customer checkout.
- Desktop-first operational layout for admin.
- Modern marketplace/fintech feel, not a generic ecommerce template.

Design principles:

- Make trust visible.
- Make money transparent.
- Make statuses impossible to miss.
- Keep actions obvious and specific.
- Prefer reusable components over one-off styling.
- Keep mobile screens simple and admin screens dense but readable.

Trust-first UI rules:

- Price breakdowns must show what each party pays or earns.
- Pay on Delivery reassurance must be visible in checkout and order confirmation moments.
- Delivery cost must be separated from product price.
- Supplier settlement and reseller commission states must be explicit.
- Admin money/status actions must include clear affordances and serious visual treatment.
- Risk, restriction, and dispute states must not be hidden behind neutral styling.

Ghana-market UX principles:

- Use GH₵ for money everywhere.
- Use realistic Ghana locations such as Accra, Kumasi, Tema, East Legon, Madina, Spintex, Osu, Adenta, Kasoa, and Takoradi in mock data.
- Treat Pay on Delivery as a trust feature, not an afterthought.
- Avoid jargon in customer and supplier-facing flows.
- Use WhatsApp as a familiar sharing/support pattern where relevant.
- Keep forms short on mobile and break long supplier/admin forms into sections.

Risellar should feel like a modern Ghana ecommerce/fintech platform: clean, calm, trustworthy, useful, and strong enough for real operations.

Risellar should not look like:

- A generic Western ecommerce template.
- A cheap student project.
- A colorful childish app.
- A crypto dashboard.
- A complicated enterprise ERP.
- A rough marketplace clone.
- An inconsistent AI-generated UI.

## 4. Product/Platform Context

Risellar is not a native mobile app. Build future UI as a Next.js PWA/web implementation.

Primary platform directions:

- Reseller experience: mobile-first PWA.
- Supplier experience: mobile-first PWA.
- Customer checkout: mobile web checkout from reseller links.
- Admin: desktop web dashboard.

Core business model:

- Suppliers list products.
- Risellar adds a small platform margin.
- Resellers add their profit within allowed limits.
- Customers buy from reseller links.
- Pay on Delivery is important because customers may not trust paying before receiving goods.
- Delivery is separate from product price.
- Stock reservation, customer confirmation, delivery quote approval, supplier settlements, reseller commissions, and admin risk queues are core product patterns.

## 5. Color System

Use these exact CSS token names. Do not introduce new UI colors without updating this guide.

| Token | Value | Use |
| --- | --- | --- |
| `--color-primary` | `#086B4F` | Primary brand green, main buttons, active nav, trusted confirmations. |
| `--color-primary-hover` | `#075C44` | Primary button hover and strong green hover states. |
| `--color-primary-active` | `#054936` | Pressed/active primary states. |
| `--color-primary-soft` | `#E6F4EF` | Soft trust/success backgrounds, selected cards, Pay on Delivery reassurance. |
| `--color-primary-subtle` | `#F1FAF6` | Very soft green screen areas and quiet highlights. |
| `--color-secondary` | `#11865E` | Secondary green, progress, charts, alternate positive emphasis. |
| `--color-accent` | `#F5B300` | Amber/gold accent for earnings, promoted items, warning highlights. |
| `--color-accent-hover` | `#D99A00` | Amber button hover. |
| `--color-accent-soft` | `#FFF3CC` | Pending/warning backgrounds and soft earnings moments. |
| `--color-bg` | `#F7F8F7` | Default app background. |
| `--color-bg-cream` | `#FFF8EA` | Warm brand background sections and mobile auth/onboarding. |
| `--color-surface` | `#FFFFFF` | Cards, panels, inputs, modals. |
| `--color-surface-muted` | `#F1F3F4` | Muted panels, table header backgrounds, disabled surfaces. |
| `--color-border` | `#E5E7EB` | Default border. |
| `--color-border-strong` | `#D0D5DD` | Stronger dividers and table boundaries. |
| `--color-text` | `#1A1C1E` | Primary text. |
| `--color-text-muted` | `#667085` | Secondary text, helper text, labels. |
| `--color-text-subtle` | `#98A2B3` | Placeholder text and low-emphasis metadata. |
| `--color-success` | `#11865E` | Success badges and completed/verified states. |
| `--color-success-soft` | `#E6F4EF` | Success backgrounds. |
| `--color-warning` | `#F5B300` | Pending, due, low stock, warning state. |
| `--color-warning-soft` | `#FFF3CC` | Soft warning backgrounds. |
| `--color-danger` | `#E5484D` | Failed, rejected, overdue, suspended, destructive actions. |
| `--color-danger-hover` | `#C93C42` | Danger hover state. |
| `--color-danger-soft` | `#FDECEC` | Soft danger backgrounds. |
| `--color-info` | `#2563EB` | Informational states only, used sparingly. |
| `--color-info-soft` | `#EAF1FF` | Soft info backgrounds. |
| `--color-disabled-bg` | `#EAECF0` | Disabled controls. |
| `--color-disabled-text` | `#98A2B3` | Disabled text/icons. |
| `--color-focus-ring` | `#B7E4D4` | Focus outline/ring. |

Chart colors:

- Primary series: `#086B4F`
- Positive/settled: `#11865E`
- Earnings/highlight: `#F5B300`
- Danger/overdue: `#E5484D`
- Info: `#2563EB`
- Neutral: `#98A2B3`

Tailwind token suggestions:

```ts
colors: {
  primary: {
    DEFAULT: "#086B4F",
    hover: "#075C44",
    active: "#054936",
    soft: "#E6F4EF",
    subtle: "#F1FAF6",
  },
  secondary: "#11865E",
  accent: {
    DEFAULT: "#F5B300",
    hover: "#D99A00",
    soft: "#FFF3CC",
  },
  bg: {
    DEFAULT: "#F7F8F7",
    cream: "#FFF8EA",
  },
  surface: {
    DEFAULT: "#FFFFFF",
    muted: "#F1F3F4",
  },
  border: {
    DEFAULT: "#E5E7EB",
    strong: "#D0D5DD",
  },
  text: {
    DEFAULT: "#1A1C1E",
    muted: "#667085",
    subtle: "#98A2B3",
  },
  success: { DEFAULT: "#11865E", soft: "#E6F4EF" },
  warning: { DEFAULT: "#F5B300", soft: "#FFF3CC" },
  danger: { DEFAULT: "#E5484D", hover: "#C93C42", soft: "#FDECEC" },
  info: { DEFAULT: "#2563EB", soft: "#EAF1FF" },
}
```

Exact Tailwind theme suggestion:

```ts
theme: {
  extend: {
    colors: {
      primary: {
        DEFAULT: "#086B4F",
        hover: "#075C44",
        active: "#054936",
        soft: "#E6F4EF",
        subtle: "#F1FAF6",
      },
      secondary: "#11865E",
      accent: {
        DEFAULT: "#F5B300",
        hover: "#D99A00",
        soft: "#FFF3CC",
      },
      bg: {
        DEFAULT: "#F7F8F7",
        cream: "#FFF8EA",
      },
      surface: {
        DEFAULT: "#FFFFFF",
        muted: "#F1F3F4",
      },
      border: {
        DEFAULT: "#E5E7EB",
        strong: "#D0D5DD",
      },
      text: {
        DEFAULT: "#1A1C1E",
        muted: "#667085",
        subtle: "#98A2B3",
      },
      success: { DEFAULT: "#11865E", soft: "#E6F4EF" },
      warning: { DEFAULT: "#F5B300", soft: "#FFF3CC" },
      danger: { DEFAULT: "#E5484D", hover: "#C93C42", soft: "#FDECEC" },
      info: { DEFAULT: "#2563EB", soft: "#EAF1FF" },
      disabled: { bg: "#EAECF0", text: "#98A2B3" },
      focus: { ring: "#B7E4D4" },
    },
    fontFamily: {
      sans: [
        "Plus Jakarta Sans",
        "Inter",
        "ui-sans-serif",
        "system-ui",
        "-apple-system",
        "BlinkMacSystemFont",
        "Segoe UI",
        "sans-serif",
      ],
    },
    borderRadius: {
      xs: "6px",
      sm: "8px",
      md: "12px",
      lg: "16px",
      xl: "20px",
      "2xl": "24px",
      pill: "999px",
    },
    boxShadow: {
      xs: "0 1px 2px rgba(16, 24, 40, 0.05)",
      sm: "0 4px 12px rgba(16, 24, 40, 0.06)",
      md: "0 10px 24px rgba(16, 24, 40, 0.08)",
      lg: "0 16px 40px rgba(16, 24, 40, 0.10)",
    },
    spacing: {
      1: "4px",
      2: "8px",
      3: "12px",
      4: "16px",
      5: "20px",
      6: "24px",
      8: "32px",
      10: "40px",
      12: "48px",
    },
  },
}
```

Color rules:

- Do not use bright neon green.
- Do not use pure black for large text areas.
- Do not use too many accent colors on one screen.
- Use amber mainly for highlights, warnings, promoted items, earnings moments, and logo accent moments.
- Use red only for real danger, overdue, failed, rejected, restricted, or suspended states.
- Use soft green for trust, success, Pay on Delivery reassurance, and safe confirmations.
- Use blue sparingly for informational states where green/amber/red do not apply.

## 6. Typography System

Font stack:

```css
font-family: "Plus Jakarta Sans", Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
```

Use Plus Jakarta Sans as the first choice. Use Inter as fallback only when Plus Jakarta Sans is unavailable.

Weights:

- 400 regular: body text.
- 500 medium: labels, metadata, table cells.
- 600 semibold: card titles, buttons, important amounts.
- 700 bold: page titles, section titles, key values.
- 800 extra bold: rare display/metric emphasis.

Mobile/PWA type scale:

| Role | Size | Weight | Line height |
| --- | --- | --- | --- |
| Display / hero | 32px | 700/800 | 40px |
| Screen title | 24px | 700 | 32px |
| Page title | 22px | 700 | 30px |
| Section title | 17-18px | 600/700 | 24px |
| Card title | 15-16px | 600/700 | 22px |
| Body | 14-15px | 400/500 | 22px |
| Small text | 13px | 400/500 | 18px |
| Caption | 12px | 400/500 | 16px |
| Badge text | 11-12px | 600 | 14px |
| Button text | 14-15px | 600/700 | 20px |

Admin type scale:

| Role | Size | Weight |
| --- | --- | --- |
| Admin page title | 26-30px | 700 |
| Admin section title | 18-20px | 600/700 |
| Admin card metric value | 24-30px | 700/800 |
| Admin metric label | 13-14px | 500 |
| Table header | 12-13px | 600/700 |
| Table body | 13-14px | 400/500 |
| Sidebar item | 14px | 500/600 |

Typography rules:

- Keep typography calm and readable.
- Avoid oversized text inside mobile cards.
- Keep admin tables dense but readable.
- Use bold for hierarchy, important values, and GH₵ amounts.
- Use green and amber text emphasis sparingly.
- Letter spacing should normally be `0`.

## 7. Spacing System

Use an 8px-based scale with 4px support.

| Token | Value | Use |
| --- | --- | --- |
| `--space-1` | 4px | Tiny gaps, icon offsets. |
| `--space-2` | 8px | Icon/text gaps, compact stacks. |
| `--space-3` | 12px | Compact component gaps. |
| `--space-4` | 16px | Standard mobile padding. |
| `--space-5` | 20px | Medium section gaps. |
| `--space-6` | 24px | Large section gaps, admin padding. |
| `--space-8` | 32px | Screen-level spacing. |
| `--space-10` | 40px | Desktop section spacing. |
| `--space-12` | 48px | Large desktop spacing. |

Mobile/PWA spacing:

- Screen horizontal padding: 16px.
- Compact screens can use 14px; avoid less than 12px.
- Major section gap: 20-24px.
- Card gap: 12-16px.
- Card internal padding: 14-18px.
- Product card padding: 12-14px.
- Form field gap: 12-14px.
- Button top margin in forms: 16-20px.
- Bottom navigation must account for safe area.

Admin spacing:

- Page padding: 24px.
- Dashboard grid gap: 16-20px.
- Card padding: 18-24px.
- Table cell padding: 12-16px.
- Sidebar width: 240-280px.
- Topbar height: 64-72px.
- Main layout should feel spacious but not stretched.

Spacing rules:

- Do not use random margins per screen.
- Do not create inconsistent button spacing.
- Components own their internal spacing.
- Pages compose components instead of inventing new spacing systems.

## 8. Layout System

Shared layout rules:

- Use mobile-first responsive layouts for reseller, supplier, and customer checkout.
- Use desktop-first operational layouts for admin.
- Cards and lists are the default mobile structure.
- Tables are acceptable in admin and should be avoided on mobile unless specifically designed.
- Use clear page headers, section headers, and action areas.
- Keep primary CTAs visible and predictable.
- Never let bottom navigation cover sticky primary actions.

Recommended app shells:

- Reseller PWA: mobile header, card/list content, bottom nav.
- Supplier PWA: mobile header, operational cards/lists, bottom nav.
- Customer checkout: simple linear flow with sticky CTA when useful, no bottom tab nav.
- Admin dashboard: left sidebar, topbar, main workspace, metric row, filters, tables, detail panels, and queue panels.

## 9. Border Radius System

| Token | Value | Use |
| --- | --- | --- |
| `--radius-xs` | 6px | Small utility elements. |
| `--radius-sm` | 8px | Compact controls, small admin table elements. |
| `--radius-md` | 12px | Buttons, inputs, compact cards. |
| `--radius-lg` | 16px | Standard cards, product cards, panels. |
| `--radius-xl` | 20px | Prominent cards, wallet cards, settlement panels. |
| `--radius-2xl` | 24px | Large feature cards and major mobile panels. |
| `--radius-pill` | 999px | Badges, chips, pill actions. |

Usage:

- Buttons: 12-14px.
- Inputs: 12-14px.
- Cards: 16-20px.
- Product cards: 16px.
- Status badges: pill.
- Admin panels: 16-20px.
- Mobile device-like containers, if used in showcase contexts only: 28px+.

Rules:

- Avoid sharp corners except thin table/grid boundaries.
- Do not mix too many radius values on one screen.
- Use pill radius only for badges, chips, and small rounded controls.

## 10. Shadow/Elevation System

| Token | Value | Use |
| --- | --- | --- |
| `--shadow-xs` | `0 1px 2px rgba(16, 24, 40, 0.05)` | Border-like lift. |
| `--shadow-sm` | `0 4px 12px rgba(16, 24, 40, 0.06)` | Mobile cards. |
| `--shadow-md` | `0 10px 24px rgba(16, 24, 40, 0.08)` | Modals, elevated panels. |
| `--shadow-lg` | `0 16px 40px rgba(16, 24, 40, 0.10)` | Major admin panels only when needed. |

Elevation rules:

- Cards mostly use border plus `shadow-xs` or `shadow-sm`.
- Important panels can use `shadow-md`.
- Buttons use minimal or no shadow.
- Avoid harsh black shadows.
- Avoid heavy glassmorphism.
- Use gradients only for primary dashboard/hero cards when they reinforce the green brand direction.

## 11. Button System

Button heights:

| Context | Size | Height |
| --- | --- | --- |
| Mobile primary large | Large | 52px |
| Mobile primary normal | Normal | 48px |
| Mobile compact | Compact | 40px |
| Tiny/table action | Tiny | 32-36px |
| Admin primary | Normal | 40-44px |
| Admin table action | Compact | 32-36px |

Padding:

- Large: 16-20px horizontal.
- Normal: 14-18px horizontal.
- Compact: 12-14px horizontal.

Variants:

- Primary: green background, white text, darker green hover, deepest green active.
- Secondary: amber/gold background, charcoal or deep green text, darker amber hover.
- Outline: white background, primary or light border, primary/dark text, soft green hover.
- Ghost: transparent background, primary/dark text, soft green/gray hover.
- Danger: danger red background, white text, darker red hover.
- Soft warning: pale amber background, dark amber/brown text, amber-tinted border.

Button rules:

- One primary action per screen should be obvious.
- Avoid two strong primary buttons side by side.
- Destructive actions must never look like primary actions.
- Labels must be action-oriented.
- Avoid vague labels like "Submit" unless context is obvious.

Good labels:

- Add to My Shop
- Confirm Order
- Approve Delivery Quote
- Settle Now
- Upload Proof
- Release Commission
- Mark as Ready
- Request Price Change

Interaction:

- Hover transition: 150-200ms ease-out.
- Mobile active press: `scale(0.98)` only if used consistently.
- Focus ring: 2px soft green outline.
- Disabled: no hover, `cursor: not-allowed`, 50-60% opacity.

## 12. Input/Form System

Input heights:

- Mobile: 48-52px.
- Admin: 40-44px.

Input style:

- White background.
- Light gray border.
- 12-14px radius.
- Label above input.
- Optional helper text below.
- Error text in danger color.
- Focus border primary green.
- Focus ring very soft green.

Input states:

- Default.
- Hover.
- Focused.
- Error.
- Disabled.
- Success/verified.

Form layout:

- Labels: 13-14px semibold.
- Required fields: subtle red asterisk.
- Helper text: 12-13px muted.
- Form group gap: 12-16px.
- Long forms: break into cards or sections.

Important fields requiring clear labels and validation:

- Product name.
- Base price.
- Stock quantity.
- Low stock threshold.
- Customer address.
- Delivery area.
- MoMo/payment reference.
- Settlement proof upload.
- Role selection.
- Ghana Card/verification upload placeholder.

## 13. Card System

Cards are the backbone of Risellar.

Standard card:

- Background: `--color-surface`.
- Border: 1px solid `--color-border`.
- Radius: 16-20px.
- Padding: 16px mobile, 20-24px desktop.
- Shadow: subtle.

Mobile card types:

- Product card.
- Product detail card.
- Price breakdown card.
- Order card.
- Wallet card.
- Settlement card.
- Delivery option card.
- Payment method card.
- Role card.
- Empty state card.
- Notification card.
- Insight card.
- Promotion card.

Admin card types:

- Metric card.
- Table panel.
- Queue card.
- Detail panel.
- Risk card.
- Settlement summary.
- Audit log card.
- Manual override warning card.

Rules:

- Cards should be consistent and reusable.
- Avoid random padding.
- Use section headers consistently.
- Use badges to communicate state.
- Use pale green, amber, or red backgrounds only for state messages.
- Price breakdown cards use clear rows and a strong final amount.
- Financial cards must be easy to scan.

## 14. Status Badge System

Badge style:

- Height: 22-28px.
- Padding: 6-10px horizontal.
- Radius: pill.
- Text: 11-12px semibold.
- Must include readable text, not color alone.

Status categories:

| Category | Examples | Style |
| --- | --- | --- |
| Success/green | Paid, Completed, Confirmed, Available, Active, Verified, Settlement Paid | Green text on soft green. |
| Warning/amber | Pending, Awaiting Confirmation, Due, Needs Review, Low Stock, Verification Pending | Amber/brown text on soft amber. |
| Danger/red | Overdue, Failed, Rejected, Suspended, Out of Stock, Restricted | Red text on soft red. |
| Info/blue or muted | Processing, Preparing, Partially Paid, Quote Ready, In Review | Blue or muted text on soft info/gray. |
| Neutral/gray | Cancelled, Inactive, Closed | Muted text on muted surface. |

Rules:

- Status colors must be consistent across the entire app.
- Do not use different colors for the same status on different screens.
- Every important status must have a badge.
- Badge text should be short and clear.

Status-to-color mapping:

| Status | Badge variant | Color rule |
| --- | --- | --- |
| Awaiting Confirmation | Warning | Amber text on soft amber. |
| Confirmed | Success | Green text on soft green. |
| Preparing | Info | Blue or muted info badge. |
| Delivery Quote Pending | Warning | Amber text on soft amber. |
| Delivery Approved | Success | Green text on soft green. |
| Out for Delivery | Info | Blue or muted info badge. |
| Delivered | Success | Green text on soft green. |
| Payment Collected | Success | Green text on soft green. |
| Settlement Due | Warning | Amber text on soft amber. |
| Settlement Overdue | Danger | Red text on soft red. |
| Settlement Paid | Success | Green text on soft green. |
| Commission Pending | Warning | Amber text on soft amber. |
| Commission Available | Success | Green text on soft green. |
| Pending Review | Warning | Amber text on soft amber. |
| Approved | Success | Green text on soft green. |
| Rejected | Danger | Red text on soft red. |
| Restricted | Danger | Red text on soft red. |
| Suspended | Danger | Red text on soft red. |
| Low Stock | Warning | Amber text on soft amber. |
| Out of Stock | Danger | Red text on soft red. |
| Failed | Danger | Red text on soft red. |
| Cancelled | Neutral | Muted text on muted surface. |
| Dispute Opened | Warning | Amber text on soft amber unless severity is high, then danger. |

## 15. Mobile/PWA Layout Rules

Mobile screens are PWA screens, not native app screens.

Rules:

- Work beautifully from 360px width upward.
- Main content padding: 16px.
- Bottom navigation for reseller and supplier.
- Sticky bottom actions where useful.
- Header with back button, title, and optional action icon.
- Avoid dense desktop tables on mobile.
- Use cards and lists.
- Use full-width primary buttons.
- Keep important financial amounts visible and clear.

Bottom navigation:

- Height: 72-84px including safe area.
- 4-5 main items.
- Icons above labels.
- Active item uses primary green.
- Center action can be circular only if it matches the overall system.
- Bottom nav must not cover page CTAs.

Recommended reseller tabs:

- Home.
- Shop.
- Orders.
- Wallet.
- Account.

Recommended supplier tabs:

- Overview.
- Products.
- Orders.
- Settlements.
- More.

## 16. Customer Checkout Rules

Customer checkout is mobile web from reseller links. It should feel safe, simple, and linear.

Required patterns:

- No bottom tab navigation.
- Step-by-step checkout.
- Sticky primary CTA when helpful.
- Clear Pay on Delivery reassurance.
- Product price and delivery cost separated.
- Delivery quote approval shown before dispatch.
- Order confirmation required to reserve item.
- Order success includes tracking and support path.

Customer copy should be direct:

- Pay when your item arrives.
- Delivery cost will be confirmed before dispatch.
- Confirm your order to reserve this item.
- We will contact you if delivery details need review.

## 17. Supplier PWA Rules

Supplier screens are mobile-first but operational. Suppliers need to manage products, stock, orders, proof, settlements, restrictions, and team permissions.

Supplier UI must prioritize:

- Product list and approval status.
- Add/edit product with clear base price and stock fields.
- Order preparation flow.
- Settlement due/overdue panels.
- Proof upload.
- Inventory counts: total, reserved, available, sold.
- Low stock and out-of-stock states.
- Price change request states.
- Team member and inventory manager permissions when relevant.

Supplier screens should stay simple, but not hide business-critical numbers.

## 18. Reseller PWA Rules

Reseller screens should make it easy to find products, understand profit, share listings, track orders, and manage wallet/commission.

Reseller UI must prioritize:

- Dashboard with earnings, orders, and quick actions.
- Catalog browsing with trusted product cards.
- Product detail with price breakdown and profit calculator.
- Add to My Shop action.
- My Shop management.
- Orders and customer confirmation state.
- Wallet balance, pending commission, withdrawal state.
- Promotions and WhatsApp template cards.

Reseller profit must be transparent:

- Show reseller cost.
- Show suggested selling price.
- Show max allowed price.
- Show selected margin.
- Show expected profit.

## 19. Admin Dashboard Rules

Admin is desktop-first and operational.

Layout:

- Left sidebar.
- Topbar.
- Main content area.
- Metric cards row.
- Table panels.
- Detail panels.
- Filter bars.
- Action menus.

Sidebar:

- Deep green background.
- Risellar logo at top.
- Active item with stronger green or soft highlight.
- Icons and labels.
- Width around 240-280px.

Topbar:

- Search.
- Notifications.
- Admin profile.
- Workspace/store selector if needed.
- Height around 64-72px.

Tables:

- Small readable headers.
- Row height around 52-64px.
- Badges for statuses.
- Actions on right.
- Filters above tables.
- Pagination where needed.
- No overcrowding with tiny text.

Admin actions affecting money/status:

- Must look serious and controlled.
- Use confirmation panels or modals for high-risk actions.
- Manual overrides must use restricted/danger styling.
- Audit trail should be visible for sensitive operations.

## 20. Transitions/Interactions

Interaction tokens:

- Default transition: 150ms.
- Larger panel/page transition: 200-250ms.
- Hover/enter easing: ease-out.
- Exit easing: ease-in.

Recommended classes:

- `transition-colors duration-150 ease-out`
- `transition-shadow duration-200 ease-out`
- `transition-transform duration-150 ease-out`
- `hover:-translate-y-[1px]` only for clickable cards.
- `active:scale-[0.98]` for mobile actions only if consistent.

Rules:

- Do not over-animate.
- Buttons can darken on hover.
- Clickable cards can lift slightly.
- Inputs highlight border on focus.
- Badges should not animate.
- Admin table rows can have subtle hover.
- Mobile list items can have subtle press feedback.
- Modals/drawers should fade or slide smoothly.

Avoid:

- Bouncing animations.
- Heavy motion.
- Random page transitions.
- Inconsistent hover effects.
- Large scaling on cards/buttons.

## 21. Responsive Breakpoints

| Breakpoint | Width |
| --- | --- |
| Mobile | 360-480px |
| Large mobile | 481-640px |
| Tablet | 641-1024px |
| Desktop | 1025px+ |
| Admin ideal | 1280px+ |

Rules:

- Reseller, supplier, and customer PWA screens must be excellent on mobile.
- Reseller and supplier may expand to tablet/desktop, but mobile remains primary.
- Admin must be desktop-first and should not break on tablet.
- Do not force admin tables into tiny mobile layouts unless a future task requires it.
- Customer checkout must remain smooth on small mobile screens.

## 22. Component Library Rules

Future UI should be built from shared components. Each component must document purpose, visual style, spacing, variants, states, usage, and do/don't rules.

Required components:

- Button: actions across all surfaces; variants primary, secondary, outline, ghost, danger, soft warning; consistent height/radius/focus.
- Input: text and numeric entry; labeled; states default, focus, error, disabled, success.
- Select: option choice; same height/radius as inputs; clear placeholder and disabled state.
- Textarea: long notes, rejection reasons, support messages; labeled and resizable only where useful.
- Checkbox: binary settings and permission toggles; minimum 44px touch target on mobile.
- Radio card: role, delivery option, payment method, and plan-like selections; selected state uses soft green.
- File upload card: Ghana Card, settlement proof, product images; shows accepted formats, upload progress, error, and success.
- Search bar: catalog/admin search; icon left, clear action optional, compact admin version.
- Card: base container; white surface, light border, radius 16-20px, subtle shadow.
- Metric card: admin/reseller/supplier key numbers; label, value, trend/status.
- Product card: product image, name, supplier/base or customer price, stock/status, action.
- Product list item: compact mobile/admin product row with thumbnail, status, and action.
- Price breakdown card: rows for supplier base, platform margin, reseller margin, customer price, delivery, final amount.
- Order card: order ID, customer/product, status badge, amount, date, next action.
- Settlement card: due amount, due date, status, proof/action, restriction warning when needed.
- Commission card: pending/available/released commission, order link, expected date.
- Wallet card: balance, pending, withdrawals, failed/pending state.
- Status badge: consistent color/status mapping.
- Category chip: product/category filter; pill style; selected soft green.
- Role card: onboarding role selection; icon, title, short explanation.
- Delivery option card: quote, area, timing, approval state.
- Payment method card: Pay on Delivery first-class, other methods later if approved.
- Confirmation panel: serious confirmation for money/status changes.
- Empty state: helpful heading, short explanation, primary action.
- Error state: clear cause, recovery action, support path if needed.
- Success state: confirmation, next step, tracking/reference.
- Warning banner: pending, due, low stock, quote waiting.
- Timeline: checkout, order tracking, settlement/audit progress.
- Notification item: icon, title, status/time, action if needed.
- Admin sidebar: deep green, logo, active state, grouped nav.
- Admin topbar: search, notifications, profile.
- Admin table: dense readable rows, filters, badges, actions, pagination.
- Admin filter bar: search, status filter, date range, export/action.
- Admin detail panel: selected order/supplier/product details with action area.
- Admin queue card: count, priority, short list, view all.
- Audit log item: actor, action, timestamp, before/after summary.
- Manual override panel: restricted styling, required reason, audit reminder.
- WhatsApp template card: caption preview, copy/share action, product trust details.

Component do/don't rules:

- Do reuse shared tokens and components.
- Do include loading, empty, error, disabled, and focus states.
- Do keep touch targets at least 44px.
- Do not create one-off button, badge, or card styles.
- Do not use lorem ipsum.
- Do not hide business-critical statuses in muted text.

Component sizing table:

| Element | Mobile/PWA size | Admin/desktop size | Notes |
| --- | --- | --- | --- |
| Primary button large | 52px height, 16-20px horizontal padding | 44px height, 16-18px horizontal padding | Use for main form/checkout action. |
| Primary button normal | 48px height, 14-18px horizontal padding | 40-44px height | Default action size. |
| Compact button | 40px height, 12-14px horizontal padding | 32-36px table/action height | Use in dense lists and admin tables. |
| Icon button | 44px touch target, 20-24px icon | 32-40px target, 16-20px icon | Icon-only buttons require `aria-label`. |
| Input | 48-52px height | 40-44px height | 12-14px radius, label above. |
| Select | 48-52px height | 40-44px height | Match input sizing. |
| Textarea | Minimum 96px height | Minimum 88px height | Use helper/error text below. |
| Badge | 22-28px height, 11-12px text | 22-26px height, 11-12px text | Pill radius only. |
| Category chip | 32-36px height | 28-32px height | Selected state uses soft green. |
| Standard card padding | 14-18px | 18-24px | Radius 16-20px. |
| Product card padding | 12-14px | 14-18px | Image ratio must stay stable. |
| Metric card padding | 16px | 18-24px | Values use 24-30px on admin. |
| Mobile header | 56-64px height | Not primary | Back/title/action layout. |
| Mobile bottom nav | 72-84px including safe area | Not primary | 4-5 items, active green. |
| Admin sidebar | Not primary | 240-280px width | Deep green, grouped nav. |
| Admin topbar | Not primary | 64-72px height | Search, notifications, profile. |
| Admin table row | Avoid dense tables | 52-64px row height | 12-16px cell padding. |
| Admin table header | Avoid dense tables | 40-48px height | 12-13px semibold text. |

## 23. State Design Rules

Every state should include an icon or simple illustration, clear heading, short explanation, primary action, optional secondary action, and status badge where relevant.

State requirements:

- Loading: skeletons for cards/tables, spinner only for short button actions, no trapped UI.
- Empty: helpful and action-oriented, never blank; example: "Your shop is empty" with "Add products".
- Error: plain explanation and recovery path; avoid technical jargon.
- Success: confirm what happened and what comes next.
- Warning: amber styling; explain what needs attention.
- Restricted: red/amber serious panel; show reason and next step.
- Suspended: red styling; support/contact path; no ambiguous actions.
- Pending review: amber/info badge; expected next step.
- Out of stock: red badge; disable selling action; show restock path for supplier.
- Low stock: amber badge; show remaining stock and restock action.
- Overdue settlement: red badge/panel; show due amount, date, restriction risk, settle/upload proof action.
- Delivery quote pending: amber badge; explain customer will approve delivery before dispatch.
- Awaiting customer confirmation: amber badge; show reminder/contact action.
- Commission pending: amber/soft green panel; explain commission depends on settlement/confirmation.
- Withdrawal failed: red badge; explain failure and retry/support action.
- Payment failed: red badge; recovery path and support.
- Support issue submitted: success/info state; show ticket/reference and next update.

## 24. Special Risellar UI Patterns

Price breakdown pattern:

- Supplier base price.
- Risellar/platform margin.
- Reseller margin.
- Customer price.
- Delivery estimate/final quote, if relevant.
- Final total in bold.

Reseller profit pattern:

- Reseller cost.
- Suggested selling price.
- Max allowed price.
- Your margin.
- Expected profit.

Supplier settlement pattern:

- Customer paid.
- Supplier base amount.
- Amount due to Risellar.
- Due date.
- Status.
- Upload proof / Settle Now CTA.

Customer Pay on Delivery trust pattern:

- Pay when your item arrives.
- Order confirmation required.
- Delivery cost approved before dispatch.
- Support available.

Stock pattern:

- Total stock.
- Reserved stock.
- Available stock.
- Sold stock.
- Low stock threshold.
- Stock movement history.

Admin queue pattern:

- Queue count.
- Priority/risk.
- Table/list of items.
- Fast actions.
- View all.
- Audit trail.

Risk pattern:

- Risk level.
- Reason.
- Recommended action.
- Restriction state.
- Audit log.

Promotion pattern:

- Sponsored/featured badge.
- Eligibility checks.
- Product trust.
- Stock availability.
- Performance metrics.

## 25. Screen Pattern Rules

Reseller dashboard pattern:

- Top greeting with reseller name and location.
- Earnings or wallet summary in a deep green card.
- Secondary metric cards for pending commission, orders, and shop/product count.
- Quick actions in small cards with outline icons.
- Product/trending sections use product cards with image, price, estimated profit, and status.
- Bottom navigation is always present with Home, Shop, Orders, Wallet, and Account.

Reseller product detail pattern:

- Large product image, badge, product name, category, rating, and stock status.
- Price breakdown card with supplier base price, platform margin, reseller cost, suggested price, max price, margin, and expected profit.
- Primary CTA is Add to My Shop, Set Selling Price, or Share to WhatsApp depending on step.
- Delivery fee note must clarify that delivery is separate and set/confirmed before dispatch.

Reseller wallet/commission pattern:

- Available balance in a deep green card.
- Pending commission card with explanation and expected availability.
- Withdraw to MoMo flow uses clear amount input, provider, number, account name, and confirmation.
- Failed withdrawal must show reason and recovery actions.
- Commission pending must explain supplier settlement/customer confirmation dependency.

Supplier dashboard pattern:

- Top summary card for total inventory value or settlement/earnings.
- Metric cards for products, pending orders, low stock, out-of-stock, settlements due, and price requests.
- Quick actions include Add Product, Orders, Settlements, and Payouts.
- Supplier screens should feel businesslike but still mobile-simple.

Supplier inventory pattern:

- Product list with thumbnail, category, base price, stock count, and availability badge.
- Inventory dashboard shows total stock, reserved stock, available stock, sold stock, low stock alerts, and price change requests.
- Restock, variants, stock movement history, and price change request screens must preserve stock math visibility.
- Out-of-stock products disable selling and show restock action.

Supplier settlement pattern:

- Settlement due/overdue amount appears prominently.
- Rows show customer paid, supplier base amount, amount due to Risellar, due date, status, and action.
- Overdue states use danger styling and are not visually optional.
- Proof upload requires payment method, optional transaction ID, note field, file upload state, and submit action.
- Trust score and restriction levels should be visible where settlement behavior affects account access.

Customer checkout pattern:

- No bottom tab navigation.
- Simple ordered flow: shop, product detail, cart, account/phone verification, delivery details, delivery options, payment method, review, success, tracking, support.
- Pay on Delivery should be the default trust-forward payment choice.
- Product total, delivery estimate/final quote, and total payable must be separated.
- Sticky bottom CTA is allowed when it improves completion.

Customer confirmation/delivery quote pattern:

- Show step progress and current status clearly.
- Awaiting confirmation must explain the time window and consequence.
- Delivery quote approval must show destination, delivery fee, total to pay on delivery, approve CTA, and change/cancel option.
- Tracking timeline must distinguish completed, current, and pending steps.

Admin dashboard pattern:

- Desktop-first layout with deep green sidebar, topbar, metric cards, charts, recent activity, and quick actions.
- Metric cards use compact labels, large values, trend indicators, and status context.
- Admin dashboard must not become a stack of mobile cards only.
- Critical alerts, overdue settlements, and risk queues should be visible above or near the fold.

Admin queue/table pattern:

- Queue panels show count, priority, table/list, fast actions, and view-all link.
- Tables use 52-64px rows, 12-16px cell padding, small readable headers, badges, filters, and pagination.
- Actions are icon buttons or compact buttons aligned right.
- Table density should match the admin references: information-rich but not cramped.

Admin risk/manual override pattern:

- Risk panels show risk level, reason, recommended action, restriction state, and audit trail.
- Manual override panels use danger styling, required reason, and clear warning that overrides are logged.
- Money/status-changing actions must be controlled and confirmable.

Team/permissions pattern:

- Team member cards show avatar, role, status, email/phone, and overflow actions.
- Role permissions use clear can/cannot sections or matrix tables.
- Restricted access screens show lock icon, explanation, owner contact path, and request access action.
- Permission toggles must have labels and disabled states.

Empty state pattern:

- Use a friendly illustration or icon, clear heading, short explanation, primary action, and optional secondary action.
- Empty states must be specific: empty shop, no orders, no products, no approvals, no notifications, no support tickets.
- Do not use a generic empty box for every situation.

## 26. Accessibility Rules

- Text must maintain readable contrast.
- Buttons must have visible focus states.
- Inputs must have labels.
- Icon-only buttons must have `aria-label`s.
- Do not communicate status by color alone.
- Status badges need readable text.
- Error messages must be clear.
- Touch targets should be at least 44px.
- Forms should be keyboard accessible.
- Admin tables should be navigable and readable.
- Loading states must not trap users.
- Use semantic headings in order.
- Ensure modals trap focus only while open and return focus when closed.

## 27. Copywriting Rules

Copy should be clear, Ghana-friendly, trust-building, and simple.

Tone:

- Calm.
- Helpful.
- Firm for risk and settlement rules.
- Professional for admin.
- Encouraging for resellers.

Good examples:

- Pay when your item arrives.
- Delivery cost will be confirmed before dispatch.
- Your commission is pending until supplier settlement is confirmed.
- This product is out of stock.
- Supplier settlement is overdue.
- Confirm your order to reserve this item.

Avoid:

- Transaction mutation failed.
- Settlement object pending hydration.
- Vendor remittance inconsistency.
- User action required without clear explanation.

Rules:

- Use direct action labels.
- Avoid technical jargon for customers, resellers, and suppliers.
- Admin copy can be more operational, but still clear.
- Use realistic marketplace data and Ghana locations in mock screens.
- Use GH₵ for money everywhere.

## 28. Do Not Do This

- Do not use generic ecommerce template styling.
- Do not use random gradients or decorative effects outside the approved green/cream/amber direction.
- Do not change `#086B4F` as the primary green without updating this guide and documenting approval.
- Do not use oversized buttons on one page and small buttons elsewhere.
- Do not make the admin dashboard look like mobile cards only.
- Do not hide status information in secondary text.
- Do not use vague copy such as "Submit", "Proceed", or "Action Required" when a specific action is known.
- Do not allow financial screens to lack breakdowns.
- Do not make supplier settlement look optional when money is due or overdue.
- Do not use unapproved colors for statuses.
- Do not create a new card, button, badge, or table style for a single screen.
- Do not interpret phone mockups as native app implementation requirements.

## 29. Future Codex Workflow

Future UI implementation must follow this order:

1. Read this brand/UI guide.
2. Build design tokens first: colors, typography, spacing, radius, shadows, transitions.
3. Build the shared component library before page work.
4. Build a design-system gallery showing buttons, inputs, badges, cards, tables, nav, states, and financial patterns.
5. Review the gallery against the reference images.
6. Build the first 3 representative screens: one reseller PWA screen, one customer checkout screen, and one admin screen.
7. Run visual QA on those first screens.
8. Build remaining screens in batches by product area.
9. Run screenshot QA per batch.
10. Document any unavoidable deviation from this guide.

Do not build production pages before tokens and shared components exist.

## 30. Visual QA Checklist

- Colors match the approved green, gold, cream, white, gray, and charcoal palette.
- Fonts match Plus Jakarta Sans or approved fallback.
- Button heights match the sizing table.
- Input heights and labels match the form system.
- Spacing matches the 4/8px scale.
- Card padding, radius, border, and shadow match the card system.
- Badges match the status-to-color table.
- Table density matches the admin references.
- Mobile bottom nav matches the PWA references.
- Admin sidebar matches the deep green desktop references.
- Financial breakdowns are clear and use GH₵.
- Statuses are visible and not communicated by color alone.
- Empty/error/success/warning states include clear copy and actions.
- No one-off styles were added.
- Phone screens were implemented as PWA/mobile web screens, not native mobile.

## 31. Non-Negotiable UI Rules

1. All new UI must use the design tokens in this guide.
2. All new pages must use existing shared components where possible.
3. Do not create one-off button styles.
4. Do not create one-off card styles.
5. Do not create new colors without updating this guide.
6. Do not use random Tailwind spacing values unless justified.
7. Do not use lorem ipsum.
8. Use GH₵ for money everywhere.
9. Use Ghana locations and realistic marketplace data in mock screens.
10. Keep reseller, supplier, customer, and admin experiences visually connected.
11. Empty states must be helpful and action-oriented.
12. Danger states must be clear but not overly scary.
13. Financial breakdowns must be transparent and easy to scan.
14. Admin actions that affect money/status must look serious and controlled.
15. Pay on Delivery trust messages must be clear and consistent.
16. Do not build native mobile UI patterns as if this were Expo/React Native.
17. Do not redesign the approved green direction.

## 32. Before Building Any UI, Codex Must Check

- Did I read this guide?
- Am I using the approved color tokens?
- Am I using the approved typography?
- Am I using the approved spacing?
- Am I using existing components?
- Am I avoiding one-off styles?
- Does this match the reference images and approved brief direction?
- Did I avoid redesigning?
- Did I keep Ghana/Risellar business context?
- Did I separate product price from delivery cost where relevant?
- Did I use GH₵ for money?
- Did I include clear state, loading, empty, error, disabled, and focus handling?
- Did I make Pay on Delivery trust messages clear where relevant?
- Did I document any unavoidable deviation?
