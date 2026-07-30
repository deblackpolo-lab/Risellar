"use client";

import { useState } from "react";
import { CheckCircle2, Loader2 } from "lucide-react";
import { useFormStatus } from "react-dom";
import { confirmCheckoutDraftOrderFormAction } from "@/app/checkout/draft/actions";
import { Button } from "@/components/ui";
import type { CheckoutOrderConfirmationState } from "@/lib/orders/confirm-checkout-order";

const acknowledgementText =
  "I understand that this is a Pay on Delivery order and that delivery arrangements and any delivery fee will be confirmed separately.";

function SubmitButton({ acknowledged, canConfirm }: { acknowledged: boolean; canConfirm: boolean }) {
  const { pending } = useFormStatus();
  const disabled = !canConfirm || !acknowledged || pending;

  return (
    <Button className="w-full" disabled={disabled} type="submit">
      {pending ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" /> : <CheckCircle2 className="h-4 w-4" aria-hidden="true" />}
      {pending ? "Confirming order..." : "Place Pay on Delivery Order"}
    </Button>
  );
}

export function CheckoutOrderConfirmationForm({
  canConfirm,
  checkoutDraftId,
  state
}: {
  canConfirm: boolean;
  checkoutDraftId: string;
  state: CheckoutOrderConfirmationState;
}) {
  const [acknowledged, setAcknowledged] = useState(false);
  const idempotencyKey = `checkout-confirm:${checkoutDraftId}`;

  return (
    <form action={confirmCheckoutDraftOrderFormAction} className="grid gap-4">
      <input name="draft_id" type="hidden" value={checkoutDraftId} />
      <input name="idempotency_key" type="hidden" value={idempotencyKey} />
      <label className="flex gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
        <input
          checked={acknowledged}
          className="mt-1 h-4 w-4 accent-[var(--color-primary)]"
          name="acknowledged_order_terms"
          onChange={(event) => setAcknowledged(event.target.checked)}
          type="checkbox"
        />
        <span>{acknowledgementText}</span>
      </label>
      {state.message ? (
        <p className="rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] px-3 py-2 text-sm font-semibold text-[var(--color-danger)]" role="alert">
          {state.message}
        </p>
      ) : null}
      {!canConfirm ? (
        <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] px-3 py-2 text-sm font-semibold text-[#8A5A00]">
          Attach a saved delivery address and keep this draft in review before placing a Pay on Delivery order.
        </p>
      ) : null}
      <SubmitButton acknowledged={acknowledged} canConfirm={canConfirm} />
    </form>
  );
}
