# Risellar UI Reference Image Audit

## Purpose

This audit records the Risellar UI reference images used to strengthen `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`. It lists whether each requested reference was found, which UI area it covers, the practical design rules extracted from it, components and patterns it contributes, and any inconsistencies or ambiguities future Codex tasks must understand.

## Important Interpretation Rule

All phone mockups in the references must be interpreted as mobile PWA/web screens. Some images label phone sections as iOS/Android, but Risellar's approved implementation direction is Next.js PWA/web:

- Reseller: mobile-first PWA.
- Supplier: mobile-first PWA.
- Customer checkout: mobile web checkout from reseller links.
- Admin: desktop web dashboard.

Do not use the phone frames as justification to build Expo, React Native, or native mobile screens.

## Image Availability Summary

Six canonical image filenames were found in `C:\Users\Nana Kwadwo\Downloads`. Seven additional requested references were available as dated `ChatGPT Image...png` files rather than the canonical filenames listed in the original brief.

No required design area is completely missing because each missing canonical filename has a matching attached/downloaded alternate image.

## Reference Image Details

| Requested filename | Found? | Actual file reviewed | UI area covered | Important design rules extracted | Components/patterns contributed | Inconsistencies or ambiguities |
| --- | --- | --- | --- | --- | --- | --- |
| `risellar_product_and_app_design_showcase.png` | Found | `C:\Users\Nana Kwadwo\Downloads\risellar_product_and_app_design_showcase.png` | Master brand, reseller dashboard/detail, customer checkout, supplier settlement, admin overview. | Deep emerald is primary; amber/gold is accent; cream is warm support background; cards are white with soft borders; GH₵ amounts are bold; delivery is separate from product price. | Logo style, color palette, typography, buttons, status badges, product card, price breakdown, order detail, admin sidebar/table/cards. | The image labels reseller/supplier as iOS/Android; treat these as PWA phone mockups only. |
| `risellar_mobile_app_mockup_ui_design.png` | Found | `C:\Users\Nana Kwadwo\Downloads\risellar_mobile_app_mockup_ui_design.png` | Reseller PWA onboarding, catalog, product detail, selling price calculator, shop, orders, wallet, withdrawal, notifications. | Bottom nav is persistent; reseller flow is action-forward; profit must be clear; product cards need image, price, profit, and status; wallet uses green balance card and clear pending commission. | Reseller dashboard, bottom nav, product list, product detail, selling price calculator, Add to My Shop success, My Shop preview, WhatsApp share card, wallet, transaction history, notifications. | Dated duplicate `ChatGPT Image Jul 12, 2026, 11_36_53 PM.png` matches this direction; use canonical file as primary. |
| `customer_checkout_flow_steps_overview.png` | Found | `C:\Users\Nana Kwadwo\Downloads\customer_checkout_flow_steps_overview.png` | Customer mobile web checkout from reseller shop through tracking/support. | Checkout is linear; Pay on Delivery is default/trust-first; delivery estimate and final quote stay separate; customer phone verification is simple; order review must include total range or final total. | Reseller shop page, product detail, cart, account/OTP, delivery details, delivery options, payment method, order review, success, tracking, support. | Customer checkout has no bottom nav; browser chrome in mockups reinforces mobile web. |
| `risellar_supplier_app_ui_showcase.png` | Found | `C:\Users\Nana Kwadwo\Downloads\risellar_supplier_app_ui_showcase.png` | Supplier onboarding, product management, orders/preparation, settlements, support/settings. | Supplier keeps base price; settlement due is prominent; supplier dashboards show inventory/orders/settlement metrics; payout setup and Ghana Card verification are first-class. | Supplier onboarding, business profile, Ghana Card upload, payout setup, dashboard, product list, add product, product detail, update stock, orders, prepare order, settlement due, settle now, history, notifications/settings. | Uses phone frames; still PWA. It is supplier-specific, not a shared reseller style override. |
| `risellar_admin_dashboard_mockup.png` | Found | `C:\Users\Nana Kwadwo\Downloads\risellar_admin_dashboard_mockup.png` | Admin overview, orders, order detail, settlements, commissions, product approval, supplier approval, delivery coordination, disputes. | Admin is desktop-first; left sidebar is deep green; tables are dense but readable; filters sit above tables; money/status actions need controlled admin panels. | Admin sidebar, topbar, metric cards, chart cards, recent activity, quick actions, tables, order detail, settlement insight, approval tables, delivery coordination forms, WhatsApp message preview, dispute table. | Admin screenshots are dense; do not simplify admin into mobile-only cards. |
| `risellar_app_onboarding_flow_design.png` | Found | `C:\Users\Nana Kwadwo\Downloads\risellar_app_onboarding_flow_design.png` | Shared auth, customer setup, reseller onboarding, supplier onboarding, verification, admin login/access. | Auth uses simple cards and role selection; onboarding is step-based; phone verification is trust-forward; supplier verification uses Ghana Card; admin login is calmer and more secure. | Splash/welcome, choose role, login, create account, OTP, reset access, reseller type, profile setup, area selection, MoMo payout, rules agreement, customer delivery setup, supplier business profile, Ghana Card upload, admin login/2-step verification. | Contains role-specific flows in one board; future implementation should use shared auth components with role-specific content. |
| `risellar_ui_design_system_overview.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 12, 2026, 11_37_52 PM.png` and updated `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 02_34_14 AM.png` | Empty states and edge cases across reseller, customer, supplier, and admin. | Empty/error/restricted states need illustration/icon, heading, explanation, primary action, secondary action when useful, and state-specific color. | Empty shop, no orders, pending commission, withdrawal failed, notifications empty, review pending, awaiting confirmation, delivery quote pending, cancelled, payment failed, supplier no products, low/out of stock, overdue settlement, verification pending/rejected, dispute, support inbox empty, supplier suspended. | Use the July 13 updated image as stronger source where it expands states; older image confirms same system. |
| `supplier_inventory_management_ui_design.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 01_56_29 AM.png` | Supplier inventory, stock, variants, movement history, restock, price changes, activity. | Inventory must show total, reserved, available, sold, low threshold, and movement history; stock actions are operational and must be auditable. | Inventory dashboard, products list, add product, variants table, product detail, restock, stock movement history, price change request, low-stock/out-of-stock states, inventory activity log. | Canonical filename missing, but the alternate image is clearly Image 8 and covers the requested area. |
| `a_clean_high_resolution_ui_ux_dashboard_concept_a.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 01_56_38 AM.png` | Supplier settlements and financial control. | Settlement due/overdue must be impossible to miss; trust score and restrictions explain consequences; proof upload is a key flow; overdue alerts use danger styling. | Settlements overview, settlement obligation table, upload proof mobile flow, settlement details, status guide, history, trust score/restrictions, restriction levels, quick actions, overdue alert. | Strong desktop-plus-mobile hybrid board; use for settlement rules across supplier and admin. |
| `a_clean_high_resolution_ux_showcase_dashboard_moc.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 02_11_21 AM.png` | Customer confirmation and delivery approval flow. | Customer journey is staged and reassuring; order confirmation and delivery approval are explicit; tracking timeline shows current vs completed vs future steps; final Pay on Delivery total is clear. | Order journey, confirmation countdown, delivery options, quote approval, tracking timeline, FAQ, order summary, secure shopping panel, support CTA. | This is an expanded customer flow and should inform checkout/tracking beyond the basic checkout board. |
| `risellar_admin_operations_control_panel.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 02_17_12 AM.png` | Admin operations hub, risk queues, settlement queues, approval queues, audit, manual override. | Admin operations need queue counts, risk summaries, alerts, manual override warnings, audit timeline, quick actions, and helper tools; red is reserved for restricted/overdue/manual override. | Operations hub sidebar, metric row, customer confirmation queue, supplier/product approval queues, risk/fraud cards, settlement due/overdue/proof verification tables, delivery/support operations, stock alerts, audit log, manual override, message templates. | This is the strictest admin operations reference and should be primary for risk/queue/admin control screens. |
| `modern_app_ui_product_dashboard_mockup.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 02_22_22 AM.png` | Reseller promotions, trending products, sponsored products, top selling, insights, Pro lock, WhatsApp captions. | Growth/insights UI uses the same palette but adds promoted/trending badges; Pro-locked features should be premium but not crypto-like; WhatsApp captions are practical sales tools. | Trending products, featured/sponsored products, top-selling list, insight detail, Pro insights locked, growth hub, WhatsApp caption card, insights empty state, promotions badges. | This is secondary to the core reseller flow for baseline UI, but primary for growth/promotions features. |
| `mobile_app_admin_dashboard_design.png` | Found via alternate | `C:\Users\Nana Kwadwo\Downloads\ChatGPT Image Jul 13, 2026, 02_27_42 AM.png` | Team members, inventory manager, permissions, access denied, activity log, compact permissions admin panel. | Permissions must be explicit, role-based, and auditable; access denied needs calm lock state and request access; desktop matrix table is valid for admin/owner. | Team list, invite by email, role permissions detail, inventory manager snapshot, edit permissions, access denied, team activity log, compact desktop permissions matrix. | Filename says mobile app, but implementation remains PWA/admin web. Treat as supplier/admin permissions source. |

## Most Important References

Primary design-system references:

- `risellar_product_and_app_design_showcase.png`
- `risellar_mobile_app_mockup_ui_design.png`
- `customer_checkout_flow_steps_overview.png`
- `risellar_supplier_app_ui_showcase.png`
- `risellar_admin_dashboard_mockup.png`
- `risellar_app_onboarding_flow_design.png`

Primary operational/state references:

- `ChatGPT Image Jul 13, 2026, 02_17_12 AM.png` for admin operations, queues, risk, audit, and manual override.
- `ChatGPT Image Jul 13, 2026, 01_56_38 AM.png` for supplier settlements and financial control.
- `ChatGPT Image Jul 13, 2026, 01_56_29 AM.png` for supplier inventory.
- `ChatGPT Image Jul 13, 2026, 02_34_14 AM.png` for updated empty states and edge cases.

Secondary/inspiration-only references:

- Duplicated dated versions of the same canonical boards should be treated as confirmation, not separate competing directions.
- `ChatGPT Image Jul 13, 2026, 02_22_22 AM.png` is primary only for reseller promotions, insights, sponsored products, and WhatsApp growth tools.
- `ChatGPT Image Jul 13, 2026, 02_27_42 AM.png` is primary only for team/permissions and inventory manager access control.

## Final Approved Brand Direction

Risellar should look like a modern Ghana ecommerce/fintech marketplace:

- Deep emerald primary brand color.
- Warm amber/gold accent for logo, highlights, earnings, pending/warning moments, and promotions.
- Soft cream backgrounds and white card surfaces.
- Charcoal text with muted gray secondary text.
- Plus Jakarta Sans typography.
- Rounded cards, consistent buttons, pill badges, subtle borders, and soft shadows.
- Transparent GH₵ financial breakdowns.
- Mobile-first PWA layouts for reseller, supplier, and customer checkout.
- Desktop-first admin dashboard with dense but readable operational tables.

## Consistency Notes

- The green/gold/cream/charcoal palette is consistent across all references.
- Status treatment is consistent: green for success/verified/paid, amber for pending/due/low stock, red for failed/overdue/rejected/restricted, blue/muted for processing/info.
- Admin screens are denser than PWA screens but share the same tokens.
- Financial screens consistently show breakdowns and final totals.
- Phone screens sometimes use native-looking frames, but they must be implemented as web/PWA surfaces.

## Remaining Ambiguities

- Some exact colors vary slightly by image rendering. The guide locks the palette to `#086B4F`, `#11865E`, `#F5B300`, `#FFF8EA`, `#F1F3F4`, and `#1A1C1E`.
- Several requested canonical filenames for specialty boards were not present, but equivalent attached/downloaded dated images were present and reviewed.
- The final production logo asset is not in the repo yet; the guide captures the visual direction but future implementation should use the approved logo file when available.

Future work must read `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md` before creating any Risellar UI.
