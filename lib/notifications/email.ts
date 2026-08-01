import "server-only";

export type EmailSendMode = "disabled" | "redirect" | "live";
export type EmailRecipientRole = "customer" | "supplier" | "reseller" | "finance_admin";

export type EmailNotificationEventType =
  | "order_placed_customer"
  | "order_placed_supplier"
  | "supplier_order_accepted"
  | "supplier_order_rejected"
  | "supplier_order_preparing"
  | "order_ready_for_delivery"
  | "delivery_arranged"
  | "order_out_for_delivery"
  | "order_delivered"
  | "supplier_payment_reported_customer"
  | "supplier_payment_reported_finance"
  | "settlement_verified_supplier"
  | "settlement_verified_customer"
  | "reseller_commission_available"
  | "withdrawal_requested_reseller"
  | "withdrawal_requested_finance"
  | "withdrawal_paid_reseller";

export type EmailNotificationConfig = {
  mode: EmailSendMode;
  canSend: boolean;
  resendApiKey?: string;
  from?: string;
  replyTo?: string;
  devRecipient?: string;
  appUrl: string;
  missing: string[];
  safeErrorCode?: string;
};

export type EmailTemplate = {
  subject: string;
  html: string;
  text: string;
};

export type EmailRequest = {
  from: string;
  to: string[];
  subject: string;
  html: string;
  text: string;
  replyTo?: string;
  headers: {
    "Idempotency-Key": string;
  };
};

type EventMatrixEntry = {
  type: EmailNotificationEventType;
  recipient: EmailRecipientRole;
  subject: string;
};

export const EMAIL_NOTIFICATION_EVENT_MATRIX: EventMatrixEntry[] = [
  { type: "order_placed_customer", recipient: "customer", subject: "Order placed successfully" },
  { type: "order_placed_supplier", recipient: "supplier", subject: "New order received" },
  { type: "supplier_order_accepted", recipient: "customer", subject: "Your order was accepted" },
  { type: "supplier_order_rejected", recipient: "customer", subject: "The supplier could not fulfil your order" },
  { type: "supplier_order_preparing", recipient: "customer", subject: "Your order is being prepared" },
  { type: "order_ready_for_delivery", recipient: "customer", subject: "Your order is ready for delivery arrangement" },
  { type: "delivery_arranged", recipient: "customer", subject: "Delivery has been arranged" },
  { type: "order_out_for_delivery", recipient: "customer", subject: "Your order is out for delivery" },
  { type: "order_delivered", recipient: "customer", subject: "Your order has been delivered" },
  { type: "supplier_payment_reported_customer", recipient: "customer", subject: "Payment was reported by the supplier" },
  { type: "supplier_payment_reported_finance", recipient: "finance_admin", subject: "Supplier settlement requires review" },
  { type: "settlement_verified_supplier", recipient: "supplier", subject: "Your settlement was verified" },
  { type: "settlement_verified_customer", recipient: "customer", subject: "Your order is complete" },
  { type: "reseller_commission_available", recipient: "reseller", subject: "Your commission is now available" },
  { type: "withdrawal_requested_reseller", recipient: "reseller", subject: "Withdrawal request received" },
  { type: "withdrawal_requested_finance", recipient: "finance_admin", subject: "New reseller withdrawal request" },
  { type: "withdrawal_paid_reseller", recipient: "reseller", subject: "Your withdrawal was marked paid" }
];

const PRIVATE_KEY_PATTERNS = [
  /admin/i,
  /private/i,
  /platform.*margin/i,
  /margin/i,
  /commission/i,
  /settlement.*amount/i,
  /payout/i,
  /token/i,
  /secret/i,
  /password/i,
  /jwt/i,
  /cookie/i,
  /risk/i
];

function normalizeMode(value?: string): EmailSendMode {
  if (value === "redirect" || value === "live" || value === "disabled") {
    return value;
  }

  return "disabled";
}

function isProductionEnv(env: Record<string, string | undefined>) {
  return env.NODE_ENV === "production" || env.VERCEL_ENV === "production";
}

function isValidSender(value?: string) {
  if (!value) {
    return false;
  }

  const trimmed = value.trim();
  const bareEmail = /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/;
  const namedEmail = /^.{1,80}<[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+>$/;

  return bareEmail.test(trimmed) || namedEmail.test(trimmed);
}

export function normalizeNotificationAppUrl(value: string | undefined, env: Record<string, string | undefined> = process.env) {
  const fallback = isProductionEnv(env) ? undefined : "http://localhost:400";
  const candidate = (value || fallback || "").trim();

  if (!candidate) {
    return null;
  }

  try {
    const url = new URL(candidate);
    const isLocalhost = url.hostname === "localhost" || url.hostname === "127.0.0.1";
    const allowedProtocol = url.protocol === "https:" || (!isProductionEnv(env) && isLocalhost && url.protocol === "http:");

    if (!allowedProtocol) {
      return null;
    }

    url.pathname = url.pathname.replace(/\/+$/, "");
    url.search = "";
    url.hash = "";

    return url.toString().replace(/\/$/, "");
  } catch {
    return null;
  }
}

export function getEmailNotificationConfig(env: Record<string, string | undefined> = process.env): EmailNotificationConfig {
  const requestedMode = normalizeMode(env.EMAIL_SEND_MODE);
  const missing: string[] = [];
  const appUrl = normalizeNotificationAppUrl(env.NEXT_PUBLIC_APP_URL, env);

  if (!env.RESEND_API_KEY) {
    missing.push("RESEND_API_KEY");
  }
  if (!env.EMAIL_FROM) {
    missing.push("EMAIL_FROM");
  }
  if (!appUrl) {
    missing.push("NEXT_PUBLIC_APP_URL");
  }
  if (requestedMode === "redirect" && !env.EMAIL_DEV_RECIPIENT) {
    missing.push("EMAIL_DEV_RECIPIENT");
  }

  if (requestedMode === "live" && env.NODE_ENV !== "production") {
    return {
      mode: "disabled",
      canSend: false,
      appUrl: appUrl ?? "",
      missing,
      safeErrorCode: "LIVE_MODE_BLOCKED_IN_DEVELOPMENT"
    };
  }

  if (env.EMAIL_FROM && !isValidSender(env.EMAIL_FROM)) {
    return {
      mode: "disabled",
      canSend: false,
      appUrl: appUrl ?? "",
      missing,
      safeErrorCode: "EMAIL_FROM_INVALID"
    };
  }

  if (requestedMode === "disabled" || missing.length > 0) {
    return {
      mode: "disabled",
      canSend: false,
      appUrl: appUrl ?? "",
      missing,
      safeErrorCode: missing.length > 0 ? "EMAIL_CONFIG_MISSING" : undefined
    };
  }

  return {
    mode: requestedMode,
    canSend: true,
    resendApiKey: env.RESEND_API_KEY,
    from: env.EMAIL_FROM,
    replyTo: env.EMAIL_REPLY_TO,
    devRecipient: env.EMAIL_DEV_RECIPIENT,
    appUrl: appUrl!,
    missing
  };
}

export function sanitizeNotificationPayload(payload: Record<string, unknown> = {}) {
  return Object.fromEntries(
    Object.entries(payload).filter(([key, value]) => {
      if (PRIVATE_KEY_PATTERNS.some((pattern) => pattern.test(key))) {
        return false;
      }

      if (typeof value === "string" && /(bearer|secret|token|password|private)/i.test(value)) {
        return false;
      }

      return true;
    })
  );
}

function escapeHtml(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function matrixFor(eventType: EmailNotificationEventType) {
  const entry = EMAIL_NOTIFICATION_EVENT_MATRIX.find((event) => event.type === eventType);

  if (!entry) {
    throw new Error("UNKNOWN_EMAIL_NOTIFICATION_EVENT");
  }

  return entry;
}

function normalizeNotificationCtaPath(value: unknown) {
  if (typeof value !== "string") {
    return "/";
  }

  const trimmed = value.trim();
  if (
    !trimmed ||
    Array.from(trimmed).some((character) => {
      const code = character.charCodeAt(0);
      return code <= 31 || code === 127;
    })
  ) {
    return "/";
  }

  if (/^[a-z][a-z0-9+.-]*:/i.test(trimmed) || trimmed.startsWith("//")) {
    return "/";
  }

  return trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
}

export function createNotificationCtaUrl(appUrl: string, ctaPath: unknown) {
  const base = normalizeNotificationAppUrl(appUrl);
  if (!base) {
    throw new Error("EMAIL_APP_URL_INVALID");
  }

  return new URL(normalizeNotificationCtaPath(ctaPath), `${base}/`).toString();
}

export function buildEmailTemplate(
  eventType: EmailNotificationEventType | string,
  payload: Record<string, unknown> = {},
  options: { appUrl?: string } = {}
): EmailTemplate {
  const entry = matrixFor(eventType as EmailNotificationEventType);
  const safe = sanitizeNotificationPayload(payload);
  const orderNumber = safe.orderNumber ? `Order ${escapeHtml(safe.orderNumber)}` : "Risellar update";
  const productName = safe.productName ? `<p>Product: ${escapeHtml(safe.productName)}</p>` : "";
  const amount = safe.amount ? `<p>Amount: ${escapeHtml(safe.amount)}</p>` : "";
  const ctaUrl = createNotificationCtaUrl(options.appUrl ?? normalizeNotificationAppUrl(process.env.NEXT_PUBLIC_APP_URL) ?? "", safe.ctaPath);
  const bodyNote = safe.safeReasonLabel ? `<p>Reason: ${escapeHtml(safe.safeReasonLabel)}</p>` : "";

  const html = [
    "<!doctype html>",
    "<html><body>",
    `<h1>${escapeHtml(entry.subject)}</h1>`,
    `<p>${orderNumber}</p>`,
    productName,
    amount,
    bodyNote,
    `<p><a href="${escapeHtml(ctaUrl)}">Open in Risellar</a></p>`,
    "<p>This transactional update was generated by Risellar.</p>",
    "</body></html>"
  ].join("");

  const text = [
    entry.subject,
    orderNumber,
    safe.productName ? `Product: ${safe.productName}` : "",
    safe.amount ? `Amount: ${safe.amount}` : "",
    `Open in Risellar: ${ctaUrl}`
  ]
    .filter(Boolean)
    .join("\n");

  return {
    subject: entry.subject,
    html,
    text
  };
}

export function createResendEmailRequest(input: {
  config: EmailNotificationConfig;
  eventKey: string;
  intendedRecipient: string;
  template: EmailTemplate;
}): EmailRequest {
  if (!input.config.canSend || !input.config.from) {
    throw new Error(input.config.safeErrorCode ?? "EMAIL_SEND_DISABLED");
  }

  if (input.eventKey.length > 256) {
    throw new Error("EMAIL_IDEMPOTENCY_KEY_TOO_LONG");
  }

  const recipient = input.config.mode === "redirect" ? input.config.devRecipient : input.intendedRecipient;
  if (!recipient) {
    throw new Error("EMAIL_RECIPIENT_MISSING");
  }

  return {
    from: input.config.from,
    to: [recipient],
    subject: input.config.mode === "redirect" ? `[DEV] ${input.template.subject}` : input.template.subject,
    html: input.template.html,
    text: input.template.text,
    replyTo: input.config.replyTo,
    headers: {
      "Idempotency-Key": input.eventKey
    }
  };
}

export function shouldRetryResendError(error: { statusCode?: number; name?: string; code?: string } | unknown) {
  const err = error as { statusCode?: number; name?: string; code?: string };
  const statusCode = err?.statusCode;
  const name = `${err?.name ?? ""} ${err?.code ?? ""}`;

  if (statusCode && (statusCode === 408 || statusCode === 409 || statusCode === 429 || statusCode >= 500)) {
    return true;
  }

  return /timeout|temporar|rate|concurrent/i.test(name);
}
