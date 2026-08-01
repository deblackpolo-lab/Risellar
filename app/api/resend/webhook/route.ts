import { NextResponse } from "next/server";
import { processResendWebhookStatus } from "@/lib/notifications/service";

export async function POST(request: Request) {
  const rawBody = await request.text();
  const result = await processResendWebhookStatus({
    rawBody,
    headers: request.headers
  });

  if (!result.ok) {
    return NextResponse.json({ ok: false, safeErrorCode: result.safeErrorCode }, { status: result.status });
  }

  return NextResponse.json({
    ok: true,
    duplicate: result.duplicate,
    providerStatus: result.providerStatus
  });
}

export function GET() {
  return NextResponse.json({ ok: false, safeErrorCode: "METHOD_NOT_ALLOWED" }, { status: 405 });
}
