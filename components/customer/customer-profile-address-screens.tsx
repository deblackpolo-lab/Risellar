"use client";

import { useActionState } from "react";
import { Archive, CheckCircle2, Home, MapPin, Phone, Plus, Save } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { Textarea } from "@/components/ui/Textarea";
import {
  archiveCustomerAddressAction,
  createCustomerAddressAction,
  saveCustomerContactAction,
  updateCustomerAddressAction
} from "@/app/customer/addresses/actions";
import {
  initialCustomerProfileAddressActionState,
  type CustomerDeliveryAddress,
  type CustomerProfileAddressActionState
} from "@/lib/customer/profile-address";

function ActionMessage({ state }: { state: CustomerProfileAddressActionState }) {
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

function FormField({
  children,
  label
}: {
  children: React.ReactNode;
  label: string;
}) {
  return (
    <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
      {label}
      {children}
    </label>
  );
}

function ContactForm() {
  const [state, formAction, pending] = useActionState(saveCustomerContactAction, initialCustomerProfileAddressActionState);

  return (
    <Card title="Contact details">
      <form action={formAction} className="grid gap-4">
        <ActionMessage state={state} />
        <div className="grid gap-3 sm:grid-cols-2">
          <FormField label="Full name">
            <Input name="full_name" placeholder="Ama Mensah" required />
          </FormField>
          <FormField label="Email optional">
            <Input name="email" placeholder="ama@example.com" type="email" />
          </FormField>
          <FormField label="Phone number">
            <Input name="phone" placeholder="0200000000" required />
          </FormField>
          <FormField label="WhatsApp optional">
            <Input name="whatsapp" placeholder="0200000001" />
          </FormField>
        </div>
        <Button className="w-full sm:w-fit" loading={pending} type="submit">
          <Save className="h-4 w-4" aria-hidden="true" />
          Save contact
        </Button>
      </form>
    </Card>
  );
}

function CreateAddressForm() {
  const [state, formAction, pending] = useActionState(createCustomerAddressAction, initialCustomerProfileAddressActionState);

  return (
    <Card title="Add delivery address">
      <form action={formAction} className="grid gap-4">
        <ActionMessage state={state} />
        <AddressFields />
        <Button className="w-full sm:w-fit" loading={pending} type="submit">
          <Plus className="h-4 w-4" aria-hidden="true" />
          Add address
        </Button>
      </form>
    </Card>
  );
}

function AddressFields({ address }: { address?: CustomerDeliveryAddress }) {
  return (
    <div className="grid gap-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <FormField label="Address label">
          <Input defaultValue={address?.label} name="label" placeholder="Home" required />
        </FormField>
        <FormField label="Recipient name">
          <Input defaultValue={address?.recipientName} name="recipient_name" placeholder="Ama Mensah" required />
        </FormField>
        <FormField label="Phone number">
          <Input defaultValue={address?.phone} name="phone" placeholder="0200000000" required />
        </FormField>
        <FormField label="Region">
          <Input defaultValue={address?.region} name="region" placeholder="Greater Accra" required />
        </FormField>
        <FormField label="City">
          <Input defaultValue={address?.city} name="city" placeholder="Accra" required />
        </FormField>
        <FormField label="Area">
          <Input defaultValue={address?.area} name="area" placeholder="Osu" required />
        </FormField>
      </div>
      <FormField label="Street address">
        <Textarea defaultValue={address?.streetAddress} name="street_address" placeholder="House number, street, nearby landmark" required />
      </FormField>
      <FormField label="Landmark optional">
        <Input defaultValue={address?.landmark ?? ""} name="landmark" placeholder="Near a visible shop or junction" />
      </FormField>
      <label className="flex items-center gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-muted-soft)] px-3 py-3 text-sm font-semibold text-[var(--color-charcoal)]">
        <input className="h-4 w-4 accent-[var(--color-primary)]" defaultChecked={address?.isDefault} name="is_default" type="checkbox" />
        Use as default delivery address
      </label>
    </div>
  );
}

function AddressCard({ address }: { address: CustomerDeliveryAddress }) {
  const [updateState, updateAction, updatePending] = useActionState(updateCustomerAddressAction, initialCustomerProfileAddressActionState);
  const [archiveState, archiveAction, archivePending] = useActionState(archiveCustomerAddressAction, initialCustomerProfileAddressActionState);

  return (
    <Card className="grid gap-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="text-base font-bold text-[var(--color-charcoal)]">{address.label}</h3>
            {address.isDefault ? <StatusBadge tone="success">Default</StatusBadge> : null}
          </div>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{address.recipientName} - {address.phone}</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">
            {address.streetAddress}, {address.area}, {address.city}
          </p>
        </div>
        <Home className="h-5 w-5 text-[var(--color-primary)]" aria-hidden="true" />
      </div>

      <form action={updateAction} className="grid gap-4 border-t border-[var(--color-border)] pt-4">
        <input name="address_id" type="hidden" value={address.id} />
        <ActionMessage state={updateState} />
        <AddressFields address={address} />
        <div className="grid gap-2 sm:grid-cols-[auto_auto]">
          <Button loading={updatePending} type="submit">
            <Save className="h-4 w-4" aria-hidden="true" />
            Save address
          </Button>
        </div>
      </form>

      <form action={archiveAction} className="border-t border-[var(--color-border)] pt-4">
        <input name="address_id" type="hidden" value={address.id} />
        <ActionMessage state={archiveState} />
        <Button className="mt-3 w-full sm:w-fit" loading={archivePending} type="submit" variant="danger">
          <Archive className="h-4 w-4" aria-hidden="true" />
          Archive address
        </Button>
      </form>
    </Card>
  );
}

export function CustomerProfileAddressScreen({
  addresses,
  error
}: {
  addresses: CustomerDeliveryAddress[];
  error?: CustomerProfileAddressActionState | null;
}) {
  return (
    <main className="min-h-screen bg-[var(--color-background)] px-4 py-6">
      <div className="mx-auto grid w-full max-w-4xl gap-5">
        <header className="grid gap-3 rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
          <p className="text-sm font-semibold text-[var(--color-accent)]">Customer account setup</p>
          <h1 className="text-[28px] font-bold leading-tight">Contact and delivery addresses</h1>
          <p className="max-w-2xl text-sm leading-6 text-white/85">
            Save your own customer contact details and delivery addresses for future checkout steps. No checkout is started from this page.
          </p>
        </header>

        <section className="grid gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4">
          <div className="flex items-center gap-3">
            <CheckCircle2 className="h-5 w-5 text-[var(--color-success)]" aria-hidden="true" />
            <p className="text-sm font-semibold text-[var(--color-charcoal)]">
              Phone and WhatsApp are saved for account setup only. OTP verification is not enabled yet.
            </p>
          </div>
          <div className="flex items-center gap-3">
            <Phone className="h-5 w-5 text-[var(--color-primary)]" aria-hidden="true" />
            <p className="text-sm text-[var(--color-muted)]">Only your signed-in customer profile can manage these records.</p>
          </div>
        </section>

        <ContactForm />
        <CreateAddressForm />

        <section className="grid gap-3">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-lg font-bold text-[var(--color-charcoal)]">Saved delivery addresses</h2>
            <StatusBadge tone={addresses.length > 0 ? "success" : "neutral"}>{`${addresses.length} saved`}</StatusBadge>
          </div>
          {error ? <ActionMessage state={error} /> : null}
          {addresses.length === 0 ? (
            <Card>
              <div className="flex items-center gap-3">
                <MapPin className="h-5 w-5 text-[var(--color-primary)]" aria-hidden="true" />
                <p className="text-sm font-semibold text-[var(--color-muted)]">No saved delivery addresses yet.</p>
              </div>
            </Card>
          ) : (
            <div className="grid gap-4">
              {addresses.map((address) => (
                <AddressCard address={address} key={address.id} />
              ))}
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
