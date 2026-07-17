# Risellar Frontend PRD Coverage Matrix

Status meanings:

- **Complete**: Frontend route/component, mock data, mock action or read-only placeholder, and status/empty-state coverage exist for MVP review.
- **Partial**: Frontend exists but needs a small later frontend expansion or stronger backend handoff detail.
- **Backend-only later**: Correctly deferred to backend/auth/storage/payment/database work.
- **Out of MVP**: Explicitly deferred by PRD/business rules.

| Requirement / module | Required by source doc | Frontend route/component available? | Mock data available? | Mock action available? | Status / empty state available? | Backend required later? | Coverage status | Notes / fix applied |
|---|---|---:|---:|---:|---:|---:|---|---|
| Brand UI foundation | Brand guide, Phase 1-2 | Yes, `/design-system`, `components/ui`, tokens | Yes | N/A | Yes | No | Complete | Component gallery and tokens remain source-aligned. |
| Preview launcher | Phase 15, current audit brief | Yes, `/preview` | Yes | N/A | Yes | No | Complete | Updated preview grouping to required review sections. |
| Public/root placeholder | PRD screen map | Yes, `/` and onboarding/auth placeholders | Yes | N/A | Yes | Later auth | Complete | Frontend-only entry points exist. |
| Customer account creation placeholder | PRD 17, auth rules | Yes, `/checkout/account` | Yes | Yes | Yes | Clerk/backend later | Complete | Auth is deliberately mocked. |
| Public reseller shop | PRD 29, customer checkout | Yes, `/shop/amas-beauty-plug` | Yes | Search/filter mock | Yes | Backend catalog later | Complete | Customer sees final prices only. |
| Customer product detail | PRD 17, 21 | Yes, `/shop/.../product/...` | Yes | Add-to-cart mock | Yes | Backend order/cart later | Complete | Product gallery and Pay on Delivery trust copy present. |
| Customer cart | PRD 17 | Yes, `/checkout/cart` | Yes | Quantity mock | Yes | Cart persistence later | Complete | Delivery shown as estimate/not final. |
| Checkout delivery details | PRD 21 | Yes, `/checkout/delivery` | Yes | Delivery option mock | Yes | Delivery quote backend later | Complete | Ghana location examples present. |
| Payment method / Pay on Delivery | PRD 18-19 | Yes, `/checkout/payment` | Yes | Pay Online disabled placeholder | Yes | Payment provider later | Complete | Pay on Delivery is primary and clear. |
| Order review / success | PRD 17-20 | Yes, `/checkout/review`, `/checkout/success` | Yes | Place order mock | Yes | Order persistence later | Complete | Confirmation requirement represented. |
| Customer confirmation | Business rules 20 | Yes, `/customer/orders/.../confirm` | Yes | Confirm/cancel mock | Yes | Server validation later | Complete | Reservation/confirmation messaging present. |
| Delivery quote approval | Business rules 21 | Yes, `/customer/orders/.../delivery-quote` | Yes | Approve/change mock | Yes | Delivery quote backend later | Complete | Customer approves before dispatch. |
| Customer order tracking | PRD 17 | Yes, `/customer/orders`, `/customer/orders/[id]` | Yes | N/A | Timeline states | Backend later | Complete | Timeline captures core order states. |
| Customer support/report issue | PRD 38 | Yes, `/customer/support`, `/report-issue` | Yes | Submit mock | Yes | Support persistence later | Complete | No real ticket creation. |
| Customer return request | PRD 38 | Yes, `/return-request` | Yes | Request mock | Yes | Return workflow later | Complete | Eligibility copy present. |
| Customer refund status | PRD 38 | Yes, `/refund-status` | Yes | N/A | Yes | Refund backend later | Complete | Pay Online refund remains future. |
| Customer dispute detail | PRD 38 | Yes, `/customer/disputes/[id]` | Yes | Response mock | Yes | Support backend later | Complete | Static detail route exists. |
| Customer empty/failed states | Phase 14 | Yes, `/edge-cases/customer/...` | Yes | Mock CTAs | Yes | Some backend later | Complete | Awaiting confirmation/out-of-stock covered. |
| Reseller onboarding | PRD 28 | Yes, `/reseller/onboarding/*` | Yes | Continue/save mock | Yes | Clerk/profile backend later | Complete | Type, area, payout, rules, complete screens exist. |
| Reseller dashboard | PRD 29-30 | Yes, `/reseller/dashboard` | Yes | N/A | Yes | Backend metrics later | Complete | Earnings/commission summary present. |
| Reseller catalog/search/filter | PRD 29, 34 | Yes, `/reseller/products`, category route | Yes | Search/filter mock | Yes | Catalog backend later | Complete | Chip rows are scrollbar-hidden. |
| Reseller product detail | PRD 16, 29 | Yes, `/reseller/products/[id]` | Yes | Add/price mock | Yes | Backend price validation later | Complete | Supplier base price remains hidden; reseller cost visible. |
| Reseller profit calculator / set price | PRD 16 | Yes, `/price` | Yes | Save price mock | Yes | Server price rules later | Complete | Max allowed price warning represented. |
| Add to shop / my shop / edit shop | PRD 29 | Yes, `/added`, `/shop`, `/shop/edit`, `/my-products` | Yes | Edit/share mock | Yes | Shop persistence later | Complete | Shop preview and product list present. |
| WhatsApp caption/share | Business rules 31 | Yes, `/reseller/share/[productId]` | Yes | Copy/share mock | Yes | WhatsApp API out of MVP | Complete | Manual helper only. |
| Reseller orders / detail | PRD 30 | Yes, `/reseller/orders`, `/orders/[id]` | Yes | Mock actions | Yes | Order backend later | Complete | Commission states visible. |
| Reseller wallet/withdraw/transactions | PRD 30, 32 | Yes | Yes | Withdraw mock | Yes | MoMo payout backend later | Complete | Pending commission is not withdrawable. |
| Reseller notifications/settings | PRD screen map | Yes | Yes | Mock toggles/settings | Yes | Backend later | Complete | Static controls only. |
| Reseller support/missing commission | PRD 38 | Yes | Yes | Dispute mock | Yes | Support backend later | Complete | Commission dispute flow present. |
| Reseller insights/trending/promotions | PRD 33-34 | Yes, `/trending`, `/insights/*`, `/promotions/*` | Yes | Share/upgrade mock | Yes | Ranking/analytics later | Complete | Pro locked state exists. |
| Reseller restricted/empty states | Phase 14 | Yes, `/edge-cases/reseller/*` | Yes | Mock CTAs | Yes | Backend risk later | Complete | Commission pending/withdrawal failed covered. |
| Supplier onboarding/verification/agreement | PRD 22 | Yes, `/supplier/onboarding/*` | Yes | Upload placeholder | Yes | KYC/storage/backend later | Complete | Pending/rejected states present. |
| Supplier dashboard | PRD 23 | Yes, `/supplier/dashboard` | Yes | N/A | Yes | Metrics backend later | Complete | Supplier PWA core present. |
| Supplier products list/add/edit/detail | PRD 23, 26 | Yes, `/supplier/products*` | Yes | Save/edit mock | Yes | Product backend/storage later | Complete | Product list layout fixed. |
| Supplier image preview up to 5 images | PRD 23 | Yes, product image preview/gallery components | Yes | Upload placeholder | Yes | Storage later | Complete | Mock product images available. |
| Supplier orders/prepare order | PRD 22 | Yes, `/supplier/orders*` | Yes | Prepare mock | Yes | Order fulfillment backend later | Complete | Customer private info remains scoped. |
| Supplier inventory dashboard | PRD 23-24 | Yes, `/supplier/inventory` | Yes | N/A | Yes | Stock backend later | Complete | Stock status cards present. |
| Variants/restock/movement/price change | PRD 23, 27 | Yes, inventory dynamic routes | Yes | Restock/price mock | Yes | Atomic backend later | Complete | Movement history and request warning present. |
| Low/out-of-stock states | PRD 24 | Yes | Yes | Restock/edit mock | Yes | Stock backend later | Complete | Edge and route states exist. |
| Supplier settlements overview/detail | PRD 31 | Yes, `/supplier/settlements*` | Yes | N/A | Yes | Settlement ledger later | Complete | Due/overdue/partial/history/rules covered. |
| Settle/upload proof placeholder | PRD 31 | Yes, `/settle` | Yes | Upload proof mock | Yes | Storage/admin verification later | Complete | No real upload. |
| Supplier finance/payout/trust score | PRD 31, 37 | Yes, `/supplier/finance*` | Yes | Mock update | Yes | MoMo/bank backend later | Complete | Trust score rules represented. |
| Supplier promotions | PRD 33 | Yes, `/supplier/promotions*` | Yes | Create/proof mock | Yes | Payment/proof backend later | Complete | Eligibility and package screens present. |
| Supplier team/inventory manager | PRD 25 | Yes, `/supplier/team*`, `/inventory-manager/*` | Yes | Invite/permission mock | Yes | Auth/RBAC backend later | Complete | Access denied and role rules present. |
| Supplier support/settlement dispute/returns | PRD 38 | Yes | Yes | Submit/respond mock | Yes | Support backend later | Complete | Supplier return handling present. |
| Supplier empty/restricted states | Phase 14 | Yes, `/edge-cases/supplier/*` | Yes | Mock CTAs | Yes | Backend later | Complete | Settlement overdue/verification pending covered. |
| Admin dashboard/sidebar/topbar/logout | PRD 35 | Yes, `/admin/dashboard`, `AdminSidebar` | Yes | Logout placeholder | Yes | Auth/admin backend later | Complete | Sidebar status card removed; logout placeholder exists. |
| Admin orders list/detail | PRD 35 | Yes, `/admin/orders*` | Yes | Mock admin actions | Yes | Backend later | Complete | Product image context visible. |
| Admin products list/detail | PRD 35, 26 | Yes, `/admin/products*` | Yes | Approve/reject mock | Yes | Backend later | Complete | Product images visible. |
| Admin suppliers/resellers/customers | PRD 35 | Yes, list/detail routes | Yes | Review/contact mock | Yes | Backend later | Complete | Static profiles and risk summaries present. |
| Admin settlements/commissions/withdrawals | PRD 31-32, 35 | Yes | Yes | Mock review/release | Yes | Finance backend later | Complete | Full price breakdown visible to admin only. |
| Admin support | PRD 38 | Yes, `/admin/support`, tickets | Yes | Assign/respond mock | Yes | Support backend later | Complete | Support queue present. |
| Admin operations hub | PRD 36 | Yes, `/admin/operations` | Yes | Mock queue actions | Yes | Backend workflows later | Complete | Queue overview and detail patterns present. |
| Customer confirmation queue/detail | PRD 36 | Yes | Yes | Mock actions | Yes | Backend later | Complete | Representative detail route exists. |
| Delivery quote / settlement / commission queues | PRD 36 | Yes | Yes | Mock notify/release | Yes | Backend later | Complete | Due and overdue detail examples exist. |
| Product/supplier approval queues | PRD 26, 36 | Yes | Yes | Approve/reject mock | Yes | Backend later | Complete | Product thumbnails visible. |
| Withdrawal/disputes/failed delivery/stock queues | PRD 36 | Yes | Yes | Mock actions | Yes | Backend later | Complete | Queue routes exist. |
| Promotion approvals/admin promotions | PRD 33, 36 | Yes | Yes | Approve/reject mock | Yes | Backend later | Complete | Admin promotions section added in preview taxonomy. |
| Risk dashboard/entity/detail | PRD 37 | Yes, `/admin/risk*` | Yes | Restrict/review mock | Yes | Backend scoring later | Complete | Risk heatmap/entity screens present. |
| Audit logs/manual override placeholder | PRD 41 | Yes, `/admin/audit-logs`, `/manual-overrides` | Yes | Disabled override placeholder | Yes | Backend/admin audit later | Complete | Manual override intentionally disabled. |
| Admin disputes/returns/refunds | PRD 38 | Yes | Yes | Resolve/refund mock | Yes | Backend later | Complete | Admin support/dispute section added in preview taxonomy. |
| Admin settings | PRD 35 | Yes, `/admin/settings` | Yes | Mock controls | Yes | Backend later | Complete | Static settings only. |
| Edge case gallery | Phase 14, PRD acceptance | Yes, `/edge-cases` and dynamic states | Yes | Mock CTAs | Yes | Some backend later | Complete | Includes loading/offline/permission/account restrictions. |
| Product image/gallery/grid experience | PRD 23, UI polish reports | Yes, shared marketplace components | Yes | Lightbox/gallery mock | Yes | Storage later | Complete | Product gallery/grid polish committed; current audit confirms no overflow in sampled routes. |
| Pricing visibility rules | Business rules 13 | Yes | Yes | N/A | Yes | Server calculation later | Complete | Customer/reseller/admin visibility split represented. |
| Delivery separate from product price | Business rules 18, 21 | Yes | Yes | N/A | Yes | Backend quote later | Complete | Delivery estimate/final quote shown separately. |
| Stock reservation concept | Business rules 16 | Yes, checkout and tracking copy | Yes | Mock confirmation | Yes | Atomic backend required | Complete | Frontend placeholder exists; backend-later critical. |
| Risk/restriction states | Business rules 26-27 | Yes | Yes | Mock CTAs | Yes | Backend enforcement later | Complete | Trust score, restrictions, access denied represented. |
| Audit/manual override placeholders | Business rules 34-35 | Yes | Yes | Disabled controls | Yes | Backend enforcement later | Complete | No real override mutation. |
| Real auth | PRD 42 | Placeholder only | N/A | N/A | N/A | Yes | Backend-only later | Clerk explicitly deferred. |
| Real database/schema/RLS | Schema plan | Docs only | N/A | N/A | N/A | Yes | Backend-only later | No migrations created. |
| Real payment processing | PRD 19 | Placeholder only | N/A | N/A | N/A | Yes | Backend-only later | Pay Online disabled. |
| Real storage/upload | PRD 22-23, 31 | Placeholder only | N/A | Upload placeholder | N/A | Yes | Backend-only later | Product/KYC/proof uploads deferred. |
| Real email/WhatsApp integrations | PRD 39-40 | Manual/helper placeholder | N/A | Copy/template mock | N/A | Yes | Backend-only later | Resend and WhatsApp API deferred. |
