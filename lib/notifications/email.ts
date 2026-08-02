import "server-only";

export type EmailSendMode = "disabled" | "redirect" | "live";
export type EmailRecipientRole = "customer" | "supplier" | "reseller" | "support_admin" | "finance_admin";

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
  | "withdrawal_paid_reseller"
  | "dispute_opened_customer"
  | "dispute_information_requested_customer"
  | "dispute_status_updated_customer"
  | "dispute_resolved_customer"
  | "dispute_closed_customer"
  | "return_requested_customer"
  | "return_approved_customer"
  | "return_rejected_customer"
  | "return_received_customer"
  | "return_accepted_customer"
  | "return_declined_customer"
  | "return_completed_customer"
  | "refund_approved_customer"
  | "refund_reported_sent_customer"
  | "refund_customer_confirmation_required"
  | "refund_verified_customer"
  | "refund_completed_customer"
  | "dispute_opened_supplier"
  | "dispute_information_requested_supplier"
  | "dispute_status_updated_supplier"
  | "dispute_resolved_supplier"
  | "return_requested_supplier"
  | "return_approved_supplier"
  | "return_in_transit_supplier"
  | "return_received_supplier"
  | "return_inspection_required_supplier"
  | "return_completed_supplier"
  | "refund_obligation_supplier"
  | "refund_report_required_supplier"
  | "refund_customer_disputed_not_received_supplier"
  | "refund_verified_supplier"
  | "supplier_liability_created"
  | "supplier_liability_updated"
  | "dispute_affecting_commission_reseller"
  | "commission_hold_created_reseller"
  | "commission_hold_released_reseller"
  | "reseller_liability_review_created"
  | "reseller_liability_approved"
  | "future_earnings_offset_enabled"
  | "liability_recovery_applied"
  | "liability_recovered"
  | "withdrawal_blocked_by_finance_review"
  | "withdrawal_allocation_released"
  | "withdrawal_ready_after_review"
  | "new_dispute_admin"
  | "dispute_response_received_admin"
  | "dispute_information_received_admin"
  | "return_requested_admin"
  | "return_received_admin"
  | "return_inspected_admin"
  | "refund_customer_disputed_not_received_admin"
  | "refund_reported_sent_admin"
  | "refund_approval_required_finance"
  | "refund_reported_sent_finance"
  | "refund_customer_disputed_not_received_finance"
  | "refund_verification_required_finance"
  | "finance_hold_created_finance"
  | "settlement_blocked_finance"
  | "commission_hold_created_finance"
  | "reseller_liability_review_finance"
  | "withdrawal_blocked_finance";

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
  defaultCtaPath: string;
};

export const EMAIL_NOTIFICATION_EVENT_MATRIX: EventMatrixEntry[] = [
  { type: "order_placed_customer", recipient: "customer", subject: "Order placed successfully", defaultCtaPath: "/customer/orders/example-id" },
  { type: "order_placed_supplier", recipient: "supplier", subject: "New order received", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "supplier_order_accepted", recipient: "customer", subject: "Your order was accepted", defaultCtaPath: "/customer/orders/example-id" },
  { type: "supplier_order_rejected", recipient: "customer", subject: "The supplier could not fulfil your order", defaultCtaPath: "/customer/orders/example-id" },
  { type: "supplier_order_preparing", recipient: "customer", subject: "Your order is being prepared", defaultCtaPath: "/customer/orders/example-id" },
  { type: "order_ready_for_delivery", recipient: "customer", subject: "Your order is ready for delivery arrangement", defaultCtaPath: "/customer/orders/example-id" },
  { type: "delivery_arranged", recipient: "customer", subject: "Delivery has been arranged", defaultCtaPath: "/customer/orders/example-id" },
  { type: "order_out_for_delivery", recipient: "customer", subject: "Your order is out for delivery", defaultCtaPath: "/customer/orders/example-id" },
  { type: "order_delivered", recipient: "customer", subject: "Your order has been delivered", defaultCtaPath: "/customer/orders/example-id" },
  { type: "supplier_payment_reported_customer", recipient: "customer", subject: "Payment was reported by the supplier", defaultCtaPath: "/customer/orders/example-id" },
  { type: "supplier_payment_reported_finance", recipient: "finance_admin", subject: "Supplier settlement requires review", defaultCtaPath: "/admin/finance" },
  { type: "settlement_verified_supplier", recipient: "supplier", subject: "Your settlement was verified", defaultCtaPath: "/supplier/finance" },
  { type: "settlement_verified_customer", recipient: "customer", subject: "Your order is complete", defaultCtaPath: "/customer/orders/example-id" },
  { type: "reseller_commission_available", recipient: "reseller", subject: "Your commission is now available", defaultCtaPath: "/reseller/wallet" },
  { type: "withdrawal_requested_reseller", recipient: "reseller", subject: "Withdrawal request received", defaultCtaPath: "/reseller/withdrawals" },
  { type: "withdrawal_requested_finance", recipient: "finance_admin", subject: "New reseller withdrawal request", defaultCtaPath: "/admin/withdrawals/example-id" },
  { type: "withdrawal_paid_reseller", recipient: "reseller", subject: "Your withdrawal was marked paid", defaultCtaPath: "/reseller/withdrawals" },
  { type: "dispute_opened_customer", recipient: "customer", subject: "Dispute opened for your order", defaultCtaPath: "/customer/orders/example-id" },
  { type: "dispute_information_requested_customer", recipient: "customer", subject: "More information needed", defaultCtaPath: "/customer/orders/example-id" },
  { type: "dispute_status_updated_customer", recipient: "customer", subject: "Your dispute status was updated", defaultCtaPath: "/customer/orders/example-id" },
  { type: "dispute_resolved_customer", recipient: "customer", subject: "Your dispute has been resolved", defaultCtaPath: "/customer/orders/example-id" },
  { type: "dispute_closed_customer", recipient: "customer", subject: "Your dispute has been closed", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_requested_customer", recipient: "customer", subject: "Return request received", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_approved_customer", recipient: "customer", subject: "Your return request has been approved", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_rejected_customer", recipient: "customer", subject: "Your return request was not approved", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_received_customer", recipient: "customer", subject: "Returned item received", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_accepted_customer", recipient: "customer", subject: "Your returned item was accepted", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_declined_customer", recipient: "customer", subject: "Your returned item needs review", defaultCtaPath: "/customer/orders/example-id" },
  { type: "return_completed_customer", recipient: "customer", subject: "Your return has been completed", defaultCtaPath: "/customer/orders/example-id" },
  { type: "refund_approved_customer", recipient: "customer", subject: "Refund approved", defaultCtaPath: "/customer/orders/example-id" },
  { type: "refund_reported_sent_customer", recipient: "customer", subject: "Refund sent, please confirm", defaultCtaPath: "/customer/orders/example-id" },
  { type: "refund_customer_confirmation_required", recipient: "customer", subject: "Please confirm your refund", defaultCtaPath: "/customer/orders/example-id" },
  { type: "refund_verified_customer", recipient: "customer", subject: "Refund verified", defaultCtaPath: "/customer/orders/example-id" },
  { type: "refund_completed_customer", recipient: "customer", subject: "Refund completed", defaultCtaPath: "/customer/orders/example-id" },
  { type: "dispute_opened_supplier", recipient: "supplier", subject: "A customer reported a problem with an item", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "dispute_information_requested_supplier", recipient: "supplier", subject: "More information needed for a dispute", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "dispute_status_updated_supplier", recipient: "supplier", subject: "A dispute status was updated", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "dispute_resolved_supplier", recipient: "supplier", subject: "A dispute has been resolved", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "return_requested_supplier", recipient: "supplier", subject: "A customer requested a return", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "return_approved_supplier", recipient: "supplier", subject: "A return was approved", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "return_in_transit_supplier", recipient: "supplier", subject: "A return is on the way", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "return_received_supplier", recipient: "supplier", subject: "Return receipt recorded", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "return_inspection_required_supplier", recipient: "supplier", subject: "Please inspect the returned item", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "return_completed_supplier", recipient: "supplier", subject: "Return completed", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "refund_obligation_supplier", recipient: "supplier", subject: "Please send the approved refund", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "refund_report_required_supplier", recipient: "supplier", subject: "Refund report needed", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "refund_customer_disputed_not_received_supplier", recipient: "supplier", subject: "Customer says refund was not received", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "refund_verified_supplier", recipient: "supplier", subject: "Refund report verified", defaultCtaPath: "/supplier/orders/example-id" },
  { type: "supplier_liability_created", recipient: "supplier", subject: "Supplier liability recorded", defaultCtaPath: "/supplier/settlements" },
  { type: "supplier_liability_updated", recipient: "supplier", subject: "Supplier liability updated", defaultCtaPath: "/supplier/settlements" },
  { type: "dispute_affecting_commission_reseller", recipient: "reseller", subject: "A dispute may affect your commission", defaultCtaPath: "/reseller/wallet" },
  { type: "commission_hold_created_reseller", recipient: "reseller", subject: "Part of your commission is under review", defaultCtaPath: "/reseller/wallet" },
  { type: "commission_hold_released_reseller", recipient: "reseller", subject: "Commission review released", defaultCtaPath: "/reseller/wallet" },
  { type: "reseller_liability_review_created", recipient: "reseller", subject: "Commission liability review opened", defaultCtaPath: "/reseller/wallet" },
  { type: "reseller_liability_approved", recipient: "reseller", subject: "Commission liability approved", defaultCtaPath: "/reseller/wallet" },
  { type: "future_earnings_offset_enabled", recipient: "reseller", subject: "Future earnings recovery plan updated", defaultCtaPath: "/reseller/wallet" },
  { type: "liability_recovery_applied", recipient: "reseller", subject: "Liability recovery applied", defaultCtaPath: "/reseller/wallet" },
  { type: "liability_recovered", recipient: "reseller", subject: "Liability recovered", defaultCtaPath: "/reseller/wallet" },
  { type: "withdrawal_blocked_by_finance_review", recipient: "reseller", subject: "Withdrawal under finance review", defaultCtaPath: "/reseller/withdrawals" },
  { type: "withdrawal_allocation_released", recipient: "reseller", subject: "Withdrawal review released", defaultCtaPath: "/reseller/withdrawals" },
  { type: "withdrawal_ready_after_review", recipient: "reseller", subject: "Withdrawal ready after review", defaultCtaPath: "/reseller/withdrawals" },
  { type: "new_dispute_admin", recipient: "support_admin", subject: "New dispute needs review", defaultCtaPath: "/admin/disputes/example-id" },
  { type: "dispute_response_received_admin", recipient: "support_admin", subject: "Dispute response received", defaultCtaPath: "/admin/disputes/example-id" },
  { type: "dispute_information_received_admin", recipient: "support_admin", subject: "Requested dispute information received", defaultCtaPath: "/admin/disputes/example-id" },
  { type: "return_requested_admin", recipient: "support_admin", subject: "Return request needs review", defaultCtaPath: "/admin/returns/example-id" },
  { type: "return_received_admin", recipient: "support_admin", subject: "Returned item received", defaultCtaPath: "/admin/returns/example-id" },
  { type: "return_inspected_admin", recipient: "support_admin", subject: "Returned item inspected", defaultCtaPath: "/admin/returns/example-id" },
  { type: "refund_customer_disputed_not_received_admin", recipient: "support_admin", subject: "Refund receipt disputed", defaultCtaPath: "/admin/refunds/example-id" },
  { type: "refund_reported_sent_admin", recipient: "support_admin", subject: "Refund report received", defaultCtaPath: "/admin/refunds/example-id" },
  { type: "refund_approval_required_finance", recipient: "finance_admin", subject: "Refund approval needed", defaultCtaPath: "/admin/finance" },
  { type: "refund_reported_sent_finance", recipient: "finance_admin", subject: "Refund verification needed", defaultCtaPath: "/admin/finance" },
  { type: "refund_customer_disputed_not_received_finance", recipient: "finance_admin", subject: "Refund receipt dispute needs finance review", defaultCtaPath: "/admin/finance" },
  { type: "refund_verification_required_finance", recipient: "finance_admin", subject: "Refund verification needed", defaultCtaPath: "/admin/finance" },
  { type: "finance_hold_created_finance", recipient: "finance_admin", subject: "Finance hold created", defaultCtaPath: "/admin/finance" },
  { type: "settlement_blocked_finance", recipient: "finance_admin", subject: "Settlement blocked by active dispute", defaultCtaPath: "/admin/finance" },
  { type: "commission_hold_created_finance", recipient: "finance_admin", subject: "Commission hold created", defaultCtaPath: "/admin/finance" },
  { type: "reseller_liability_review_finance", recipient: "finance_admin", subject: "Reseller liability review needed", defaultCtaPath: "/admin/finance" },
  { type: "withdrawal_blocked_finance", recipient: "finance_admin", subject: "Withdrawal under finance review", defaultCtaPath: "/admin/withdrawals/example-id" }
];

const PRIVATE_KEY_PATTERNS = [
  /admin/i,
  /private/i,
  /platform.*margin/i,
  /margin/i,
  /commission/i,
  /settlement.*amount/i,
  /payout/i,
  /address/i,
  /reference/i,
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

export function getNotificationCatalogEntry(eventType: EmailNotificationEventType | string) {
  return matrixFor(eventType as EmailNotificationEventType);
}

export function buildEmailNotificationEventKey(
  eventType: EmailNotificationEventType | string,
  entityId: string,
  auditActionId: string,
  recipientRole: EmailRecipientRole | string,
  suffix?: string
) {
  const parts = [eventType, entityId, auditActionId, recipientRole, suffix].filter((part): part is string => typeof part === "string");

  if (
    parts.length < 4 ||
    parts.some((part) => {
      const trimmed = part.trim();
      return !trimmed || /[\s/]/.test(trimmed) || /(password|secret|token|jwt|cookie)/i.test(trimmed);
    })
  ) {
    throw new Error("EMAIL_NOTIFICATION_EVENT_KEY_PART_INVALID");
  }

  const key = parts.join(":");
  if (key.length > 256) {
    throw new Error("EMAIL_NOTIFICATION_EVENT_KEY_TOO_LONG");
  }

  return key;
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
  const ctaUrl = createNotificationCtaUrl(
    options.appUrl ?? normalizeNotificationAppUrl(process.env.NEXT_PUBLIC_APP_URL) ?? "",
    safe.ctaPath ?? entry.defaultCtaPath
  );
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
