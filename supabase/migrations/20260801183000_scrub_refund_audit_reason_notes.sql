-- Disputes D8 forward privacy fix: refund audit rows must not store note bodies
-- in the generic audit reason field.

create or replace function public.refund_workflow_scrub_audit_reason()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.target_entity_type = 'order_refund'
    and new.action in (
      'refund_obligation_approved',
      'refund_reported_sent',
      'refund_customer_confirmed_received',
      'refund_customer_disputed_not_received',
      'refund_report_rejected',
      'refund_verified',
      'refund_completed',
      'refund_cancelled'
    ) then
    new.reason := null;
  end if;

  return new;
end;
$$;

drop trigger if exists audit_logs_scrub_refund_reason on public.audit_logs;
create trigger audit_logs_scrub_refund_reason
before insert or update of reason on public.audit_logs
for each row execute function public.refund_workflow_scrub_audit_reason();

revoke all on function public.refund_workflow_scrub_audit_reason() from public, anon, authenticated;

comment on function public.refund_workflow_scrub_audit_reason() is
  'D8 privacy guard that prevents refund-related audit rows from storing note bodies in audit_logs.reason.';
