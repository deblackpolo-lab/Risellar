import Link from "next/link";
import { PackageCheck, ShieldCheck } from "lucide-react";
import { CheckoutDraftAbandonForm, CheckoutDraftAddressForm } from "@/components/customer/checkout-draft-action-forms";
import { CheckoutOrderConfirmationForm } from "@/components/customer/checkout-order-confirmation-form";
import { MobileShell } from "@/components/layout";
import { Card } from "@/components/ui";
import {
  type CheckoutDraft,
  type CheckoutDraftActionState
} from "@/lib/checkout/draft";
import type { CustomerDeliveryAddress } from "@/lib/customer/profile-address";
import type { CheckoutOrderConfirmationState } from "@/lib/orders/confirm-checkout-order";

function formatGhc(value: number | null, currencyCode: string) {
  if (value === null) {
    return "Price pending";
  }

  const prefix = currencyCode === "GHS" ? "GHâ‚µ" : `${currencyCode} `;
  return `${prefix}${value.toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function snapshotText(snapshot: Record<string, unknown>, key: string) {
  const value = snapshot[key];
  return typeof value === "string" && value.trim() ? value : "Not set";
}

function ActionMessage({ state }: { state: CheckoutDraftActionState | CheckoutOrderConfirmationState }) {
  if (!state.message) {
    return null;
  }

  const isSuccess = state.code === "OK";

  return (
    <p
      className={
        isSuccess
          ? "rounded-[var(--radius-md)] bg-[var(--color-success-soft)] px-3 py-2 text-sm font-semibold text-[var(--color-success)]"
          : "rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] px-3 py-2 text-sm font-semibold text-[var(--color-danger)]"
      }
      role="status"
    >
      {state.message}
    </p>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-b-0 last:pb-0">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="text-right font-bold text-[var(--color-charcoal)]">{value}</span>
    </div>
  );
}

function AddressSelector({ addresses, draft }: { addresses: CustomerDeliveryAddress[]; draft: CheckoutDraft }) {
  return (
    <Card title="Contact and delivery">
      <CheckoutDraftAddressForm addresses={addresses} draft={draft} />
    </Card>
  );
}

function AbandonDraftForm({ draft }: { draft: CheckoutDraft }) {
  return <CheckoutDraftAbandonForm draft={draft} />;
}

function confirmationStateFromError(error: CheckoutDraftActionState | CheckoutOrderConfirmationState | null): CheckoutOrderConfirmationState {
  if (
    error?.code === "ACKNOWLEDGEMENT_REQUIRED" ||
    error?.code === "CHECKOUT_DRAFT_NOT_READY" ||
    error?.code === "INSUFFICIENT_STOCK"
  ) {
    return error;
  }

  return { code: "OK", message: "" };
}

export function CheckoutDraftReviewScreen({
  addresses,
  draft,
  error
}: {
  addresses: CustomerDeliveryAddress[];
  draft: CheckoutDraft | null;
  error: CheckoutDraftActionState | CheckoutOrderConfirmationState | null;
}) {
  if (!draft) {
    return (
      <MobileShell>
        <Card className="p-5 text-center">
          <PackageCheck className="mx-auto h-12 w-12 text-[var(--color-muted)]" aria-hidden="true" />
          <h1 className="mt-3 text-xl font-bold">Draft unavailable</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
            {error?.message ?? "This checkout draft was not found for your customer account."}
          </p>
        </Card>
      </MobileShell>
    );
  }

  const canConfirm = draft.draftStatus === "review_pending" && Boolean(draft.deliveryAddressId);
  const convertedOrderId = typeof draft.convertedOrderId === "string" && draft.convertedOrderId ? draft.convertedOrderId : null;

  return (
    <MobileShell>
      <header className="grid gap-3 rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
        <p className="text-sm font-semibold text-[var(--color-accent)]">Checkout draft</p>
        <h1 className="text-[28px] font-bold leading-tight">Review your draft</h1>
        <p className="text-sm leading-6 text-white/85">
          This draft saves a server-calculated snapshot only. Orders, stock reservation, payment, and delivery remain deferred.
        </p>
      </header>

      {error?.message ? <ActionMessage state={error} /> : null}

      <Card title="Product snapshot">
        <div className="grid gap-3 text-sm">
          <InfoRow label="Product" value={draft.productName} />
          <InfoRow label="Quantity" value={String(draft.quantity)} />
          <InfoRow label="Unit price" value={formatGhc(draft.finalCustomerPriceAmount, draft.currencyCode)} />
          <InfoRow label="Draft total" value={formatGhc(draft.lineTotalAmount, draft.currencyCode)} />
          <InfoRow label="Status" value={draft.draftStatus} />
        </div>
      </Card>

      <AddressSelector addresses={addresses} draft={draft} />

      <Card title="Saved snapshot">
        <div className="grid gap-3 text-sm">
          <InfoRow label="Customer phone" value={snapshotText(draft.customerContactSnapshot, "phone")} />
          <InfoRow label="Address label" value={snapshotText(draft.deliveryAddressSnapshot, "label")} />
          <InfoRow label="Area" value={snapshotText(draft.deliveryAddressSnapshot, "area")} />
          <InfoRow label="City" value={snapshotText(draft.deliveryAddressSnapshot, "city")} />
        </div>
      </Card>

      <Card className="bg-[var(--color-warning-soft)] p-4">
        <div className="flex gap-3">
          <ShieldCheck className="h-5 w-5 flex-none text-[#8A5A00]" aria-hidden="true" />
          <div>
            <p className="text-sm font-bold text-[#8A5A00]">Pay on Delivery confirmation</p>
            <p className="mt-1 text-sm leading-6 text-[#8A5A00]">
              No payment is collected now. Delivery arrangements and any delivery fee will be confirmed separately.
            </p>
          </div>
        </div>
      </Card>

      {convertedOrderId ? (
        <Link
          className="inline-flex h-11 w-full items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-semibold text-white shadow-[var(--shadow-sm)]"
          href={`/customer/orders/${convertedOrderId}`}
        >
          View order
        </Link>
      ) : (
        <CheckoutOrderConfirmationForm
          canConfirm={canConfirm}
          checkoutDraftId={draft.draftId}
          state={confirmationStateFromError(error)}
        />
      )}

      <AbandonDraftForm draft={draft} />
    </MobileShell>
  );
}
