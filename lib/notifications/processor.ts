import "server-only";

import { buildEmailTemplate, createResendEmailRequest, shouldRetryResendError, type EmailNotificationConfig } from "./email";

export type ClaimedEmailNotification = {
  id: string;
  eventKey: string;
  eventType: string;
  recipientProfileId: string | null;
  payload: Record<string, unknown>;
};

export type NotificationProcessorDependencies = {
  config: EmailNotificationConfig;
  claimPending: (input: { batchSize: number; workerId: string }) => Promise<ClaimedEmailNotification[]>;
  resolveRecipientEmail: (recipientProfileId: string | null) => Promise<string | null>;
  sendEmail: (request: ReturnType<typeof createResendEmailRequest>) => Promise<{ providerMessageId?: string | null }>;
  markSent: (notificationId: string, providerMessageId?: string | null) => Promise<void>;
  markRetry: (notificationId: string, safeErrorCode: string) => Promise<void>;
  markFailed: (notificationId: string, safeErrorCode: string) => Promise<void>;
};

export type NotificationProcessorResult = {
  claimed: number;
  sent: number;
  retried: number;
  failed: number;
  skipped: number;
};

export async function processEmailNotificationBatch(
  deps: NotificationProcessorDependencies,
  input: { batchSize: number; workerId: string }
): Promise<NotificationProcessorResult> {
  const result: NotificationProcessorResult = { claimed: 0, sent: 0, retried: 0, failed: 0, skipped: 0 };
  const claimed = await deps.claimPending({ batchSize: Math.min(Math.max(input.batchSize, 1), 25), workerId: input.workerId });
  result.claimed = claimed.length;

  for (const notification of claimed) {
    if (!deps.config.canSend) {
      await deps.markFailed(notification.id, deps.config.safeErrorCode ?? "EMAIL_SEND_DISABLED");
      result.skipped += 1;
      continue;
    }

    const recipient = await deps.resolveRecipientEmail(notification.recipientProfileId);
    if (!recipient) {
      await deps.markFailed(notification.id, "SKIPPED_NO_VERIFIED_EMAIL");
      result.skipped += 1;
      continue;
    }

    try {
      const template = buildEmailTemplate(notification.eventType, notification.payload);
      const request = createResendEmailRequest({
        config: deps.config,
        eventKey: notification.eventKey,
        intendedRecipient: recipient,
        template
      });
      const sendResult = await deps.sendEmail(request);
      await deps.markSent(notification.id, sendResult.providerMessageId);
      result.sent += 1;
    } catch (error) {
      if (shouldRetryResendError(error)) {
        await deps.markRetry(notification.id, "RESEND_RETRYABLE_ERROR");
        result.retried += 1;
      } else {
        await deps.markFailed(notification.id, "RESEND_PERMANENT_ERROR");
        result.failed += 1;
      }
    }
  }

  return result;
}
