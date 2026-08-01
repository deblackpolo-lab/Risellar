import "server-only";

import { clerkClient } from "@clerk/nextjs/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { getEmailNotificationConfig } from "./email";
import { processEmailNotificationBatch, type ClaimedEmailNotification } from "./processor";
import { createResendSender, createResendWebhookVerifier } from "./resend-client";
import { handleResendWebhook, type ResendWebhookEvent } from "./resend-webhook";

type SupabaseAdmin = ReturnType<typeof createSupabaseAdminClient>;

async function getProfileForRecipient(client: SupabaseAdmin, profileId: string | null) {
  if (!profileId) {
    return null;
  }

  const { data, error } = await client
    .from("profiles")
    .select("id, clerk_user_id, email, account_status, deleted_at")
    .eq("id", profileId)
    .maybeSingle();

  if (error || !data || data.account_status !== "active" || data.deleted_at) {
    return null;
  }

  return data;
}

export async function resolveVerifiedProfileEmail(client: SupabaseAdmin, profileId: string | null) {
  const profile = await getProfileForRecipient(client, profileId);
  if (!profile) {
    return null;
  }

  try {
    const clerk = await clerkClient();
    const user = await clerk.users.getUser(profile.clerk_user_id);
    const primary = user.emailAddresses.find((email) => email.id === user.primaryEmailAddressId);

    if (primary?.verification?.status === "verified") {
      return primary.emailAddress;
    }
  } catch {
    return null;
  }

  return null;
}

export async function processPendingTransactionalEmails(input: { batchSize: number; workerId: string }) {
  const client = createSupabaseAdminClient();
  const config = getEmailNotificationConfig();
  const sendEmail = config.canSend ? createResendSender(config) : async () => ({ providerMessageId: null });

  return processEmailNotificationBatch(
    {
      config,
      async claimPending({ batchSize, workerId }) {
        const { data, error } = await client.rpc("claim_pending_email_notifications", {
          p_limit: batchSize,
          p_worker_id: workerId
        });
        if (error) {
          throw new Error("EMAIL_OUTBOX_CLAIM_FAILED");
        }

        return ((data ?? []) as Array<Record<string, unknown>>).map((row): ClaimedEmailNotification => ({
          id: String(row.id),
          eventKey: String(row.event_key),
          eventType: String(row.event_type),
          recipientProfileId: typeof row.recipient_profile_id === "string" ? row.recipient_profile_id : null,
          payload: typeof row.payload === "object" && row.payload !== null ? (row.payload as Record<string, unknown>) : {}
        }));
      },
      resolveRecipientEmail: (profileId) => resolveVerifiedProfileEmail(client, profileId),
      sendEmail,
      async markSent(notificationId, providerMessageId) {
        const { error } = await client.rpc("mark_email_notification_sent", {
          p_notification_id: notificationId,
          p_provider_message_id: providerMessageId ?? null
        });
        if (error) {
          throw new Error("EMAIL_OUTBOX_MARK_SENT_FAILED");
        }
      },
      async markRetry(notificationId, safeErrorCode) {
        const { error } = await client.rpc("mark_email_notification_retry", {
          p_notification_id: notificationId,
          p_safe_error_code: safeErrorCode
        });
        if (error) {
          throw new Error("EMAIL_OUTBOX_MARK_RETRY_FAILED");
        }
      },
      async markFailed(notificationId, safeErrorCode) {
        const { error } = await client.rpc("mark_email_notification_failed", {
          p_notification_id: notificationId,
          p_safe_error_code: safeErrorCode
        });
        if (error) {
          throw new Error("EMAIL_OUTBOX_MARK_FAILED_FAILED");
        }
      }
    },
    input
  );
}

export async function processResendWebhookStatus(input: { rawBody: string; headers: Headers }) {
  const webhookSecret = process.env.RESEND_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return { ok: false as const, status: 503, safeErrorCode: "RESEND_WEBHOOK_SECRET_MISSING" };
  }

  const client = createSupabaseAdminClient();

  return handleResendWebhook({
    rawBody: input.rawBody,
    headers: input.headers,
    deps: {
      webhookSecret,
      verify: createResendWebhookVerifier({ apiKey: process.env.RESEND_API_KEY }),
      async recordProviderEvent(event: ResendWebhookEvent) {
        const status = event.type.replace(/^email\./, "");
        const providerMessageId = event.data?.email_id ?? event.data?.emailId ?? null;
        const { data, error } = await client.rpc("record_email_provider_event", {
          p_provider_event_id: event.providerEventId,
          p_provider_message_id: providerMessageId,
          p_provider_event_type: event.type,
          p_provider_status: status,
          p_safe_metadata: {}
        });
        if (error) {
          throw new Error("EMAIL_PROVIDER_EVENT_RECORD_FAILED");
        }

        return data === true;
      },
      async updateProviderStatus(providerMessageId, providerStatus) {
        const { error } = await client.rpc("update_email_notification_provider_status", {
          p_provider_message_id: providerMessageId,
          p_provider_status: providerStatus
        });
        if (error) {
          throw new Error("EMAIL_PROVIDER_STATUS_UPDATE_FAILED");
        }
      }
    }
  });
}
