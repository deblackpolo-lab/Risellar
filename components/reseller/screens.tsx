"use client";

import type { ReactElement, ReactNode } from "react";
import { useMemo, useState } from "react";
import {
  Bell,
  CheckCircle2,
  Copy,
  Filter,
  Headphones,
  MapPin,
  Package,
  Search,
  Share2,
  ShieldCheck,
  ShoppingBag,
  Wallet
} from "lucide-react";
import { BottomNav, MobileShell } from "@/components/layout";
import { Button, Card, Input, StatusBadge } from "@/components/ui";
import {
  formatGhc,
  getResellerCategory,
  getResellerProduct,
  resellerCategories,
  resellerCoreProducts,
  resellerNotifications,
  resellerOrders,
  resellerProfile,
  resellerTransactions,
  type ResellerProduct
} from "@/lib/mock/reseller-core";
import { cn } from "@/lib/utils/cn";

type OnboardingStep = "welcome" | "type" | "profile" | "area" | "payout" | "rules" | "complete";

const onboardingCopy: Record<OnboardingStep, { title: string; eyebrow: string; body: string }> = {
  welcome: {
    eyebrow: "Start selling safely",
    title: "Welcome to Risellar",
    body: "Pick trusted products, share your shop, and earn commission after verified supplier settlement."
  },
  type: {
    eyebrow: "Choose reseller type",
    title: "Welcome to Risellar",
    body: "Choose how you plan to sell. Clerk or email sign-in will connect later."
  },
  profile: {
    eyebrow: "Profile setup",
    title: "Tell us about you",
    body: "Your public reseller profile helps customers trust your shop."
  },
  area: {
    eyebrow: "Area selection",
    title: "Where do you sell?",
    body: "Use realistic Ghana locations so customers understand delivery coverage."
  },
  payout: {
    eyebrow: "MoMo payout",
    title: "Set up your payout",
    body: "Withdraw available commission to your MoMo wallet when the minimum is reached."
  },
  rules: {
    eyebrow: "Reseller rules",
    title: "Keep it fair and trusted",
    body: "No fake orders, no supplier bypass, and no misleading prices. Pending commission is not withdrawable."
  },
  complete: {
    eyebrow: "All set",
    title: "You're ready to sell",
    body: "Your shop is ready with mock data. Real account and payment services will connect later."
  }
};

const navByRoute = {
  home: "Home",
  shop: "Shop",
  orders: "Orders",
  wallet: "Wallet",
  account: "Account"
} as const;

function ResellerShell({ active = "Home", children, title }: { active?: string; children: ReactNode; title: string }) {
  return (
    <MobileShell footer={<BottomNav active={active} />} title={title}>
      {children}
    </MobileShell>
  );
}

export function ResellerOnboardingScreen({ step }: { step: OnboardingStep }) {
  const copy = onboardingCopy[step];
  const isComplete = step === "complete";

  return (
    <ResellerShell active={navByRoute.account} title="Reseller onboarding">
      <section className="space-y-5">
        <div className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)]">
          <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{copy.eyebrow}</p>
          <div className="mt-5 grid place-items-center rounded-[var(--radius-lg)] bg-[var(--color-primary-subtle)] py-8">
            {isComplete ? (
              <CheckCircle2 className="h-16 w-16 text-[var(--color-success)]" aria-hidden="true" />
            ) : (
              <ShoppingBag className="h-16 w-16 text-[var(--color-primary)]" aria-hidden="true" />
            )}
          </div>
          <h1 className="mt-5 text-2xl font-bold text-[var(--color-charcoal)]">{copy.title}</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{copy.body}</p>
        </div>

        {step === "type" ? <TypeChoices /> : null}
        {step === "profile" ? <ProfileForm /> : null}
        {step === "area" ? <AreaChoices /> : null}
        {step === "payout" ? <PayoutForm /> : null}
        {step === "rules" ? <RulesList /> : null}
        {isComplete ? <CompletionActions /> : null}

        {!isComplete ? <Button className="w-full">Continue</Button> : null}
      </section>
    </ResellerShell>
  );
}

function TypeChoices() {
  return (
    <div className="grid gap-3">
      {["Student Reseller", "General Reseller", "Influencer", "Beauty Plug"].map((type, index) => (
        <Card className={cn("p-4", index === 1 && "border-[var(--color-primary)] bg-[var(--color-primary-subtle)]")} key={type}>
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="font-bold">{type}</p>
              <p className="mt-1 text-sm text-[var(--color-muted)]">
                {type === "Beauty Plug" ? "I focus on beauty and skincare." : "I sell trusted products to my network."}
              </p>
            </div>
            {index === 1 ? <StatusBadge status="Active" /> : null}
          </div>
        </Card>
      ))}
    </div>
  );
}

function ProfileForm() {
  return (
    <Card title="Profile details">
      <div className="space-y-3">
        <LabeledInput label="Full name" value={resellerProfile.name} />
        <LabeledInput label="Shop name" value={resellerProfile.shopName} />
        <LabeledInput label="Phone number" value={resellerProfile.momoNumber} />
      </div>
    </Card>
  );
}

function AreaChoices() {
  return (
    <Card title="Choose your area">
      <div className="space-y-2 text-sm">
        {["Legon, Accra", "Madina, Accra", "UPSA, Accra", "Kumasi, Ashanti Region"].map((area) => (
          <div className="flex items-center justify-between rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 py-3" key={area}>
            <span>{area}</span>
            {area === resellerProfile.location ? <StatusBadge status="Selected" /> : null}
          </div>
        ))}
      </div>
    </Card>
  );
}

function PayoutForm() {
  return (
    <Card title="MoMo payout details">
      <div className="space-y-3">
        <LabeledInput label="Mobile Money provider" value={resellerProfile.momoProvider} />
        <LabeledInput label="MoMo number" value={resellerProfile.momoNumber} />
        <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm text-[#8A5A00]">
          You can withdraw only available commission. Pending commission is released after settlement verification.
        </p>
      </div>
    </Card>
  );
}

function RulesList() {
  return (
    <Card title="Reseller agreement">
      <div className="space-y-3 text-sm">
        {["I will share authentic product information.", "I will not place fake orders.", "I will respect Pay on Delivery confirmation steps.", "I understand pending commission cannot be withdrawn."].map((rule) => (
          <div className="flex gap-3" key={rule}>
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-success)]" aria-hidden="true" />
            <span>{rule}</span>
          </div>
        ))}
      </div>
    </Card>
  );
}

function CompletionActions() {
  return (
    <div className="grid gap-3">
      <Button>Go to Dashboard</Button>
      <Button variant="outline">Take me to My Shop</Button>
    </div>
  );
}

export function ResellerDashboardCoreScreen() {
  const hotProducts = resellerCoreProducts.slice(0, 3);

  return (
    <ResellerShell active={navByRoute.home} title="Reseller dashboard">
      <Header />
      <div className="mt-5 space-y-4">
        <section className="rounded-[var(--radius-xl)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-sm)]">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-white/80">Available balance</p>
              <p className="mt-1 text-3xl font-bold">{formatGhc(resellerProfile.availableBalance)}</p>
            </div>
            <Wallet className="h-8 w-8 text-white/80" aria-hidden="true" />
          </div>
          <p className="mt-3 text-xs text-white/75">Pending commission is held until supplier settlement is verified.</p>
        </section>

        <div className="grid grid-cols-2 gap-3">
          <Metric label="Pending commission" value={formatGhc(resellerProfile.pendingCommission)} status="Commission Pending" />
          <Metric label="Orders" value={`${resellerProfile.ordersThisMonth}`} status="Completed" />
          <Metric label="Products shared" value={`${resellerProfile.productsShared}`} status="Trending" />
          <Metric label="Active products" value={`${resellerProfile.activeProducts}`} status="In Stock" />
        </div>

        <ActionGrid />
        <ProductSection title="Hot products" products={hotProducts} />
      </div>
    </ResellerShell>
  );
}

function Header() {
  return (
    <header className="flex items-start justify-between gap-4">
      <div>
        <p className="text-sm text-[var(--color-muted)]">Good morning, {resellerProfile.firstName}</p>
        <h1 className="mt-1 text-2xl font-bold">{resellerProfile.shopName}</h1>
        <p className="mt-1 flex items-center gap-1 text-sm text-[var(--color-muted)]">
          <MapPin className="h-4 w-4" aria-hidden="true" />
          {resellerProfile.location}
        </p>
      </div>
      <div className="grid h-11 w-11 place-items-center rounded-full bg-[var(--color-primary)] text-sm font-bold text-white">AP</div>
    </header>
  );
}

function Metric({ label, status, value }: { label: string; status: string; value: string }) {
  return (
    <Card className="p-4">
      <p className="text-xs font-semibold text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-xl font-bold">{value}</p>
      <div className="mt-3">
        <StatusBadge status={status} />
      </div>
    </Card>
  );
}

function ActionGrid() {
  return (
    <section>
      <h2 className="mb-3 text-base font-bold">Quick actions</h2>
      <div className="grid grid-cols-2 gap-3">
        {["Browse Products", "Share My Shop", "View Orders", "Withdraw"].map((action, index) => (
          <Button key={action} size="compact" variant={index === 0 ? "primary" : "outline"}>
            {action}
          </Button>
        ))}
      </div>
    </section>
  );
}

export function ResellerProductCatalogScreen({ categoryId }: { categoryId?: string }) {
  const [query, setQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState(categoryId ?? "all");
  const category = categoryId ? getResellerCategory(categoryId) : undefined;
  const filteredProducts = useMemo(() => {
    return resellerCoreProducts.filter((product) => {
      const matchesCategory = selectedCategory === "all" || product.categoryId === selectedCategory;
      const matchesQuery = product.name.toLowerCase().includes(query.toLowerCase());
      return matchesCategory && matchesQuery;
    });
  }, [query, selectedCategory]);

  return (
    <ResellerShell active={navByRoute.shop} title={category ? `${category.name} products` : "Product catalog"}>
      <header>
        <h1 className="text-2xl font-bold">Browse trusted products</h1>
        <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">Choose products with clear reseller cost, profit, stock, and settlement rules.</p>
      </header>

      <label className="relative mt-5 block">
        <span className="sr-only">Search products</span>
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-muted)]" aria-hidden="true" />
        <Input
          aria-label="Search products"
          className="pl-10"
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search products, brands..."
          type="search"
          value={query}
        />
      </label>

      <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
        <Filter className="mt-2 h-4 w-4 shrink-0 text-[var(--color-muted)]" aria-hidden="true" />
        <button className={filterClass(selectedCategory === "all")} onClick={() => setSelectedCategory("all")} type="button">
          All
        </button>
        {resellerCategories.map((categoryOption) => (
          <button
            className={filterClass(selectedCategory === categoryOption.id)}
            key={categoryOption.id}
            onClick={() => setSelectedCategory(categoryOption.id)}
            type="button"
          >
            {categoryOption.name}
          </button>
        ))}
      </div>

      <ProductSection products={filteredProducts} title={category ? category.name : "All products"} />
    </ResellerShell>
  );
}

function filterClass(active: boolean) {
  return cn(
    "h-9 shrink-0 rounded-full border px-4 text-sm font-semibold transition",
    active
      ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
      : "border-[var(--color-border)] bg-white text-[var(--color-muted)]"
  );
}

function ProductSection({ products, title }: { products: ResellerProduct[]; title: string }) {
  return (
    <section className="mt-6">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-base font-bold">{title}</h2>
        <StatusBadge status={`${products.length} products`} tone="neutral" />
      </div>
      <div className="grid gap-3">
        {products.map((product) => (
          <ProductTile key={product.id} product={product} />
        ))}
      </div>
    </section>
  );
}

function ProductTile({ product }: { product: ResellerProduct }) {
  return (
    <Card className="p-4">
      <div className="flex gap-4">
        <ProductImageTile category={product.category} name={product.name} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap gap-2">
            {product.tags.slice(0, 2).map((tag) => (
              <StatusBadge key={tag} status={tag} />
            ))}
          </div>
          <h3 className="mt-2 text-sm font-bold leading-5">{product.name}</h3>
          <p className="mt-1 text-xs text-[var(--color-muted)]">{product.category} • {product.rating}</p>
          <div className="mt-3 grid gap-1 text-sm">
            <p className="font-semibold text-[var(--color-primary)]">Reseller cost {formatGhc(product.resellerCost)}</p>
            <p className="text-[var(--color-muted)]">Suggested {formatGhc(product.suggestedSellingPrice)}</p>
            <p className="text-[var(--color-muted)]">Profit {formatGhc(product.expectedProfit)}</p>
          </div>
          <div className="mt-3">
            <StatusBadge status={product.stockStatus} />
          </div>
        </div>
      </div>
    </Card>
  );
}

function ProductImageTile({ category, name, size = "normal" }: { category: string; name: string; size?: "normal" | "large" }) {
  const initials = category
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div
      aria-label={`${name} product image`}
      className={cn(
        "grid shrink-0 place-items-center overflow-hidden rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[linear-gradient(135deg,#FFF7E6_0%,#E7F4ED_55%,#FFFFFF_100%)] shadow-[var(--shadow-sm)]",
        size === "large" ? "aspect-[4/3] w-full" : "h-24 w-24"
      )}
      role="img"
    >
      <div className="grid h-14 w-14 place-items-center rounded-2xl bg-white text-lg font-black text-[var(--color-primary)] shadow-[var(--shadow-sm)]">
        {initials}
      </div>
    </div>
  );
}

export function ResellerProductDetailScreen({ id }: { id: string }) {
  const product = getResellerProduct(id);

  return (
    <ResellerShell active={navByRoute.shop} title="Product detail">
      <Card className="p-4">
        <ProductImageTile category={product.category} name={product.name} size="large" />
        <div className="mt-4 flex flex-wrap gap-2">
          {product.tags.map((tag) => (
            <StatusBadge key={tag} status={tag} />
          ))}
          <StatusBadge status={product.stockStatus} />
        </div>
        <p className="mt-3 text-xs font-bold uppercase text-[var(--color-muted)]">{product.category}</p>
        <h1 className="mt-1 text-2xl font-bold leading-tight">{product.name}</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">{product.variant} • {product.rating}</p>
      </Card>

      <section className="mt-4 grid gap-4">
        <Card title="Profit and price">
          <div className="space-y-3 text-sm">
            <InfoRow label="Reseller cost" value={formatGhc(product.resellerCost)} />
            <InfoRow label="Suggested selling price" value={formatGhc(product.suggestedSellingPrice)} />
            <InfoRow label="Max allowed selling price" value={formatGhc(product.maxAllowedPrice)} />
            <InfoRow label="Expected profit" value={formatGhc(product.expectedProfit)} />
          </div>
        </Card>

        <Card title="Stock and delivery">
          <div className="space-y-3 text-sm">
            <InfoRow badge={product.stockStatus} label="Stock" value={`${product.stockCount} available`} />
            <p className="leading-6 text-[var(--color-muted)]">{product.deliveryNote}</p>
            <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-[#8A5A00]">{product.settlementNote}</p>
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-3">
          <Button>Add to My Shop</Button>
          <Button variant="outline">Share Product</Button>
        </div>
      </section>
    </ResellerShell>
  );
}

export function ResellerPriceScreen({ id }: { id: string }) {
  const product = getResellerProduct(id);
  const [price, setPrice] = useState(product.suggestedSellingPrice);
  const profit = Math.max(0, price - product.resellerCost);
  const isTooHigh = price > product.maxAllowedPrice;

  return (
    <ResellerShell active={navByRoute.shop} title="Set selling price">
      <header>
        <h1 className="text-2xl font-bold">Set your selling price</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">{product.name}</p>
      </header>

      <Card className="mt-5" title="Price guardrails">
        <div className="space-y-3 text-sm">
          <InfoRow label="Reseller cost" value={formatGhc(product.resellerCost)} />
          <InfoRow label="Suggested selling price" value={formatGhc(product.suggestedSellingPrice)} />
          <InfoRow label="Maximum allowed" value={formatGhc(product.maxAllowedPrice)} />
        </div>
      </Card>

      <Card className="mt-4" title="Profit preview">
        <label className="block text-sm font-semibold" htmlFor="selling-price">
          Your selling price
        </label>
        <Input
          aria-label="Your selling price"
          className="mt-2"
          id="selling-price"
          max={product.maxAllowedPrice}
          min={product.resellerCost}
          onChange={(event) => setPrice(Number(event.target.value))}
          type="number"
          value={price}
        />
        <p className="mt-3 text-sm text-[var(--color-muted)]">Maximum allowed: {formatGhc(product.maxAllowedPrice)}</p>
        <div className="mt-4 rounded-[var(--radius-lg)] bg-[var(--color-primary-subtle)] p-4">
          <p className="text-xs font-semibold text-[var(--color-muted)]">Expected profit</p>
          <p className="mt-1 text-2xl font-bold text-[var(--color-primary)]">{formatGhc(profit)}</p>
        </div>
        {isTooHigh ? (
          <p className="mt-3 rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] p-3 text-sm font-semibold text-[var(--color-danger)]">
            Price is above the allowed maximum. Lower it before saving.
          </p>
        ) : null}
      </Card>

      <Button className="mt-4 w-full" disabled={isTooHigh}>
        Save Selling Price
      </Button>
    </ResellerShell>
  );
}

export function ResellerAddedProductScreen({ id }: { id: string }) {
  const product = getResellerProduct(id);

  return (
    <ResellerShell active={navByRoute.shop} title="Added product">
      <div className="grid min-h-[70vh] place-items-center">
        <Card className="w-full text-center">
          <CheckCircle2 className="mx-auto h-16 w-16 text-[var(--color-success)]" aria-hidden="true" />
          <h1 className="mt-4 text-2xl font-bold">Added to My Shop</h1>
          <p className="mt-2 text-sm text-[var(--color-muted)]">{product.name} has been added to {resellerProfile.shopName}.</p>
          <div className="mt-5 grid gap-3">
            <Button>View My Shop</Button>
            <Button variant="outline">Continue Shopping</Button>
          </div>
        </Card>
      </div>
    </ResellerShell>
  );
}

export function ResellerShopScreen({ empty = false }: { empty?: boolean }) {
  const shopProducts = empty ? [] : resellerCoreProducts.filter((product) => product.inShop);

  return (
    <ResellerShell active={navByRoute.shop} title="My shop">
      <ShopHeader />
      <div className="mt-4 grid grid-cols-3 gap-3">
        <Metric label="Products" value={`${shopProducts.length}`} status="Active" />
        <Metric label="Orders" value={`${resellerProfile.ordersThisMonth}`} status="Completed" />
        <Metric label="Followers" value={`${resellerProfile.followers}`} status="Trending" />
      </div>
      <div className="mt-4 grid grid-cols-2 gap-3">
        <Button>Share Shop</Button>
        <Button variant="outline">Edit Shop</Button>
      </div>
      {shopProducts.length ? (
        <ProductSection products={shopProducts} title="Products in shop" />
      ) : (
        <EmptyPanel action="Add Products" description="Add trusted products to start receiving Pay on Delivery orders." title="Your shop is empty" />
      )}
    </ResellerShell>
  );
}

function ShopHeader() {
  return (
    <Card>
      <div className="flex items-center gap-4">
        <div className="grid h-16 w-16 place-items-center rounded-2xl bg-[var(--color-primary)] text-lg font-black text-white">AP</div>
        <div>
          <h1 className="text-2xl font-bold">{resellerProfile.shopName}</h1>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{resellerProfile.location}</p>
          <p className="text-sm font-semibold text-[var(--color-primary)]">{resellerProfile.type}</p>
        </div>
      </div>
    </Card>
  );
}

export function ResellerShopEditScreen() {
  return (
    <ResellerShell active={navByRoute.account} title="Edit shop">
      <header>
        <h1 className="text-2xl font-bold">Edit shop profile</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">This is a mock settings form for Phase 4.</p>
      </header>
      <Card className="mt-5" title="Shop details">
        <div className="space-y-3">
          <LabeledInput label="Shop name" value={resellerProfile.shopName} />
          <LabeledInput label="Location" value={resellerProfile.location} />
          <LabeledInput label="Handle" value={resellerProfile.handle} />
        </div>
      </Card>
      <Button className="mt-4 w-full">Save Mock Changes</Button>
    </ResellerShell>
  );
}

export function ResellerMyProductsScreen() {
  return <ResellerShopScreen />;
}

export function ResellerShareProductScreen({ productId }: { productId: string }) {
  const product = getResellerProduct(productId);
  const [copied, setCopied] = useState(false);
  const caption = `Fresh drop alert! ${product.name}. Original quality, ${formatGhc(product.suggestedSellingPrice)}. ${product.deliveryNote} DM me to order from ${resellerProfile.shopName}.`;

  return (
    <ResellerShell active={navByRoute.shop} title="Share product">
      <Card>
        <div className="flex gap-4">
          <ProductImageTile category={product.category} name={product.name} />
          <div>
            <h1 className="text-xl font-bold">{product.name}</h1>
            <p className="mt-2 text-lg font-bold text-[var(--color-primary)]">{formatGhc(product.suggestedSellingPrice)}</p>
            <p className="mt-1 text-sm text-[var(--color-muted)]">Ready for delivery anywhere in Accra after confirmation.</p>
          </div>
        </div>
      </Card>

      <Card className="mt-4" title="Ready-made WhatsApp caption">
        <p className="whitespace-pre-line rounded-[var(--radius-md)] bg-[var(--color-page)] p-4 text-sm leading-6">{caption}</p>
        <p className="mt-3 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
          Link preview: risellar.app/{resellerProfile.handle.replace("@", "")}/{product.id}
        </p>
      </Card>

      <div className="mt-4 grid gap-3">
        <Button>
          <Share2 className="h-4 w-4" aria-hidden="true" />
          Share to WhatsApp
        </Button>
        <Button onClick={() => setCopied(true)} variant="outline">
          <Copy className="h-4 w-4" aria-hidden="true" />
          Copy Caption
        </Button>
        {copied ? <p className="text-center text-sm font-semibold text-[var(--color-success)]">Caption copied</p> : null}
      </div>
    </ResellerShell>
  );
}

export function ResellerOrdersScreen() {
  return (
    <ResellerShell active={navByRoute.orders} title="Orders">
      <header>
        <h1 className="text-2xl font-bold">My orders</h1>
        <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
          Commission becomes available after supplier settlement is verified.
        </p>
      </header>
      <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
        {["All", "Pending", "Quote Pending", "Completed"].map((filter, index) => (
          <button className={filterClass(index === 0)} key={filter} type="button">
            {filter}
          </button>
        ))}
      </div>
      <div className="mt-5 grid gap-3">
        {resellerOrders.map((order) => (
          <OrderTile key={order.id} orderId={order.id} />
        ))}
      </div>
    </ResellerShell>
  );
}

function OrderTile({ orderId }: { orderId: string }) {
  const order = resellerOrders.find((item) => item.id === orderId) ?? resellerOrders[0];

  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs text-[var(--color-muted)]">Order {order.id}</p>
          <h3 className="mt-1 text-sm font-bold">{order.product}</h3>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{order.customer}</p>
        </div>
        <StatusBadge status={order.status} />
      </div>
      <div className="mt-4 flex items-center justify-between text-sm">
        <span className="text-[var(--color-muted)]">Expected commission</span>
        <span className="font-bold text-[var(--color-primary)]">{formatGhc(order.expectedCommission)}</span>
      </div>
      <div className="mt-3">
        <StatusBadge status={order.commissionStatus} />
      </div>
    </Card>
  );
}

export function ResellerOrderDetailScreen({ id }: { id: string }) {
  const order = resellerOrders.find((item) => item.id === id) ?? resellerOrders[0];

  return (
    <ResellerShell active={navByRoute.orders} title="Order detail">
      <Card>
        <p className="text-xs text-[var(--color-muted)]">Order ID</p>
        <h1 className="mt-1 text-2xl font-bold">{order.id}</h1>
        <div className="mt-3">
          <StatusBadge status={order.status} />
        </div>
      </Card>
      <Card className="mt-4" title="Order summary">
        <div className="space-y-3 text-sm">
          <InfoRow label="Customer" value={order.customer} />
          <InfoRow label="Product" value={order.product} />
          <InfoRow label="Total" value={formatGhc(order.total)} />
          <InfoRow label="Expected commission" value={formatGhc(order.expectedCommission)} />
        </div>
      </Card>
      <Card className="mt-4" title="Timeline">
        <div className="space-y-3">
          {order.timeline.map((event) => (
            <div className="flex gap-3 text-sm" key={event}>
              <CheckCircle2 className="mt-0.5 h-4 w-4 text-[var(--color-success)]" aria-hidden="true" />
              {event}
            </div>
          ))}
        </div>
      </Card>
    </ResellerShell>
  );
}

export function ResellerWalletScreen() {
  return (
    <ResellerShell active={navByRoute.wallet} title="Wallet">
      <section className="rounded-[var(--radius-xl)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-sm)]">
        <p className="text-sm text-white/80">Available balance</p>
        <p className="mt-1 text-3xl font-bold">{formatGhc(resellerProfile.availableBalance)}</p>
        <p className="mt-2 text-sm text-white/80">Minimum withdrawal is GH₵50.</p>
      </section>
      <div className="mt-4 grid grid-cols-2 gap-3">
        <Metric label="Pending commission" value={formatGhc(resellerProfile.pendingCommission)} status="Commission Pending" />
        <Metric label="Total earned" value={formatGhc(resellerProfile.totalEarned)} status="Completed" />
      </div>
      <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm text-[#8A5A00]">
        Pending commission cannot be withdrawn until supplier settlement is verified.
      </p>
      <Button className="mt-4 w-full">Request Withdrawal</Button>
      <TransactionList />
    </ResellerShell>
  );
}

export function ResellerWithdrawScreen() {
  return (
    <ResellerShell active={navByRoute.wallet} title="Withdraw">
      <header>
        <h1 className="text-2xl font-bold">Withdraw to MoMo</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">Mock request only. Real payouts will connect later.</p>
      </header>
      <Card className="mt-5" title="Withdrawal request">
        <div className="space-y-3">
          <LabeledInput label="Available balance" value={formatGhc(resellerProfile.availableBalance)} />
          <LabeledInput label="Amount" value="GH₵100" />
          <LabeledInput label="MoMo account" value={`${resellerProfile.momoProvider} • ${resellerProfile.momoNumber}`} />
        </div>
      </Card>
      <Button className="mt-4 w-full">Request Withdrawal</Button>
    </ResellerShell>
  );
}

export function ResellerTransactionsScreen() {
  return (
    <ResellerShell active={navByRoute.wallet} title="Transactions">
      <header>
        <h1 className="text-2xl font-bold">Transaction history</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">Track pending, available, paid, and failed commission movements.</p>
      </header>
      <TransactionList />
    </ResellerShell>
  );
}

function TransactionList() {
  return (
    <div className="mt-5 grid gap-3">
      {resellerTransactions.map((transaction) => (
        <Card className="p-4" key={transaction.id}>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm font-bold">{transaction.label}</p>
              <p className="mt-1 text-xs text-[var(--color-muted)]">{transaction.date}</p>
            </div>
            <div className="text-right">
              <p className="font-bold text-[var(--color-primary)]">{formatGhc(Math.abs(transaction.amount))}</p>
              <div className="mt-2">
                <StatusBadge status={transaction.status} />
              </div>
            </div>
          </div>
        </Card>
      ))}
    </div>
  );
}

export function ResellerNotificationsScreen() {
  const [read, setRead] = useState<string[]>([]);

  return (
    <ResellerShell active={navByRoute.account} title="Notifications">
      <header>
        <h1 className="text-2xl font-bold">Notifications</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">Mock notifications for orders, commission, stock, and withdrawals.</p>
      </header>
      <div className="mt-5 grid gap-3">
        {resellerNotifications.map((notification) => (
          <Card className={cn("p-4", read.includes(notification) && "opacity-70")} key={notification}>
            <div className="flex items-start gap-3">
              <Bell className="mt-1 h-4 w-4 shrink-0 text-[var(--color-primary)]" aria-hidden="true" />
              <div className="flex-1">
                <p className="text-sm leading-6">{notification}</p>
                <button className="mt-2 text-sm font-semibold text-[var(--color-primary)]" onClick={() => setRead((items) => [...items, notification])} type="button">
                  Mark notification read
                </button>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </ResellerShell>
  );
}

export function ResellerSettingsScreen() {
  return (
    <ResellerShell active={navByRoute.account} title="Settings">
      <header>
        <h1 className="text-2xl font-bold">Settings</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">Profile, payout, shop, and support options use mock settings in Phase 4.</p>
      </header>
      <Card className="mt-5" title="Account summary">
        <div className="space-y-3 text-sm">
          <InfoRow label="Shop" value={resellerProfile.shopName} />
          <InfoRow label="Type" value={resellerProfile.type} />
          <InfoRow label="Location" value={resellerProfile.location} />
          <InfoRow label="MoMo provider" value={resellerProfile.momoProvider} />
          <InfoRow label="Payout number" value={resellerProfile.momoNumber} />
        </div>
      </Card>
      <div className="mt-4 grid gap-3">
        <SettingsItem icon={<ShoppingBag />} label="Shop settings" />
        <SettingsItem icon={<Wallet />} label="MoMo payout details" />
        <SettingsItem icon={<ShieldCheck />} label="Trust and reseller rules" />
        <SettingsItem icon={<Headphones />} label="Support and report issue" />
      </div>
    </ResellerShell>
  );
}

function SettingsItem({ icon, label }: { icon: ReactElement; label: string }) {
  return (
    <Card className="p-4">
      <div className="flex items-center gap-3">
        <span className="grid h-10 w-10 place-items-center rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] text-[var(--color-primary)]">
          {icon}
        </span>
        <p className="font-bold">{label}</p>
      </div>
    </Card>
  );
}

export function ResellerSupportScreen() {
  return (
    <ResellerShell active={navByRoute.account} title="Support">
      <header>
        <h1 className="text-2xl font-bold">Support</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">Get help with orders, delivery, settlement, or withdrawals.</p>
      </header>
      <div className="mt-5 grid gap-3">
        {["Report an order issue", "Ask about commission", "Withdrawal help", "Product sharing support"].map((item) => (
          <Card className="p-4" key={item}>
            <div className="flex items-center gap-3">
              <Headphones className="h-5 w-5 text-[var(--color-primary)]" aria-hidden="true" />
              <p className="font-bold">{item}</p>
            </div>
          </Card>
        ))}
      </div>
    </ResellerShell>
  );
}

function LabeledInput({ label, value }: { label: string; value: string }) {
  return (
    <label className="block">
      <span className="mb-2 block text-sm font-semibold">{label}</span>
      <Input defaultValue={value} />
    </label>
  );
}

function InfoRow({ badge, label, value }: { badge?: string; label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="flex max-w-[58%] flex-wrap justify-end gap-2 text-right font-bold">
        {value}
        {badge ? <StatusBadge status={badge} /> : null}
      </span>
    </div>
  );
}

function EmptyPanel({ action, description, title }: { action: string; description: string; title: string }) {
  return (
    <Card className="mt-5 text-center">
      <Package className="mx-auto h-14 w-14 text-[var(--color-primary)]" aria-hidden="true" />
      <h2 className="mt-4 text-xl font-bold">{title}</h2>
      <p className="mt-2 text-sm text-[var(--color-muted)]">{description}</p>
      <Button className="mt-4 w-full">{action}</Button>
    </Card>
  );
}

export { resellerProfile };
