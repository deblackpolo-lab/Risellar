# Risellar D13-A Existing Mock UI Audit

Date: 2026-08-02

## Summary

Existing dispute, return, refund, and support UI is concentrated in a preserved mock component file and mock data module. These screens are visually useful but are not backend-connected and must not be activated as live workflow screens without replacement.

## Mock Source Files

| File | Current use | Backend connected | Privacy risk | Recommendation |
| --- | --- | --- | --- | --- |
| components/support/support-disputes-screens.tsx | Customer, reseller, supplier, admin support/dispute/return/refund visual screens | No | Medium if treated as real, because mock names, notes, amounts, and action buttons are displayed | Reuse selected visual shell only after replacing props with role-safe DTOs |
| lib/mock/support-disputes.ts | Mock tickets, disputes, returns, refunds, timelines, finance impact values | No | Medium if exposed as live data | Quarantine from activated routes |
| app/admin/disputes/page.tsx | Admin dispute list | No | Medium | Replace in D13-F |
| app/admin/disputes/[id]/page.tsx | Admin dispute detail | No | Medium | Replace in D13-F |
| app/admin/returns/page.tsx | Admin return list | No | Medium | Replace in D13-G |
| app/admin/returns/[id]/page.tsx | Admin return detail | No | Medium | Replace in D13-G |
| app/admin/refunds/page.tsx | Admin refund list | No | High if confused with finance-ready refunds | Replace in D13-H |
| app/admin/refunds/[id]/page.tsx | Admin refund detail | No | High if confused with finance-ready refunds | Replace in D13-H |
| app/admin/support/page.tsx | Admin support inbox | No | Medium | Keep quarantined until support tickets are live |
| app/admin/support/tickets/* | Admin support ticket screens | No | Medium | Keep quarantined |
| app/customer/disputes/[id]/page.tsx | Customer dispute detail | No | Medium | Replace in D13-B |
| app/customer/orders/[id]/report-issue/page.tsx | Customer issue entry | No | Medium | Replace in D13-B |
| app/customer/orders/[id]/return-request/page.tsx | Customer return request entry | No | Medium | Replace in D13-C |
| app/customer/orders/[id]/refund-status/page.tsx | Customer refund status | No | Medium | Replace in D13-C |
| app/customer/support/* | Customer support screens | No | Medium | Keep quarantined |
| app/supplier/support/* | Supplier support, returns, settlement-dispute screens | No | Medium | Replace only where D13-D/E scope applies |
| app/reseller/support/* | Reseller support and commission dispute screens | No | Medium | Replace only where D13-I scope applies |

## Reusable Visual Elements

The following patterns can be reused after replacing mock data/actions:

- Admin tables and queue cards
- Status badges
- Timeline layout
- Card spacing and typography
- Empty and error states
- Confirmation panels
- Action button placement
- Internal-note visual treatment for admin-only views

## Quarantine Rules

- Do not import lib/mock/support-disputes from any activated D13 route.
- Do not keep "Mock" action buttons in live routes.
- Do not let full backend records reach shared visual components.
- Do not show finance, margin, commission, settlement, payout, risk, internal note, or supplier contact fields outside authorized role DTOs.
- Keep support ticket mocks separate from dispute/return/refund activation unless a later support-ticket backend exists.

