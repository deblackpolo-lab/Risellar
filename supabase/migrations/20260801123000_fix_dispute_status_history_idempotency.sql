-- Disputes D3 forward fix: add idempotency protection to status history.
-- The already-applied D2 migration created the append-only status history table
-- but omitted the planned idempotency key. This patch keeps the fix narrow and
-- does not change dispute read grants, RLS, finance, refund, return, stock,
-- reservation, order, payment, commission, settlement, withdrawal, evidence, or
-- notification behavior.

alter table public.dispute_status_history
  add column if not exists idempotency_key text;

alter table public.dispute_status_history
  drop constraint if exists dispute_status_history_idempotency_key_safe;

alter table public.dispute_status_history
  add constraint dispute_status_history_idempotency_key_safe
  check (
    idempotency_key is null
    or (
      length(trim(idempotency_key)) between 8 and 140
      and idempotency_key !~* '(password|secret|token|jwt|cookie)'
    )
  );

create unique index if not exists dispute_status_history_idempotency_unique
  on public.dispute_status_history(dispute_id, idempotency_key)
  where idempotency_key is not null;
