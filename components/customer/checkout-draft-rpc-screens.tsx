import { PackageCheck, ShieldCheck, Truck } from "lucide-react";
import { CheckoutDraftAbandonForm, CheckoutDraftAddressForm } from "@/components/customer/checkout-draft-action-forms";
import { MobileShell } from "@/components/layout";
import { Button, Card } from "@/components/ui";
import {
  type CheckoutDraft,
  type CheckoutDraftActionState
} from "@/lib/checkout/draft";
import type { CustomerDeliveryAddress } from "@/lib/customer/profile-address";

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

function ActionMessage({ state }: { state: CheckoutDraftActionState }) {
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

export function CheckoutDraftReviewScreen({
  addresses,
  draft,
  error
}: {
  addresses: CustomerDeliveryAddress[];
  draft: CheckoutDraft | null;
  error: CheckoutDraftActionState | null;
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
        <p className="text-sm font-bold text-[#8A5A00]">Final confirmation disabled</p>
            <p className="mt-1 text-sm leading-6 text-[#8A5A00]">
              The next phase will create orders and reserve stock after a separate backend approval. This page cannot place an order.
            </p>
          </div>
        </div>
      </Card>

      <Button className="w-full" disabled type="button">
        <Truck className="h-4 w-4" aria-hidden="true" />
        Order confirmation coming next
      </Button>

      <AbandonDraftForm draft={draft} />
    </MobileShell>
  );
}
