# Risellar D13-A Shared Component Plan

Date: 2026-08-02

## Source Of Truth

D13 should reuse the existing Risellar visual system:

- components/ui/Button.tsx
- components/ui/Card.tsx
- components/ui/StatusBadge.tsx
- components/ui/EmptyState.tsx
- components/ui/ErrorState.tsx
- components/ui/Input.tsx
- components/ui/Textarea.tsx
- components/ui/Select.tsx
- components/ui/Tabs.tsx
- components/admin/AdminSidebar.tsx
- components/admin/AdminTable.tsx
- components/admin/AdminMetricCard.tsx
- components/admin/AdminQueueCard.tsx
- existing customer, supplier, and reseller dashboard spacing/typography patterns

No D13 route should redesign dashboards or the brand system.

## Planned Shared Components

| Component | Roles | Purpose | Data rule |
| --- | --- | --- | --- |
| WorkflowStatusBadge | all | Role-safe state label | Receives normalized label/tone only |
| SafeTimeline | all | Timeline of role-safe events | Receives redacted events per role |
| ActionRequiredBanner | all | Next required action | No raw enum exposure |
| OrderReferenceCard | all | Safe order/item snapshot | Receives route-specific DTO |
| ItemSnapshotCard | all | Product/item summary | No supplier private price unless supplier/finance DTO allows it |
| PublicMessageCard | customer, supplier, support | Public case messages | No internal notes |
| InternalAdminNoteCard | support, finance, super_admin | Internal notes | Never rendered for customer/supplier/reseller |
| RoleSafeEmptyState | all | Empty queues | Role-specific copy |
| RoleSafeErrorState | all | Safe error copy | No SQL/internal errors |
| ConfirmActionDialog | support, finance, supplier, customer | Confirm state-changing actions | Requires idempotency-aware action |
| IdempotentSubmitButton | mutating routes | Prevent duplicate submits | Receives pending/submitted state |
| MoneyDisplay | reseller, finance, customer where safe | Currency display | Receives server-calculated amounts only |
| CurrencyBadge | all | Currency label | DTO value only |
| FinanceReviewBanner | finance, super_admin | Finance-only warnings | Never shown to customer/supplier/reseller |
| ReturnProgressStepper | customer, supplier, support | Return state progress | Role-specific steps |
| RefundProgressStepper | customer, supplier, finance | Refund state progress | Role-specific steps |
| LiabilityProgressCard | reseller, finance | Liability/recovery status | No hidden allocation details to reseller |
| WithdrawalReviewCard | reseller, finance | Withdrawal review status | Role-specific fields |
| AuditSummaryPanel | support, finance, super_admin | Authorized audit summary | Admin-only DTO |

## Component Safety Rules

- Components should receive safe DTOs, not full database rows.
- Do not hide sensitive fields only with CSS or conditional text after passing full records to the browser.
- Do not make one generic "case record" component that accepts every backend field.
- Do not render internal notes, risk fields, payout data, settlement internals, supplier contact data, or raw IDs unless the role-specific route explicitly permits them.

