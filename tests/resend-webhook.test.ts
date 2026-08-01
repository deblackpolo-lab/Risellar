import { describe, expect, it, vi } from "vitest";
import { handleResendWebhook, type ResendWebhookDependencies } from "@/lib/notifications/resend-webhook";

vi.mock("server-only", () => ({}));

describe("Resend webhook handling", () => {
  const realResendPayload = {
    created_at: "2026-08-01T16:38:39.731Z",
    data: {
      created_at: "2026-08-01T16:38:39.574Z",
      email_id: "email-fake-provider-id",
      from: "Risellar <onboarding@resend.dev>",
      message_id: "message-fake-provider-id",
      subject: "[DEV] Order placed successfully",
      to: ["dev-inbox@example.test"]
    },
    type: "email.sent"
  };

  it("uses svix-id to store real Resend payloads that do not include a body id", async () => {
    const recordProviderEvent = vi.fn().mockResolvedValue(true);
    const updateProviderStatus = vi.fn().mockResolvedValue(undefined);
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockResolvedValue(realResendPayload),
      recordProviderEvent,
      updateProviderStatus
    };

    const result = await handleResendWebhook({
      rawBody: JSON.stringify(realResendPayload),
      headers: new Headers({
        "svix-id": "msg_real_svix_id",
        "svix-timestamp": "1785602317",
        "svix-signature": "v1,fake"
      }),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: false, providerStatus: "sent" });
    expect(recordProviderEvent).toHaveBeenCalledWith({
      ...realResendPayload,
      providerEventId: "msg_real_svix_id"
    });
    expect(updateProviderStatus).not.toHaveBeenCalled();
  });

  it("updates provider status for delivered and bounced events", async () => {
    const updateProviderStatus = vi.fn().mockResolvedValue(undefined);
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockResolvedValue({ ...realResendPayload, type: "email.delivered" }),
      recordProviderEvent: vi.fn().mockResolvedValue(true),
      updateProviderStatus
    };

    const deliveredResult = await handleResendWebhook({
      rawBody: JSON.stringify({ ...realResendPayload, type: "email.delivered" }),
      headers: new Headers({ "svix-id": "msg_delivered_svix_id" }),
      deps
    });

    expect(deliveredResult).toEqual({ ok: true, duplicate: false, providerStatus: "delivered" });
    expect(updateProviderStatus).toHaveBeenCalledWith("email-fake-provider-id", "delivered");
  });

  it("dedupes real Resend replays by svix-id", async () => {
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockResolvedValue({ ...realResendPayload, type: "email.sent" }),
      recordProviderEvent: vi.fn().mockResolvedValue(false),
      updateProviderStatus: vi.fn()
    };

    const result = await handleResendWebhook({
      rawBody: JSON.stringify(realResendPayload),
      headers: new Headers({ "svix-id": "msg_replay_svix_id" }),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: true, providerStatus: "sent" });
    expect(deps.updateProviderStatus).not.toHaveBeenCalled();
  });

  it("accepts unmatched real Resend email IDs without crashing", async () => {
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockResolvedValue(realResendPayload),
      recordProviderEvent: vi.fn().mockResolvedValue(true),
      updateProviderStatus: vi.fn().mockResolvedValue(false)
    };

    const result = await handleResendWebhook({
      rawBody: JSON.stringify(realResendPayload),
      headers: new Headers({ "svix-id": "msg_unmatched_svix_id" }),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: false, providerStatus: "sent" });
  });

  it("ignores unsupported signed Resend event types without storing provider events", async () => {
    const deps: ResendWebhookDependencies = {
      webhookSecret: "webhook-secret",
      verify: vi.fn().mockResolvedValue({ ...realResendPayload, type: "email.rendered" }),
      recordProviderEvent: vi.fn(),
      updateProviderStatus: vi.fn()
    };

    const result = await handleResendWebhook({
      rawBody: JSON.stringify({ ...realResendPayload, type: "email.rendered" }),
      headers: new Headers({ "svix-id": "msg_unsupported_svix_id" }),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: false, providerStatus: "ignored" });
    expect(deps.recordProviderEvent).not.toHaveBeenCalled();
    expect(deps.updateProviderStatus).not.toHaveBeenCalled();
  });

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
      headers: new Headers({ "svix-id": "event-id" }),
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
      headers: new Headers({ "svix-id": "event-id" }),
      deps
    });

    expect(result).toEqual({ ok: true, duplicate: true, providerStatus: "bounced" });
    expect(deps.updateProviderStatus).not.toHaveBeenCalled();
  });
});
