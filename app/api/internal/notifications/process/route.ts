import { NextResponse } from "next/server";
import { processPendingTransactionalEmails } from "@/lib/notifications/service";

export async function POST(request: Request) {
  const expected = process.env.NOTIFICATION_PROCESSOR_SECRET;
  const provided = request.headers.get("x-risellar-notification-secret");

  if (!expected) {
    return NextResponse.json({ ok: false, safeErrorCode: "NOTIFICATION_PROCESSOR_SECRET_MISSING" }, { status: 503 });
  }

  if (!provided || provided !== expected) {
    return NextResponse.json({ ok: false, safeErrorCode: "UNAUTHORIZED_NOTIFICATION_PROCESSOR" }, { status: 401 });
  }

  const result = await processPendingTransactionalEmails({
    batchSize: 10,
    workerId: "next-internal-notification-worker"
  });

  return NextResponse.json({ ok: true, result });
}

export function GET() {
  return NextResponse.json({ ok: false, safeErrorCode: "METHOD_NOT_ALLOWED" }, { status: 405 });
}
