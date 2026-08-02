# Risellar D13-A Navigation Plan

Date: 2026-08-02

## Summary

D13 navigation should expose only live, role-authorized routes. Mock-only links must stay hidden or clearly QA-only until the corresponding route group is implemented and tested.

## Customer Navigation

Add when D13-B/C routes are live:

- Orders
- Disputes
- Returns
- Refunds

Rules:

- visible to active customer only
- wrong-role users blocked by server route guards
- mobile navigation must include the same active state as desktop

## Supplier Navigation

Add when D13-D/E routes are live:

- Orders
- Disputes
- Returns
- Refunds

Rules:

- visible to active approved supplier_owner only
- supplier_inventory_manager access remains limited unless explicitly approved
- no cross-supplier links

## Reseller Navigation

Add when D13-I is live:

- Earnings
- Wallet
- Withdrawals
- Liabilities and Reviews

Rules:

- visible to active reseller only
- no finance-private settlement or payout data
- no false allocation displays

## Admin/Support Navigation

Add when D13-F/G are live:

- Disputes
- Returns

Rules:

- visible to support_staff, admin, or super_admin
- finance_staff-only should not see support mutation routes unless also granted support/admin authority

## Finance Navigation

Add when D13-H is live:

- Refunds
- Finance Holds
- Liabilities
- Settlements
- Withdrawals

Rules:

- visible to finance_staff or super_admin
- support_staff-only must be blocked
- super_admin still uses controlled RPCs

## Do Not Implement Yet

D13-A does not add navigation links to missing or mock-only routes. Navigation changes should land with the route group that activates the corresponding live backend-connected UI.

