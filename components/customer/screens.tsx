"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  AlertCircle,
  ArrowLeft,
  Check,
  Clock,
  HelpCircle,
  Mail,
  MapPin,
  Minus,
  PackageCheck,
  Phone,
  Plus,
  Search,
  ShieldCheck,
  Truck,
} from "lucide-react";
import { MobileShell } from "@/components/layout/MobileShell";
import { ProductBrowseGrid, ProductGridCard, ProductImageFrame, ProductImageGallery } from "@/components/marketplace";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Checkbox } from "@/components/ui/Checkbox";
import { Input } from "@/components/ui/Input";
import { ScrollableChipRow } from "@/components/ui/ScrollableChipRow";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { Textarea } from "@/components/ui/Textarea";
import { cn } from "@/lib/utils/cn";
import { customerCheckoutMock, formatGhc, getCustomerProduct, type CustomerProduct } from "@/lib/mock/customer-checkout";

function CustomerHeader({ title, eyebrow, backHref }: { title: string; eyebrow?: string; backHref?: string }) {
  return (
    <header className="flex items-start gap-3">
      {backHref ? (
        <Link
          aria-label="Go back"
          className="grid h-10 w-10 shrink-0 place-items-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white text-[var(--color-charcoal)]"
          href={backHref}
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
      ) : null}
      <div>
        {eyebrow ? <p className="text-xs font-semibold uppercase tracking-normal text-[var(--color-primary)]">{eyebrow}</p> : null}
        <h1 className="text-[22px] font-bold leading-tight text-[var(--color-charcoal)]">{title}</h1>
      </div>
    </header>
  );
}

export function CustomerCheckoutShell({
  title,
  eyebrow,
  children,
  backHref
}: {
  title: string;
  eyebrow?: string;
  children: React.ReactNode;
  backHref?: string;
}) {
  return (
    <MobileShell>
      <CustomerHeader title={title} eyebrow={eyebrow} backHref={backHref} />
      {children}
    </MobileShell>
  );
}

export function PublicShopHeader() {
  const { shop } = customerCheckoutMock;

  return (
    <section className="rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-4 text-white shadow-[var(--shadow-md)]">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-semibold text-[var(--color-accent)]">Risellar Shop</p>
          <h1 className="mt-1 max-w-[13rem] text-[24px] font-semibold leading-[1.16]">{shop.name}</h1>
          <p className="mt-2 flex items-center gap-1 text-sm text-white/85">
            <MapPin className="h-4 w-4" aria-hidden="true" />
            {shop.location}
          </p>
        </div>
        <div className="shrink-0">
          <StatusBadge tone="success">Verified seller</StatusBadge>
        </div>
      </div>
      <p className="mt-3 line-clamp-2 text-sm leading-5 text-white/90">{shop.tagline}</p>
    </section>
  );
}

function CustomerProductCard({ product }: { product: CustomerProduct }) {
  return (
    <ProductGridCard
      badges={[product.stockLabel]}
      category={product.category}
      href={`/shop/${customerCheckoutMock.shop.slug}/product/${product.id}`}
      imageAlt={product.imageAlt}
      images={product.images}
      name={product.name}
      price={formatGhc(product.price)}
      priceLabel="Final customer price"
      rating={`${product.rating} rating`}
      stockStatus={product.stockLabel}
    />
  );
}

export function PublicShopScreen({ shopSlug }: { shopSlug: string }) {
  const [query, setQuery] = useState("");
  const products = useMemo(() => {
    const normalized = query.toLowerCase();
    return customerCheckoutMock.products.filter((product) => `${product.name} ${product.category}`.toLowerCase().includes(normalized));
  }, [query]);

  return (
    <MobileShell>
      <PublicShopHeader />
      <label className="relative mt-4 block">
        <span className="sr-only">Search Ama&apos;s Beauty Plug</span>
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-muted)]" />
        <Input
          aria-label="Search Ama's Beauty Plug"
          className="pl-10"
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search products..."
          type="search"
          value={query}
        />
      </label>
      <ScrollableChipRow className="mt-3">
        {["All", "Sneakers", "Beauty", "Phone Accessories", "Hostel Essentials"].map((category) => (
          <button
            className="h-9 flex-none whitespace-nowrap rounded-full border border-[var(--color-border)] bg-white px-4 text-sm font-semibold text-[var(--color-charcoal)] first:bg-[var(--color-primary)] first:text-white"
            key={category}
            type="button"
          >
            {category}
          </button>
        ))}
      </ScrollableChipRow>
      <Card className="bg-[var(--color-accent-soft)] p-4">
        <div className="flex items-center gap-3">
          <ShieldCheck className="h-5 w-5 text-[var(--color-primary)]" aria-hidden="true" />
          <div>
            <p className="text-base font-bold text-[var(--color-charcoal)]">Pay on Delivery</p>
            <p className="text-sm leading-5 text-[var(--color-muted)]">No upfront payment. Delivery quote is confirmed before dispatch.</p>
          </div>
        </div>
      </Card>
      <section className="grid gap-3">
        <div className="flex items-center justify-between">
          <h2 className="text-[18px] font-semibold leading-6 text-[var(--color-charcoal)]">Featured products</h2>
          <span className="text-sm font-semibold text-[var(--color-primary)]">{shopSlug === customerCheckoutMock.shop.slug ? "Trusted shop" : "Preview"}</span>
        </div>
        <ProductBrowseGrid ariaLabel="Customer storefront products">
          {products.map((product) => (
            <CustomerProductCard key={product.id} product={product} />
          ))}
        </ProductBrowseGrid>
      </section>
    </MobileShell>
  );
}

export function PublicProductHero({ product }: { product: CustomerProduct }) {
  return (
    <section className="grid gap-4">
      <ProductImageGallery productName={product.name} images={product.images} imageAlt={product.imageAlt} />
      <div className="space-y-2">
        <StatusBadge tone={product.stockLabel.includes("Only") ? "warning" : "success"}>{product.stockLabel}</StatusBadge>
        <h1 className="text-[23px] font-bold leading-[1.2] text-[var(--color-charcoal)]">{product.name}</h1>
        <p className="text-sm font-semibold text-[var(--color-muted)]">Sold by {customerCheckoutMock.shop.name}</p>
        <p className="text-2xl font-extrabold text-[var(--color-primary)]">{formatGhc(product.price)}</p>
        <p className="text-sm leading-6 text-[var(--color-muted)]">{product.description}</p>
      </div>
    </section>
  );
}

export function PublicProductDetailScreen({ productId }: { shopSlug: string; productId: string }) {
  const product = getCustomerProduct(productId);

  return (
    <CustomerCheckoutShell title="Product details" backHref={`/shop/${customerCheckoutMock.shop.slug}`}>
      <PublicProductHero product={product} />
      <Card title="Choose your item">
        <div className="grid gap-4">
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Size
            <select className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-4 text-sm">
              <option>42</option>
              <option>41</option>
              <option>43</option>
            </select>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Quantity
            <Input aria-label="Quantity" defaultValue={1} min={1} type="number" />
          </label>
        </div>
      </Card>
      <DeliveryEstimateCard />
      <div className="grid grid-cols-2 gap-3">
        <Button className="w-full" variant="outline">Add to Cart</Button>
        <Button className="w-full">Buy Now</Button>
      </div>
    </CustomerCheckoutShell>
  );
}

function CheckoutProductRow({ quantity = 1 }: { quantity?: number }) {
  const product = getCustomerProduct(customerCheckoutMock.cart.itemId);

  return (
    <div className="grid grid-cols-[72px_1fr] gap-3">
      <ProductImageFrame
        className="rounded-[var(--radius-md)]"
        imageAlt={product.imageAlt}
        images={product.images}
        productName={product.name}
      />
      <div>
        <h2 className="text-sm font-bold text-[var(--color-charcoal)]">{product.name}</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">Size: {customerCheckoutMock.cart.size} • Qty: {quantity}</p>
        <p className="mt-2 text-base font-extrabold text-[var(--color-primary)]">{formatGhc(product.price)}</p>
      </div>
    </div>
  );
}

export function CheckoutSummaryCard({ showFinalQuote = false }: { showFinalQuote?: boolean }) {
  const product = getCustomerProduct(customerCheckoutMock.cart.itemId);
  const delivery = showFinalQuote ? formatGhc(customerCheckoutMock.order.finalDeliveryQuote) : customerCheckoutMock.order.deliveryEstimate;
  const total = showFinalQuote ? formatGhc(customerCheckoutMock.order.totalToPay) : "GH₵360-380";

  return (
    <Card title="Order summary">
      <div className="grid gap-4">
        <CheckoutProductRow />
        <div className="grid gap-2 border-t border-[var(--color-border)] pt-4 text-sm">
          <div className="flex justify-between">
            <span className="text-[var(--color-muted)]">Product price</span>
            <strong>{formatGhc(product.price)}</strong>
          </div>
          <div className="flex justify-between">
            <span className="text-[var(--color-muted)]">Delivery</span>
            <strong>{delivery}</strong>
          </div>
          <div className="flex justify-between text-base">
            <span className="font-bold text-[var(--color-charcoal)]">{showFinalQuote ? "Total to pay on delivery" : "Estimated total"}</span>
            <strong className="text-[var(--color-primary)]">{total}</strong>
          </div>
        </div>
      </div>
    </Card>
  );
}

export function DeliveryEstimateCard() {
  return (
    <Card className="bg-[var(--color-accent-soft)]">
      <div className="flex gap-3">
        <Truck className="mt-0.5 h-5 w-5 shrink-0 text-[var(--color-primary)]" aria-hidden="true" />
        <div>
          <h2 className="font-bold text-[var(--color-charcoal)]">Delivery estimate</h2>
          <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">
            Delivery cost is estimated and will be confirmed before dispatch. You can approve or cancel after the final delivery quote is ready.
          </p>
        </div>
      </div>
    </Card>
  );
}

export function CheckoutCartScreen() {
  const [quantity, setQuantity] = useState<number>(customerCheckoutMock.cart.quantity);
  const product = getCustomerProduct(customerCheckoutMock.cart.itemId);

  return (
    <CustomerCheckoutShell title="Your cart" backHref={`/shop/${customerCheckoutMock.shop.slug}`}>
      <Card>
        <div className="grid gap-4">
          <CheckoutProductRow quantity={quantity} />
          <div className="flex items-center justify-between rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] p-3">
            <span className="text-sm font-semibold text-[var(--color-charcoal)]">Quantity</span>
            <div className="flex items-center gap-3">
              <button
                aria-label="Decrease quantity"
                className="grid h-9 w-9 place-items-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white"
                onClick={() => setQuantity((current) => Math.max(1, current - 1))}
                type="button"
              >
                <Minus className="h-4 w-4" />
              </button>
              <strong>{quantity}</strong>
              <button
                aria-label="Increase quantity"
                className="grid h-9 w-9 place-items-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white"
                onClick={() => setQuantity((current) => current + 1)}
                type="button"
              >
                <Plus className="h-4 w-4" />
              </button>
            </div>
          </div>
          <div className="flex justify-between text-sm">
            <span>Subtotal</span>
            <strong>{formatGhc(product.price * quantity)}</strong>
          </div>
          <div className="flex justify-between text-sm">
            <span>Delivery estimate pending</span>
            <strong>To be confirmed</strong>
          </div>
        </div>
      </Card>
      <DeliveryEstimateCard />
      <Button className="w-full" size="large">Proceed to Checkout</Button>
    </CustomerCheckoutShell>
  );
}

export function CustomerAccountCard() {
  return (
    <Card title="Your details">
      <div className="grid gap-3">
        <Input aria-label="Full name" defaultValue={customerCheckoutMock.customer.name} />
        <Input aria-label="Email address" defaultValue={customerCheckoutMock.customer.email} type="email" />
        <Input aria-label="Phone number" defaultValue={customerCheckoutMock.customer.phone} />
        <Input aria-label="WhatsApp number optional" defaultValue={customerCheckoutMock.customer.whatsapp} />
      </div>
    </Card>
  );
}

export function CheckoutAccountScreen() {
  return (
    <CustomerCheckoutShell title="Create your account" eyebrow="Simple and secure" backHref="/checkout/cart">
      <Card>
        <div className="grid gap-3">
          <Button className="w-full" variant="outline">
            <Mail className="h-4 w-4" aria-hidden="true" />
            Continue with Google
          </Button>
          <Button className="w-full" variant="outline">
            <Mail className="h-4 w-4" aria-hidden="true" />
            Continue with Email
          </Button>
          <p className="text-sm leading-6 text-[var(--color-muted)]">Mock account only. Clerk or auth will connect in a later phase.</p>
        </div>
      </Card>
      <CustomerAccountCard />
      <Card className="bg-[var(--color-primary-subtle)]">
        <div className="grid gap-3 text-sm text-[var(--color-charcoal)]">
          <p className="flex gap-2"><ShieldCheck className="h-4 w-4 text-[var(--color-primary)]" />We use your account to track your order.</p>
          <p className="flex gap-2"><Phone className="h-4 w-4 text-[var(--color-primary)]" />Your phone number helps us contact you for delivery.</p>
          <p className="flex gap-2"><Check className="h-4 w-4 text-[var(--color-primary)]" />No phone OTP is required at this stage.</p>
        </div>
      </Card>
      <Button className="w-full" size="large">Save and Continue</Button>
    </CustomerCheckoutShell>
  );
}

function DeliveryOption({ option, selected }: { option: (typeof customerCheckoutMock.deliveryOptions)[number]; selected?: boolean }) {
  return (
    <button
      className={cn(
        "flex min-h-16 w-full items-center justify-between gap-3 rounded-[var(--radius-md)] border bg-white p-4 text-left",
        selected ? "border-[var(--color-primary)] bg-[var(--color-primary-subtle)]" : "border-[var(--color-border)]"
      )}
      type="button"
    >
      <span>
        <span className="block font-bold text-[var(--color-charcoal)]">{option.name}</span>
        <span className="block text-sm text-[var(--color-muted)]">{option.timing}</span>
      </span>
      <strong className="text-sm text-[var(--color-primary)]">{option.estimate}</strong>
    </button>
  );
}

export function CheckoutDeliveryScreen() {
  const { address } = customerCheckoutMock.customer;

  return (
    <CustomerCheckoutShell title="Delivery details" eyebrow="Where should we deliver?" backHref="/checkout/account">
      <Card title="Location">
        <div className="grid gap-3">
          <div className="grid grid-cols-3 gap-2">
            {["Home", "Hostel", "Work"].map((type) => (
              <button
                className={cn(
                  "h-10 rounded-[var(--radius-md)] border text-sm font-semibold",
                  type === address.type ? "border-[var(--color-primary)] bg-[var(--color-primary-subtle)] text-[var(--color-primary)]" : "border-[var(--color-border)]"
                )}
                key={type}
                type="button"
              >
                {type}
              </button>
            ))}
          </div>
          <Input aria-label="Area or city" defaultValue={address.area} />
          <Input aria-label="Detailed address" defaultValue={address.details} />
          <Input aria-label="Landmark" defaultValue={address.landmark} />
          <Textarea aria-label="Delivery notes" defaultValue={address.notes} />
        </div>
      </Card>
      <Card title="Choose delivery option">
        <div className="grid gap-3">
          {customerCheckoutMock.deliveryOptions.map((option) => (
            <DeliveryOption key={option.id} option={option} selected={option.id === "standard"} />
          ))}
        </div>
      </Card>
      <DeliveryEstimateCard />
      <Button className="w-full" size="large">Save and Continue</Button>
    </CustomerCheckoutShell>
  );
}

export function CheckoutPaymentScreen() {
  return (
    <CustomerCheckoutShell title="Choose payment method" eyebrow="Pay on Delivery" backHref="/checkout/delivery">
      <Card title="Customer account">
        <div className="grid gap-2 text-sm">
          <p className="text-lg font-bold text-[var(--color-charcoal)]">{customerCheckoutMock.customer.name}</p>
          <p className="text-[var(--color-muted)]">{customerCheckoutMock.customer.phone}</p>
          <p className="text-[var(--color-muted)]">{customerCheckoutMock.customer.address.area}</p>
        </div>
      </Card>
      <Card>
        <div className="grid gap-3">
          <button className="rounded-[var(--radius-lg)] border border-[var(--color-primary)] bg-[var(--color-primary-subtle)] p-4 text-left" type="button">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="font-bold text-[var(--color-charcoal)]">Pay on Delivery</p>
                <p className="text-sm text-[var(--color-muted)]">Pay when your item arrives.</p>
              </div>
              <StatusBadge tone="success">Default</StatusBadge>
            </div>
            <div className="mt-3 grid gap-2 text-sm text-[var(--color-charcoal)]">
              <p>No upfront payment</p>
              <p>Inspect your item before paying</p>
              <p>Delivery cost will be confirmed before dispatch.</p>
              <p>We may ask you to confirm the order before processing.</p>
              <p>Order confirmation required</p>
            </div>
          </button>
          <button className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 text-left opacity-70" disabled type="button">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="font-bold text-[var(--color-charcoal)]">Pay Online</p>
                <p className="text-sm text-[var(--color-muted)]">Mobile Money or card will connect later.</p>
              </div>
              <StatusBadge tone="neutral">Coming soon</StatusBadge>
            </div>
          </button>
        </div>
      </Card>
      <CheckoutSummaryCard />
      <StatusBadge status="Awaiting Customer Confirmation" />
      <Button className="w-full" size="large">Place Order</Button>
    </CustomerCheckoutShell>
  );
}

export function CheckoutReviewScreen() {
  const [deliveryAccepted, setDeliveryAccepted] = useState(false);
  const [confirmationAccepted, setConfirmationAccepted] = useState(false);

  return (
    <CustomerCheckoutShell title="Review your order" eyebrow="Confirm before placing" backHref="/checkout/payment">
      <CheckoutSummaryCard />
      <Card title="Customer and delivery">
        <div className="grid gap-3 text-sm">
          <p><strong>{customerCheckoutMock.customer.name}</strong> • {customerCheckoutMock.customer.phone}</p>
          <p>{customerCheckoutMock.customer.address.details}</p>
          <p>{customerCheckoutMock.order.deliveryOption} • {customerCheckoutMock.order.deliveryEstimate}</p>
          <p>{customerCheckoutMock.order.paymentMethod}</p>
        </div>
      </Card>
      <Card>
        <label className="flex gap-3 text-sm font-semibold text-[var(--color-charcoal)]">
          <Checkbox checked={deliveryAccepted} onChange={(event) => setDeliveryAccepted(event.target.checked)} />
          I understand delivery cost will be confirmed before dispatch.
        </label>
        <label className="mt-3 flex gap-3 text-sm font-semibold text-[var(--color-charcoal)]">
          <Checkbox checked={confirmationAccepted} onChange={(event) => setConfirmationAccepted(event.target.checked)} />
          I understand my order must be confirmed before processing.
        </label>
      </Card>
      <Button className="w-full" disabled={!deliveryAccepted || !confirmationAccepted} size="large">Place Order</Button>
    </CustomerCheckoutShell>
  );
}

export function CheckoutSuccessScreen() {
  return (
    <CustomerCheckoutShell title="Order received" eyebrow="Thank you, Nana" backHref="/checkout/review">
      <Card className="text-center">
        <div className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-[var(--color-success-soft)]">
          <Check className="h-10 w-10 text-[var(--color-success)]" aria-hidden="true" />
        </div>
        <h2 className="mt-4 text-xl font-extrabold text-[var(--color-charcoal)]">Received and saved</h2>
        <p className="mt-2 text-sm text-[var(--color-muted)]">Your order has been created and is awaiting confirmation.</p>
        <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] p-3 font-bold">{customerCheckoutMock.order.id}</p>
      </Card>
      <CheckoutSummaryCard />
      <Card title="What happens next?">
        <div className="grid gap-3 text-sm text-[var(--color-charcoal)]">
          <p>Confirm Order so the reseller knows you are serious.</p>
          <p>We contact the supplier after confirmation.</p>
          <p>Delivery cost is confirmed before dispatch.</p>
          <p>Pay when item arrives.</p>
        </div>
      </Card>
      <div className="grid gap-3">
        <Button className="w-full">Confirm Order</Button>
        <Button className="w-full" variant="outline">Track Order</Button>
        <Button className="w-full" variant="ghost">Continue Shopping</Button>
      </div>
    </CustomerCheckoutShell>
  );
}

function OrderStatusCard() {
  return (
    <Card>
      <div className="flex items-center justify-between gap-3">
        <CheckoutProductRow />
      </div>
      <div className="mt-4 flex items-center justify-between">
        <StatusBadge status={customerCheckoutMock.order.status} />
        <strong className="text-[var(--color-primary)]">{formatGhc(customerCheckoutMock.order.productPrice)}</strong>
      </div>
    </Card>
  );
}

export function CustomerOrdersScreen() {
  return (
    <CustomerCheckoutShell title="My orders" eyebrow="Customer account">
      <OrderStatusCard />
      <DeliveryEstimateCard />
    </CustomerCheckoutShell>
  );
}

export function CustomerOrderTimeline({ currentStatus = "Delivery Quote Pending" }: { currentStatus?: string }) {
  const statuses = ["Order Placed", "Awaiting Customer Confirmation", "Customer Confirmed", "Supplier Preparing", "Delivery Quote Pending", "Delivery Approved", "Out for Delivery", "Delivered"];

  return (
    <Card title="Order timeline">
      <ol className="grid gap-4">
        {statuses.map((status, index) => {
          const active = status === currentStatus;
          const complete = index < statuses.indexOf(currentStatus);
          return (
            <li className="flex gap-3" key={status}>
              <span
                className={cn(
                  "grid h-7 w-7 shrink-0 place-items-center rounded-full border text-xs font-bold",
                  active || complete ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-white" : "border-[var(--color-border)] text-[var(--color-muted)]"
                )}
              >
                {complete ? <Check className="h-4 w-4" /> : index + 1}
              </span>
              <div>
                <p className="font-bold text-[var(--color-charcoal)]">{status}</p>
                <p className="text-sm text-[var(--color-muted)]">{active ? "Current step" : complete ? "Completed" : "Coming soon"}</p>
              </div>
            </li>
          );
        })}
      </ol>
    </Card>
  );
}

export function CustomerOrderTrackingScreen({ id }: { id: string }) {
  return (
    <CustomerCheckoutShell title="Track your order" eyebrow={id} backHref="/customer/orders">
      <OrderStatusCard />
      <CustomerOrderTimeline />
      <Button className="w-full" variant="outline">
        <HelpCircle className="h-4 w-4" />
        Need help with this order?
      </Button>
    </CustomerCheckoutShell>
  );
}

export function CustomerOrderConfirmScreen({ id }: { id: string }) {
  const [confirmed, setConfirmed] = useState(false);

  return (
    <CustomerCheckoutShell title="Confirm your order" eyebrow={id} backHref={`/customer/orders/${id}`}>
      <Card>
        <div className="grid gap-4">
          <StatusBadge status={confirmed ? "Customer Confirmed" : "Awaiting Customer Confirmation"} />
          <CheckoutProductRow />
          <div className="rounded-[var(--radius-md)] bg-[var(--color-accent-soft)] p-4 text-sm text-[var(--color-charcoal)]">
            <Clock className="mb-2 h-5 w-5 text-[var(--color-warning)]" aria-hidden="true" />
            {customerCheckoutMock.order.confirmationDeadline} Your item is reserved only after confirmation.
          </div>
        </div>
      </Card>
      <Button className="w-full" onClick={() => setConfirmed(true)} size="large">Confirm Order</Button>
      <Button className="w-full" variant="outline">Cancel Order</Button>
    </CustomerCheckoutShell>
  );
}

export function DeliveryQuoteApprovalCard() {
  return (
    <Card title="Quote details">
      <div className="grid gap-3 text-sm">
        <div className="flex justify-between">
          <span>Product price</span>
          <strong>{formatGhc(customerCheckoutMock.order.productPrice)}</strong>
        </div>
        <div className="flex justify-between">
          <span>Final delivery quote</span>
          <strong>{formatGhc(customerCheckoutMock.order.finalDeliveryQuote)}</strong>
        </div>
        <div className="flex justify-between border-t border-[var(--color-border)] pt-3 text-base">
          <span className="font-bold">Total to pay on delivery</span>
          <strong className="text-[var(--color-primary)]">{formatGhc(customerCheckoutMock.order.totalToPay)}</strong>
        </div>
        <p className="rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] p-3 text-[var(--color-muted)]">
          Delivery to {customerCheckoutMock.customer.address.area}. You can approve, request a change, or cancel before dispatch.
        </p>
      </div>
    </Card>
  );
}

export function CustomerDeliveryQuoteScreen({ id }: { id: string }) {
  const [approved, setApproved] = useState(false);

  return (
    <CustomerCheckoutShell title="Delivery quote" eyebrow={id} backHref={`/customer/orders/${id}`}>
      <StatusBadge status={approved ? "Delivery Approved" : "Delivery Quote Pending"} />
      <DeliveryQuoteApprovalCard />
      <Button className="w-full" onClick={() => setApproved(true)} size="large">Approve Delivery Quote</Button>
      <Button className="w-full" variant="outline">Request Change</Button>
      <Button className="w-full" variant="danger">Cancel Order Before Dispatch</Button>
    </CustomerCheckoutShell>
  );
}

export function CustomerSupportScreen() {
  return (
    <CustomerCheckoutShell title="Help and support" eyebrow="We are here to help">
      {[
        ["My order", "Track, view, or change your order", PackageCheck],
        ["Report an issue", "Problem with your order or delivery", AlertCircle],
        ["Delivery and payments", "Questions about Pay on Delivery", Truck],
        ["Chat with support", "Mock support entry for later integration", HelpCircle]
      ].map(([title, description, Icon]) => (
        <Card key={String(title)}>
          <div className="flex items-center gap-3">
            <Icon className="h-5 w-5 text-[var(--color-primary)]" aria-hidden="true" />
            <div>
              <h2 className="font-bold text-[var(--color-charcoal)]">{String(title)}</h2>
              <p className="text-sm text-[var(--color-muted)]">{String(description)}</p>
            </div>
          </div>
        </Card>
      ))}
    </CustomerCheckoutShell>
  );
}

export function IssueCategoryCard({ category, selected, onSelect }: { category: string; selected?: boolean; onSelect: () => void }) {
  return (
    <button
      className={cn(
        "min-h-12 rounded-[var(--radius-md)] border px-4 text-left text-sm font-semibold",
        selected ? "border-[var(--color-primary)] bg-[var(--color-primary-subtle)] text-[var(--color-primary)]" : "border-[var(--color-border)] bg-white"
      )}
      onClick={onSelect}
      type="button"
    >
      {category}
    </button>
  );
}

export function CustomerReportIssueScreen({ id }: { id: string }) {
  const [selected, setSelected] = useState("Wrong product");
  const [submitted, setSubmitted] = useState(false);

  return (
    <CustomerCheckoutShell title="Report an issue" eyebrow={id} backHref={`/customer/orders/${id}`}>
      {submitted ? (
        <Card>
          <div className="flex items-center gap-3" role="status">
            <Check className="h-6 w-6 text-[var(--color-success)]" aria-hidden="true" />
            <div>
              <h2 className="font-bold text-[var(--color-charcoal)]">Issue Submitted</h2>
              <p className="text-sm text-[var(--color-muted)]">We have received your issue and our team will review it.</p>
            </div>
          </div>
        </Card>
      ) : null}
      <Card title="What happened?">
        <div className="grid grid-cols-2 gap-2">
          {customerCheckoutMock.issueCategories.map((category) => (
            <IssueCategoryCard category={category} key={category} onSelect={() => setSelected(category)} selected={selected === category} />
          ))}
        </div>
      </Card>
      <Card title="Tell us more">
        <Textarea aria-label="Issue details" defaultValue="The product I received is different from what I ordered." />
      </Card>
      <Button className="w-full" onClick={() => setSubmitted(true)} size="large">Submit Issue</Button>
    </CustomerCheckoutShell>
  );
}
