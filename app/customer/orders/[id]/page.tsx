import Link from "next/link";
import { auth } from "@clerk/nextjs/server";
import { notFound, redirect } from "next/navigation";
import { CheckCircle2, Clock, PackageCheck, ShieldCheck, Truck } from "lucide-react";
import { MobileShell } from "@/components/layout";
import { Card } from "@/components/ui";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import { getCustomerOrderSafeWithClient, type CustomerOrderSafe } from "@/lib/orders/customer-order-read";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

function formatMoney(value: number | null, currencyCode: string) {
  if (value === null) {
    return "Amount pending";
  }

  const prefix = currencyCode === "GHS" ? "GHS " : `${currencyCode} `;
  return `${prefix}${value.toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function snapshotText(snapshot: Record<string, unknown>, key: string) {
  const value = snapshot[key];
  return typeof value === "string" && value.trim() ? value : "Not set";
}

function formatDateOnly(value: string | null) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium"
  }).format(new Date(`${value}T00:00:00`));
}

function formatDateTime(value: string | null) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-b-0 last:pb-0">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="text-right font-bold text-[var(--color-charcoal)]">{value}</span>
    </div>
  );
}

async function getCustomerOrderForPage(orderId: string) {
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent(`/customer/orders/${orderId}`)}`);
  }

  const profile = await getCurrentSyncedProfile();

  if (!profile) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent(`/customer/orders/${orderId}`)}`);
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent(`/customer/orders/${orderId}`)}`);
  }

  const supabase = createSupabaseUserServerClient(accessToken);
  const result = await getCustomerOrderSafeWithClient(supabase, orderId);

  if (!result.order) {
    notFound();
  }

  return result.order;
}

function OrderTimeline({ order }: { order: CustomerOrderSafe }) {
  const steps = [
    { label: "Order placed", state: "Completed", active: true },
    { label: order.reservationStatusLabel, state: "Completed", active: true },
    { label: "Customer confirmation", state: order.customerConfirmationLabel, active: false },
    { label: "Supplier preparation", state: "Not started", active: false },
    { label: "Delivery quote", state: order.deliveryQuoteLabel, active: false },
    { label: "Delivery", state: order.deliveryStatusLabel, active: false }
  ];

  return (
    <Card title="Order timeline">
      <ol className="grid gap-4">
        {steps.map((step, index) => (
          <li className="flex gap-3" key={`${step.label}-${index}`}>
            <span
              className={
                step.active
                  ? "grid h-7 w-7 shrink-0 place-items-center rounded-full border border-[var(--color-primary)] bg-[var(--color-primary)] text-xs font-bold text-white"
                  : "grid h-7 w-7 shrink-0 place-items-center rounded-full border border-[var(--color-border)] text-xs font-bold text-[var(--color-muted)]"
              }
            >
              {step.active ? <CheckCircle2 className="h-4 w-4" aria-hidden="true" /> : index + 1}
            </span>
            <div>
              <p className="font-bold text-[var(--color-charcoal)]">{step.label}</p>
              <p className="text-sm text-[var(--color-muted)]">{step.state}</p>
            </div>
          </li>
        ))}
      </ol>
    </Card>
  );
}

function CustomerOrderDetailScreen({ order, placed }: { order: CustomerOrderSafe; placed: boolean }) {
  return (
    <MobileShell>
      <header className="grid gap-3 rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
        <p className="text-sm font-semibold text-[var(--color-accent)]">Customer order</p>
        <h1 className="text-[28px] font-bold leading-tight">{order.orderNumber}</h1>
        <p className="text-sm leading-6 text-white/85">
          Pay on Delivery order details are read-only here. Payment collection, delivery quote approval, supplier preparation, and finance workflows are separate later phases.
        </p>
      </header>

      {placed ? (
        <Card className="border-[var(--color-success)]/30 bg-[var(--color-success-soft)] p-4">
          <div className="flex gap-3">
            <CheckCircle2 className="h-5 w-5 flex-none text-[var(--color-success)]" aria-hidden="true" />
            <div>
              <p className="text-sm font-bold text-[var(--color-success)]">Pay on Delivery order placed</p>
              <p className="mt-1 text-sm leading-6 text-[var(--color-success)]">
                No payment was collected. Delivery arrangements and any delivery fee will be confirmed separately.
              </p>
            </div>
          </div>
        </Card>
      ) : null}

      <Card title="Product">
        <div className="grid gap-3 text-sm">
          <InfoRow label="Product" value={order.productName} />
          <InfoRow label="Quantity" value={String(order.quantity)} />
          <InfoRow label="Unit price" value={formatMoney(order.finalCustomerPriceAmount, order.currencyCode)} />
          <InfoRow label="Product total" value={formatMoney(order.lineTotalAmount, order.currencyCode)} />
          <InfoRow label="Total payable" value={formatMoney(order.totalPayableAmount, order.currencyCode)} />
        </div>
      </Card>

      <Card title="Pay on Delivery status">
        <div className="grid gap-3 text-sm">
          <InfoRow label="Order" value={order.orderStatusLabel} />
          <InfoRow label="Payment method" value={order.paymentMethodLabel} />
          <InfoRow label="Payment collection" value={order.paymentCollectionLabel} />
          <InfoRow label="Delivery" value={order.deliveryStatusLabel} />
          <InfoRow label="Delivery fee" value={order.deliveryQuoteLabel} />
          <InfoRow label="Stock reservation" value={order.reservationStatusLabel} />
        </div>
      </Card>

      {order.deliveryArrangementMethodLabel ? (
        <Card title="Delivery arrangement">
          <div className="grid gap-3 text-sm">
            <InfoRow label="Method" value={order.deliveryArrangementMethodLabel} />
            <InfoRow label="Agreed fee" value={formatMoney(order.deliveryArrangementFeeAmount, order.deliveryArrangementCurrencyCode ?? order.currencyCode)} />
            <InfoRow label="Expected date" value={formatDateOnly(order.deliveryArrangementExpectedDate)} />
            <InfoRow label="Time window" value={order.deliveryArrangementTimeWindow ?? "Not set"} />
            <InfoRow label="Courier/rider" value={order.deliveryArrangementCourierName ?? "Not set"} />
            <InfoRow label="Courier phone" value={order.deliveryArrangementCourierPhone ?? "Not set"} />
            <InfoRow label="Instruction" value={order.deliveryArrangementCustomerInstruction ?? "Not set"} />
          </div>
          {order.deliveryArrangementNotice ? (
            <p className="mt-4 rounded-[var(--radius-md)] border border-[var(--color-primary)]/20 bg-[var(--color-accent-soft)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
              {order.deliveryArrangementNotice}
            </p>
          ) : null}
        </Card>
      ) : null}

      {order.outForDeliveryAt ? (
        <Card title="Out for delivery">
          <div className="grid gap-3 text-sm">
            <InfoRow label="Status" value={order.deliveredAt ? "Your order has been delivered" : "Your order is out for delivery"} />
            <InfoRow label="Dispatched" value={formatDateTime(order.outForDeliveryAt)} />
            <InfoRow label="Instruction" value={order.customerDispatchInstruction ?? "Not set"} />
            {order.deliveredAt ? <InfoRow label="Delivered" value={formatDateTime(order.deliveredAt)} /> : null}
          </div>
          {order.deliveredNotice ? (
            <p className="mt-4 rounded-[var(--radius-md)] border border-[var(--color-primary)]/20 bg-[var(--color-accent-soft)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
              {order.deliveredNotice}
            </p>
          ) : order.dispatchNotice ? (
            <p className="mt-4 rounded-[var(--radius-md)] border border-[var(--color-primary)]/20 bg-[var(--color-accent-soft)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
              {order.dispatchNotice}
            </p>
          ) : null}
          <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">
            Risellar does not provide live tracking, proof of delivery, or online payment collection in this step.
          </p>
        </Card>
      ) : null}

      <Card title="Contact and delivery snapshot">
        <div className="grid gap-3 text-sm">
          <InfoRow label="Phone" value={snapshotText(order.customerContactSnapshot, "phone")} />
          <InfoRow label="Address label" value={snapshotText(order.deliveryAddressSnapshot, "label")} />
          <InfoRow label="Area" value={snapshotText(order.deliveryAddressSnapshot, "area")} />
          <InfoRow label="City" value={snapshotText(order.deliveryAddressSnapshot, "city")} />
        </div>
      </Card>

      <Card className="bg-[var(--color-accent-soft)] p-4">
        <div className="flex gap-3">
          <ShieldCheck className="h-5 w-5 flex-none text-[var(--color-primary)]" aria-hidden="true" />
          <div>
            <p className="text-sm font-bold text-[var(--color-charcoal)]">What happens next</p>
            <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">
              Risellar will keep this as a Pay on Delivery order while later phases handle customer confirmation, supplier preparation, delivery quotes, and support.
            </p>
          </div>
        </div>
      </Card>

      <OrderTimeline order={order} />

      <div className="grid gap-3">
        <Link
          className="inline-flex h-11 w-full items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-5 text-sm font-semibold text-[var(--color-primary)]"
          href="/customer/orders"
        >
          <PackageCheck className="h-4 w-4" aria-hidden="true" />
          Back to orders
        </Link>
        <button
          className="inline-flex h-11 w-full cursor-not-allowed items-center justify-center gap-2 rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] px-5 text-sm font-semibold text-[var(--color-muted)]"
          disabled
          type="button"
        >
          <Truck className="h-4 w-4" aria-hidden="true" />
          Delivery quote actions coming later
        </button>
        <p className="flex items-center justify-center gap-2 text-xs font-semibold text-[var(--color-muted)]">
          <Clock className="h-4 w-4" aria-hidden="true" />
          No online payment, delivery quote, supplier preparation, or finance action is connected here.
        </p>
      </div>
    </MobileShell>
  );
}

export default async function CustomerOrderPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ placed?: string }>;
}) {
  const { id } = await params;
  const query = await searchParams;
  const order = await getCustomerOrderForPage(id);

  return <CustomerOrderDetailScreen order={order} placed={query?.placed === "1"} />;
}
