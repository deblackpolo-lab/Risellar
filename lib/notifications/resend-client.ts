import "server-only";

import { Resend } from "resend";
import type { EmailNotificationConfig, EmailRequest } from "./email";

export function createResendSender(config: EmailNotificationConfig) {
  if (!config.resendApiKey) {
    throw new Error("EMAIL_CONFIG_MISSING");
  }

  const resend = new Resend(config.resendApiKey);

  return async function sendEmail(request: EmailRequest) {
    const { data, error } = await resend.emails.send(
      {
        from: request.from,
        to: request.to,
        subject: request.subject,
        html: request.html,
        text: request.text,
        replyTo: request.replyTo
      },
      {
        idempotencyKey: request.headers["Idempotency-Key"]
      }
    );

    if (error) {
      throw error;
    }

    return { providerMessageId: data?.id ?? null };
  };
}

export function createResendWebhookVerifier(config: { apiKey?: string }) {
  const resend = new Resend(config.apiKey);

  return function verify(rawBody: string, headers: Headers, webhookSecret: string) {
    return Promise.resolve(
      resend.webhooks.verify({
        payload: rawBody,
        headers: {
          id: headers.get("svix-id") ?? "",
          timestamp: headers.get("svix-timestamp") ?? "",
          signature: headers.get("svix-signature") ?? ""
        },
        webhookSecret
      }) as unknown as { id: string; type: string; data?: { email_id?: string; emailId?: string } }
    );
  };
}
