import { describe, expect, it, vi } from "vitest";
import { handleResendWebhook, type ResendWebhookDependencies } from "@/lib/notifications/resend-webhook";

vi.mock("server-only", () => ({}));

describe("Resend webhook handling", () => {
  it("verifies the raw body before storing provider status", async () => {
    const verify = vi.fn().mockResolvedValue({
      id: "event-id",
      type: "email.delivered",
      data: { email_id: "provider-message-id" }
    });
    const updateProviderStatus = vi.fn().mockResolvedValue(undefined);
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify,
      recordProviderEvent: vi.fn().mockResolvedValue(true),
      updateProviderStatus
    };

    const result = await handleResendWebhook({
      rawBody: "{\"type\":\"email.delivered\"}",
      headers: new Headers({ "svix-id": "event-id" }),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: false, providerStatus: "delivered" });
    expect(verify).toHaveBeenCalledWith("{\"type\":\"email.delivered\"}", expect.any(Headers), "webhook-secret");
    expect(updateProviderStatus).toHaveBeenCalledWith("provider-message-id", "delivered");
  });

  it("rejects invalid signatures without mutating provider status", async () => {
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockRejectedValue(new Error("bad signature")),
      recordProviderEvent: vi.fn(),
      updateProviderStatus: vi.fn()
    };

    const result = await handleResendWebhook({
      rawBody: "{\"type\":\"email.bounced\"}",
      headers: new Headers(),
      deps
    });

    expect(result).toEqual({ ok: false, status: 401, safeErrorCode: "INVALID_SIGNATURE" });
    expect(deps.recordProviderEvent).not.toHaveBeenCalled();
    expect(deps.updateProviderStatus).not.toHaveBeenCalled();
  });

  it("dedupes provider replay events and never mutates business rows", async () => {
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockResolvedValue({
        id: "event-id",
        type: "email.bounced",
        data: { email_id: "provider-message-id" }
      }),
      recordProviderEvent: vi.fn().mockResolvedValue(false),
      updateProviderStatus: vi.fn()
    };

    const result = await handleResendWebhook({
      rawBody: "{\"type\":\"email.bounced\"}",
      headers: new Headers(),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: true, providerStatus: "bounced" });
    expect(deps.updateProviderStatus).not.toHaveBeenCalled();
  });
});
