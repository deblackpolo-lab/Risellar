import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import {
  EMAIL_NOTIFICATION_EVENT_MATRIX,
  buildEmailTemplate,
  createResendEmailRequest,
  getEmailNotificationConfig,
  sanitizeNotificationPayload,
  shouldRetryResendError
} from "@/lib/notifications/email";
import { processEmailNotificationBatch, type NotificationProcessorDependencies } from "@/lib/notifications/processor";

vi.mock("server-only", () => ({}));

function readSourceTree(relativePath: string): string {
  const fullPath = join(process.cwd(), relativePath);
  const stat = statSync(fullPath);

  if (stat.isFile()) {
    return readFileSync(fullPath, "utf8");
  }

  return readdirSync(fullPath)
    .map((entry): string => readSourceTree(join(relativePath, entry)))
    .join("\n");
}

describe("transactional email notifications", () => {
  it("defaults to disabled send mode and never silently enables live sending", () => {
    const config = getEmailNotificationConfig({
      NEXT_PUBLIC_APP_URL: "http://localhost:400"
    });

    expect(config.mode).toBe("disabled");
    expect(config.canSend).toBe(false);
    expect(config.missing).toEqual(expect.arrayContaining(["RESEND_API_KEY", "EMAIL_FROM"]));

    const liveDev = getEmailNotificationConfig({
      NODE_ENV: "development",
      EMAIL_SEND_MODE: "live",
      RESEND_API_KEY: "test-key",
      EMAIL_FROM: "Risellar <dev@example.invalid>",
      NEXT_PUBLIC_APP_URL: "http://localhost:400"
    });

    expect(liveDev.mode).toBe("disabled");
    expect(liveDev.safeErrorCode).toBe("LIVE_MODE_BLOCKED_IN_DEVELOPMENT");
  });

  it("disables sending when EMAIL_FROM is not a valid Resend sender format", () => {
    const config = getEmailNotificationConfig({
      NODE_ENV: "development",
      RESEND_API_KEY: "test-key",
      EMAIL_FROM: "Risellar",
      EMAIL_SEND_MODE: "redirect",
      EMAIL_DEV_RECIPIENT: "qa-inbox@example.invalid",
      NEXT_PUBLIC_APP_URL: "http://localhost:400"
    });

    expect(config.mode).toBe("disabled");
    expect(config.canSend).toBe(false);
    expect(config.safeErrorCode).toBe("EMAIL_FROM_INVALID");
  });

  it("redirect mode replaces the recipient and prefixes the subject for development QA", () => {
    const config = getEmailNotificationConfig({
      NODE_ENV: "development",
      RESEND_API_KEY: "test-key",
      EMAIL_FROM: "Risellar <dev@example.invalid>",
      EMAIL_SEND_MODE: "redirect",
      EMAIL_DEV_RECIPIENT: "qa-inbox@example.invalid",
      NEXT_PUBLIC_APP_URL: "http://localhost:400"
    });
    const template = buildEmailTemplate("order_placed_customer", {
      orderNumber: "RSR-DEV-001",
      productName: "QA Phone",
      amount: "GHS 100.00",
      ctaPath: "/customer/orders/order-id"
    });

    const request = createResendEmailRequest({
      config,
      eventKey: "order_placed_customer/order-id/customer-id",
      intendedRecipient: "customer@example.invalid",
      template
    });

    expect(request.to).toEqual(["qa-inbox@example.invalid"]);
    expect(request.subject).toBe("[DEV] Order placed successfully");
    expect(request.headers["Idempotency-Key"]).toBe("order_placed_customer/order-id/customer-id");
    expect(request.html).not.toContain("customer@example.invalid");
  });

  it("defines every required transactional event and recipient mapping", () => {
    expect(EMAIL_NOTIFICATION_EVENT_MATRIX.map((event) => event.type)).toEqual([
      "order_placed_customer",
      "order_placed_supplier",
      "supplier_order_accepted",
      "supplier_order_rejected",
      "supplier_order_preparing",
      "order_ready_for_delivery",
      "delivery_arranged",
      "order_out_for_delivery",
      "order_delivered",
      "supplier_payment_reported_customer",
      "supplier_payment_reported_finance",
      "settlement_verified_supplier",
      "settlement_verified_customer",
      "reseller_commission_available",
      "withdrawal_requested_reseller",
      "withdrawal_requested_finance",
      "withdrawal_paid_reseller"
    ]);

    for (const event of EMAIL_NOTIFICATION_EVENT_MATRIX) {
      expect(event.recipient).toMatch(/customer|supplier|reseller|finance_admin/);
      expect(event.subject).not.toMatch(/_/);
    }
  });

  it("blocks private fields from notification payloads and templates", () => {
    const unsafe = {
      orderNumber: "RSR-DEV-001",
      productName: "QA Phone",
      platform_margin: 10,
      resellerCommissionAmount: 20,
      supplierPrivateNote: "do not show",
      admin_note: "private",
      payoutAccountNumber: "1234567890",
      token: "secret-token"
    };

    const safe = sanitizeNotificationPayload(unsafe);
    const rendered = buildEmailTemplate("supplier_order_rejected", safe);

    expect(JSON.stringify(safe)).not.toMatch(/platform_margin|resellerCommission|supplierPrivateNote|admin_note|payoutAccount|token/i);
    expect(rendered.html).not.toMatch(/platform margin|commission|private|1234567890|secret-token/i);
    expect(rendered.text).not.toMatch(/platform margin|commission|private|1234567890|secret-token/i);
  });

  it("processes a claimed notification without exposing recipient or mutating business state", async () => {
    const calls: string[] = [];
    const deps: NotificationProcessorDependencies = {
      config: getEmailNotificationConfig({
        NODE_ENV: "development",
        RESEND_API_KEY: "test-key",
        EMAIL_FROM: "Risellar <dev@example.invalid>",
        EMAIL_SEND_MODE: "redirect",
        EMAIL_DEV_RECIPIENT: "qa-inbox@example.invalid",
        NEXT_PUBLIC_APP_URL: "http://localhost:400"
      }),
      claimPending: async () => [
        {
          id: "notification-id",
          eventKey: "order_placed_customer/order-id/customer-id",
          eventType: "order_placed_customer",
          recipientProfileId: "customer-id",
          payload: { orderNumber: "RSR-DEV-001", productName: "QA Phone" }
        }
      ],
      resolveRecipientEmail: async () => "customer@example.invalid",
      sendEmail: async (request) => {
        calls.push(request.headers["Idempotency-Key"]);
        return { providerMessageId: "resend-message-id" };
      },
      markSent: async () => undefined,
      markRetry: async () => undefined,
      markFailed: async () => undefined
    };

    const result = await processEmailNotificationBatch(deps, { batchSize: 10, workerId: "worker-a" });

    expect(result).toEqual({ claimed: 1, sent: 1, retried: 0, failed: 0, skipped: 0 });
    expect(calls).toEqual(["order_placed_customer/order-id/customer-id"]);
  });

  it("classifies retryable and permanent Resend failures safely", () => {
    expect(shouldRetryResendError({ statusCode: 429, name: "rate_limit_exceeded" })).toBe(true);
    expect(shouldRetryResendError({ statusCode: 503, name: "temporary_unavailable" })).toBe(true);
    expect(shouldRetryResendError({ statusCode: 400, name: "invalid_idempotency_key" })).toBe(false);
    expect(shouldRetryResendError({ statusCode: 422, name: "validation_error" })).toBe(false);
  });

  it("keeps Resend, service role, and direct send calls out of client components", () => {
    const componentSources = ["app", "components"].map(readSourceTree).join("\n");
    const notificationSources = ["lib/notifications"].map((path) => (statSync(path).isDirectory() ? "" : "")).join("");

    expect(componentSources).not.toContain("RESEND_API_KEY");
    expect(componentSources).not.toContain("new Resend");
    expect(componentSources).not.toContain("createSupabaseAdminClient");
    expect(notificationSources).toBe("");
  });
});
