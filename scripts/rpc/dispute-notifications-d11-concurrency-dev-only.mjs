#!/usr/bin/env node
/* global console, process */

import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import crypto from "node:crypto";

const marker = `d11-${crypto.randomUUID()}`;
const profileA = crypto.randomUUID();
const profileB = crypto.randomUUID();
const entityA = crypto.randomUUID();
const entityB = crypto.randomUUID();
const auditA = crypto.randomUUID();
const auditB = crypto.randomUUID();
const auditC = crypto.randomUUID();
const providerMessageId = `d11-provider-${crypto.randomUUID()}`;
const providerEventId = `d11-provider-event-${crypto.randomUUID()}`;

function sqlLiteral(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

async function runSupabaseSql(sql, label) {
  const dir = await mkdtemp(join(tmpdir(), "risellar-d11-"));
  const file = join(dir, "query.sql");
  await writeFile(file, sql, "utf8");

  try {
    const result = await new Promise((resolve) => {
      const child = spawn("npx", ["supabase", "db", "query", "--linked", "--file", file], {
        cwd: process.cwd(),
        shell: true,
        env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
        stdio: ["ignore", "pipe", "pipe"]
      });

      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => {
        stdout += chunk.toString();
      });
      child.stderr.on("data", (chunk) => {
        stderr += chunk.toString();
      });
      child.on("close", (code) => resolve({ code, stdout, stderr }));
    });

    if (result.code !== 0) {
      throw new Error(`${label} failed\n${result.stdout}\n${result.stderr}`);
    }

    return result.stdout;
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

async function runPair(name, leftSql, rightSql) {
  await Promise.all([
    runSupabaseSql(leftSql, `${name}:left`),
    runSupabaseSql(rightSql, `${name}:right`)
  ]);
}

function enqueueSql(eventKey, eventType, entityId, recipientProfileId, recipientRole, payload = "{}") {
  return `
    select pg_sleep(0.25);
    select public.enqueue_email_notification(
      ${sqlLiteral(eventKey)},
      ${sqlLiteral(eventType)},
      'd11_concurrency',
      ${sqlLiteral(entityId)}::uuid,
      ${sqlLiteral(recipientProfileId)}::uuid,
      ${sqlLiteral(recipientRole)},
      ${sqlLiteral(payload)}::jsonb
    );
  `;
}

async function main() {
  await runSupabaseSql(
    `
      insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
      values
        (${sqlLiteral(profileA)}::uuid, ${sqlLiteral(`${marker}-a`)}, ${sqlLiteral(`${marker}-a@example.test`)}, 'D11 Recipient A', 'customer', 'active'),
        (${sqlLiteral(profileB)}::uuid, ${sqlLiteral(`${marker}-b`)}, ${sqlLiteral(`${marker}-b@example.test`)}, 'D11 Recipient B', 'customer', 'active');
    `,
    "setup"
  );

  try {
    await runPair(
      "same-audit-event",
      enqueueSql(`${marker}:same-audit`, "dispute_opened_customer", entityA, profileA, "customer"),
      enqueueSql(`${marker}:same-audit`, "dispute_opened_customer", entityA, profileA, "customer")
    );

    await runPair(
      "same-business-retry",
      enqueueSql(`${marker}:same-business:${auditA}:customer`, "return_approved_customer", entityA, profileA, "customer"),
      enqueueSql(`${marker}:same-business:${auditA}:customer`, "return_approved_customer", entityA, profileA, "customer")
    );

    await runPair(
      "separate-response-events",
      enqueueSql(`${marker}:response:${auditA}:support`, "dispute_response_received_admin", entityA, profileA, "support_admin"),
      enqueueSql(`${marker}:response:${auditB}:support`, "dispute_response_received_admin", entityA, profileA, "support_admin")
    );

    await runPair(
      "refund-retry",
      enqueueSql(`${marker}:refund:${auditA}:customer`, "refund_verified_customer", entityA, profileA, "customer"),
      enqueueSql(`${marker}:refund:${auditA}:customer`, "refund_verified_customer", entityA, profileA, "customer")
    );

    await runPair(
      "finance-hold-roles",
      enqueueSql(`${marker}:hold:${auditA}:reseller`, "commission_hold_created_reseller", entityA, profileA, "reseller"),
      enqueueSql(`${marker}:hold:${auditA}:finance`, "commission_hold_created_finance", entityA, profileB, "finance_admin")
    );

    await runPair(
      "withdrawal-blocked-roles",
      enqueueSql(`${marker}:withdrawal:${auditA}:reseller`, "withdrawal_blocked_by_finance_review", entityA, profileA, "reseller"),
      enqueueSql(`${marker}:withdrawal:${auditA}:finance`, "withdrawal_blocked_finance", entityA, profileB, "finance_admin")
    );

    await runSupabaseSql(
      `
        select public.enqueue_email_notification(${sqlLiteral(`${marker}:claim:1`)}, 'dispute_status_updated_customer', 'd11_concurrency', ${sqlLiteral(entityA)}::uuid, ${sqlLiteral(profileA)}::uuid, 'customer', '{}'::jsonb);
        select public.enqueue_email_notification(${sqlLiteral(`${marker}:claim:2`)}, 'dispute_status_updated_customer', 'd11_concurrency', ${sqlLiteral(entityA)}::uuid, ${sqlLiteral(profileA)}::uuid, 'customer', '{}'::jsonb);
        select public.enqueue_email_notification(${sqlLiteral(`${marker}:claim:3`)}, 'dispute_status_updated_customer', 'd11_concurrency', ${sqlLiteral(entityA)}::uuid, ${sqlLiteral(profileA)}::uuid, 'customer', '{}'::jsonb);
        update public.notification_outbox
        set created_at = now() - interval '30 days',
            next_attempt_at = now() - interval '1 minute',
            updated_at = now()
        where event_key like ${sqlLiteral(`${marker}:claim:%`)};
      `,
      "claim-setup"
    );
    await runPair(
      "processor-claim",
      `select pg_sleep(0.25); select count(*) from public.claim_pending_email_notifications(3, ${sqlLiteral(`${marker}-worker-a`)});`,
      `select pg_sleep(0.25); select count(*) from public.claim_pending_email_notifications(3, ${sqlLiteral(`${marker}-worker-b`)});`
    );

    await runPair(
      "webhook-replay",
      `select pg_sleep(0.25); select public.record_email_provider_event(${sqlLiteral(providerEventId)}, ${sqlLiteral(providerMessageId)}, 'email.delivered', 'delivered', '{}'::jsonb);`,
      `select pg_sleep(0.25); select public.record_email_provider_event(${sqlLiteral(providerEventId)}, ${sqlLiteral(providerMessageId)}, 'email.delivered', 'delivered', '{}'::jsonb);`
    );

    await runPair(
      "rollback-mapping",
      `begin; ${enqueueSql(`${marker}:rollback:${auditC}:customer`, "refund_completed_customer", entityB, profileA, "customer")} rollback;`,
      `begin; ${enqueueSql(`${marker}:rollback:${auditC}:customer`, "refund_completed_customer", entityB, profileA, "customer")} rollback;`
    );

    await runPair(
      "recipient-isolation",
      enqueueSql(`${marker}:isolation:${auditA}:supplier-a`, "dispute_opened_supplier", entityA, profileA, "supplier"),
      enqueueSql(`${marker}:isolation:${auditB}:reseller-a`, "commission_hold_created_reseller", entityA, profileA, "reseller")
    );

    await runSupabaseSql(
      `
        do $$
        declare
          v_failed text;
        begin
          create temp table d11_concurrency_results(assertion text primary key, passed boolean not null) on commit drop;

          insert into d11_concurrency_results(assertion, passed)
          values
            ('same audit event processed twice creates one outbox row', (select count(*) from public.notification_outbox where event_key = ${sqlLiteral(`${marker}:same-audit`)}) = 1),
            ('same business action retry creates one logical notification', (select count(*) from public.notification_outbox where event_key = ${sqlLiteral(`${marker}:same-business:${auditA}:customer`)}) = 1),
            ('two valid responses create separate intended notifications', (select count(*) from public.notification_outbox where event_key in (${sqlLiteral(`${marker}:response:${auditA}:support`)}, ${sqlLiteral(`${marker}:response:${auditB}:support`)})) = 2),
            ('refund verification retry creates one customer notification', (select count(*) from public.notification_outbox where event_key = ${sqlLiteral(`${marker}:refund:${auditA}:customer`)}) = 1),
            ('finance hold retry keeps one notification per intended role', (select count(*) from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:hold:%`)}) = 2),
            ('withdrawal blocked retry keeps reseller and finance events distinct', (select count(*) from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:withdrawal:%`)}) = 2),
            ('processor concurrent claim marks each claim row once', (select count(*) from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:claim:%`)} and status = 'processing') = 3),
            ('processor concurrent claim does not duplicate rows', (select count(distinct event_key) from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:claim:%`)}) = 3),
            ('webhook replay stores provider event once', (select count(*) from public.notification_provider_events where provider_event_id = ${sqlLiteral(providerEventId)}) = 1),
            ('rolled back notification creates no orphan outbox row', not exists(select 1 from public.notification_outbox where event_key = ${sqlLiteral(`${marker}:rollback:${auditC}:customer`)})),
            ('recipient role isolation avoids unrelated recipient', not exists(select 1 from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:isolation:%`)} and recipient_profile_id = ${sqlLiteral(profileB)}::uuid)),
            ('outbox payload excludes recipient email', not exists(select 1 from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:%`)} and (payload ? 'recipient_email' or payload ? 'email'))),
            ('no duplicate provider send idempotency keys', (select count(*) from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:%`)}) = (select count(distinct event_key) from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:%`)}));

          select string_agg(assertion, '; ' order by assertion)
          into v_failed
          from d11_concurrency_results
          where not passed;

          if v_failed is not null then
            raise exception 'D11_CONCURRENCY_ASSERTIONS_FAILED: %', v_failed;
          end if;
        end;
        $$;
        select 13 as invariant_checks, 'passed' as result;
      `,
      "assertions"
    );
  } finally {
    await runSupabaseSql(
      `
        delete from public.notification_provider_events where provider_event_id = ${sqlLiteral(providerEventId)};
        update public.notification_outbox
        set status = 'pending',
            locked_at = null,
            locked_by = null,
            updated_at = now()
        where locked_by in (${sqlLiteral(`${marker}-worker-a`)}, ${sqlLiteral(`${marker}-worker-b`)})
          and event_key not like ${sqlLiteral(`${marker}:%`)};
        delete from public.notification_outbox where event_key like ${sqlLiteral(`${marker}:%`)};
        delete from public.profiles where clerk_user_id in (${sqlLiteral(`${marker}-a`)}, ${sqlLiteral(`${marker}-b`)});
      `,
      "cleanup"
    );
  }

  console.log("D11_NOTIFICATION_CONCURRENCY_PASSED", JSON.stringify({ scenarios: 10, invariantChecks: 13 }));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
