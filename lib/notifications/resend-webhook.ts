import "server-only";

export type ResendWebhookEvent = {
  id: string;
  type: string;
  data?: {
    email_id?: string;
    emailId?: string;
    [key: string]: unknown;
  };
};

export type ResendWebhookDependencies = {
  webhookSecret: string;
  verify: (rawBody: string, headers: Headers, secret: string) => Promise<ResendWebhookEvent>;
  recordProviderEvent: (event: ResendWebhookEvent) => Promise<boolean>;
  updateProviderStatus: (providerMessageId: string, providerStatus: string) => Promise<void>;
};

const PROVIDER_STATUS_BY_EVENT: Record<string, string> = {
  "email.sent": "sent",
  "email.delivered": "delivered",
  "email.delivery_delayed": "delivery_delayed",
  "email.bounced": "bounced",
  "email.complained": "complained",
  "email.opened": "opened",
  "email.clicked": "clicked"
};

export async function handleResendWebhook(input: {
  rawBody: string;
  headers: Headers;
  deps: ResendWebhookDependencies;
}): Promise<
  | { ok: true; duplicate: boolean; providerStatus: string }
  | { ok: false; status: number; safeErrorCode: "INVALID_SIGNATURE" | "UNSUPPORTED_EVENT" | "MISSING_PROVIDER_MESSAGE_ID" }
> {
  let event: ResendWebhookEvent;

  try {
    event = await input.deps.verify(input.rawBody, input.headers, input.deps.webhookSecret);
  } catch {
    return { ok: false, status: 401, safeErrorCode: "INVALID_SIGNATURE" };
  }

  const providerStatus = PROVIDER_STATUS_BY_EVENT[event.type];
  if (!providerStatus) {
    return { ok: false, status: 202, safeErrorCode: "UNSUPPORTED_EVENT" };
  }

  const providerMessageId = event.data?.email_id ?? event.data?.emailId;
  if (!providerMessageId) {
    return { ok: false, status: 400, safeErrorCode: "MISSING_PROVIDER_MESSAGE_ID" };
  }

  const firstSeen = await input.deps.recordProviderEvent(event);
  if (!firstSeen) {
    return { ok: true, duplicate: true, providerStatus };
  }

  await input.deps.updateProviderStatus(providerMessageId, providerStatus);
  return { ok: true, duplicate: false, providerStatus };
}
