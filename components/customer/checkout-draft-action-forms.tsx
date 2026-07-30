import { Ban, MapPin } from "lucide-react";
import { abandonCheckoutDraftFormAction, attachCheckoutDraftAddressFormAction } from "@/app/checkout/draft/actions";
import { Button, Input } from "@/components/ui";
import type { CheckoutDraft } from "@/lib/checkout/draft";
import type { CustomerDeliveryAddress } from "@/lib/customer/profile-address";

export function CheckoutDraftAddressForm({
  addresses,
  draft
}: {
  addresses: CustomerDeliveryAddress[];
  draft: CheckoutDraft;
}) {
  return (
    <form action={attachCheckoutDraftAddressFormAction} className="grid gap-4">
      <input name="draft_id" type="hidden" value={draft.draftId} />
      <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
        Saved delivery address
        <select
          className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)] focus:ring-2 focus:ring-[var(--color-primary)]/15"
          defaultValue={draft.deliveryAddressId ?? addresses.find((address) => address.isDefault)?.id ?? ""}
          name="address_id"
          required
        >
          <option value="" disabled>Choose an address</option>
          {addresses.map((address) => (
            <option key={address.id} value={address.id}>
              {address.label} - {address.area}, {address.city}
            </option>
          ))}
        </select>
      </label>
      <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
        Contact phone optional
        <Input name="contact_phone" placeholder="Use a checkout phone for this draft" />
      </label>
      {addresses.length === 0 ? (
        <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] px-3 py-2 text-sm font-semibold text-[#8A5A00]">
          Add a delivery address before moving this draft to review.
        </p>
      ) : null}
      <div className="flex flex-wrap gap-3">
        <Button disabled={addresses.length === 0 || draft.draftStatus === "abandoned"} type="submit">
          <MapPin className="h-4 w-4" aria-hidden="true" />
          Attach address
        </Button>
        <a
          className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-5 text-sm font-semibold text-[var(--color-primary)]"
          href="/customer/addresses"
        >
          Manage addresses
        </a>
      </div>
    </form>
  );
}

export function CheckoutDraftAbandonForm({ draft }: { draft: CheckoutDraft }) {
  return (
    <form action={abandonCheckoutDraftFormAction}>
      <input name="draft_id" type="hidden" value={draft.draftId} />
      <Button className="mt-3 w-full" disabled={draft.draftStatus === "abandoned"} type="submit" variant="danger">
        <Ban className="h-4 w-4" aria-hidden="true" />
        Abandon draft
      </Button>
    </form>
  );
}
