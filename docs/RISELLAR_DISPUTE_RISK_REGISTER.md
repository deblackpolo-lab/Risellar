# Risellar Dispute Risk Register

| Risk | Likelihood | Impact | Prevention | Detection | Recovery |
| --- | --- | --- | --- | --- | --- |
| Customer disputes another person's order | Medium | High | Customer RPC resolves profile from auth and checks order ownership | SQL ownership tests, browser cross-account QA | Revoke access, audit, patch RLS/RPC |
| Supplier sees customer private data | Medium | High | Supplier safe reads with allowlisted fields | Privacy snapshot tests | Remove leaked field, notify if required |
| Supplier resolves own dispute | Medium | High | Separate supplier response RPC from admin resolution RPC | Boundary tests | Reopen case, audit invalid action |
| Admin changes arbitrary money values | Medium | Critical | Finance RPCs enforce snapshot maximums and role checks | Finance boundary tests | Reverse via audited correction |
| Refund exceeds order amount | Medium | Critical | Backend max from immutable snapshots | Amount tests | Block/refund correction process |
| Refund issued twice | Medium | Critical | Idempotency keys and unique obligations | Duplicate-call tests | Mark duplicate, recovery workflow |
| Supplier says refunded but customer did not receive it | High | High | Refund proof and finance/admin verification | Customer challenge workflow | Reopen refund verification |
| Commission released while dispute open | Medium | High | Settlement verification checks active blocking disputes | Settlement/dispute tests | Create hold/adjustment |
| Withdrawal request consumes disputed commission | Medium | High | Available balance hold before withdrawal | Withdrawal/hold concurrency test | Hold pending withdrawal or liability |
| Paid withdrawal reversed silently | Medium | Critical | No silent reversal; liability model only | Ledger tests | Audited recovery/liability |
| Wallet becomes negative | Medium | Critical | Non-negative constraints and transaction locks | Balance invariant tests | Freeze wallet and reconcile |
| Settlement verified while dispute should block it | Medium | High | Settlement RPC checks dispute categories | SQL boundary tests | Mark settlement disputed and audit |
| Stock restored before physical return | High | High | No restock until inspection RPC | Return state tests | Reverse movement and quarantine |
| Returned damaged item sold again | Medium | High | Condition/outcome gating | Inventory QA | Quarantine affected stock |
| Duplicate stock movement | Medium | High | Idempotency and unique movement references | Duplicate tests | Inventory correction movement |
| Duplicate finance adjustment | Medium | Critical | Idempotency and unique adjustment references | Duplicate tests | Audited reversing adjustment |
| Dispute reopened after final resolution | Medium | Medium | Reopen/appeal rules and windows | State transition tests | Close duplicate or appeal |
| Evidence public exposure | Medium | Critical | Private bucket, signed URLs, no raw paths | Storage access tests | Rotate links, remove object, audit |
| Malicious file upload | Medium | High | File allowlist, size limits, scan plan | Upload tests | Quarantine/delete file |
| Private notes leaked in email | Medium | High | Email templates use safe payloads only | Template privacy tests | Correct template and notify if required |
| Stale UI after resolution | Medium | Medium | Revalidate after actions and show durable state | Browser QA | Refresh/revalidate cache |
| Cross-currency refund | Low | High | Currency match enforcement | Currency tests | Block and correct record |
| Partial transaction | Medium | Critical | Single transaction RPCs and rollback on errors | Fault-injection tests | Reconcile via audit |
| Race between refund and settlement | Medium | Critical | Lock order/dispute/settlement rows in stable order | Concurrency test | Manual finance review |
| Race between hold and withdrawal | Medium | Critical | Lock reseller balance/withdrawal rows in stable order | Concurrency test | Freeze wallet and reconcile |
| Admin private note exposed to reseller | Medium | High | Role-specific message visibility | Safe-read tests | Redact and patch |
| Reseller sees supplier evidence | Medium | High | Reseller impact reads only | Safe-read tests | Patch RPC and audit |
| Return delivery fee responsibility unclear | High | Medium | Controlled responsibility code | QA decision checklist | Admin correction workflow |
| Platform goodwill refunds untracked | Medium | High | Explicit platform responsibility records | Accounting tests | Finance reconciliation |
