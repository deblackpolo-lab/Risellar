"use client";

import Link from "next/link";
import { AlertCircle, Archive, Filter, Search, Store } from "lucide-react";
import { useMemo, useState } from "react";
import { AccountSignOutButton } from "@/components/auth/AccountSignOutButton";
import { BottomNav, MobileShell } from "@/components/layout";
import { ProductBrowseGrid, ProductGridCard, ProductImageGallery } from "@/components/marketplace";
import { Button, Card, Input, ScrollableChipRow, StatusBadge } from "@/components/ui";
import type { ResellerCatalogError, ResellerCatalogProduct } from "@/lib/reseller/catalog";
import type { ResellerListingError, ResellerShopProduct } from "@/lib/reseller/listings";
import { cn } from "@/lib/utils/cn";

type ListingFormAction = (formData: FormData) => void | Promise<void>;

function formatGhc(value: number | null) {
  if (value === null) {
    return "Pending";
  }

  return `GH₵${value.toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function stockStatus(product: ResellerCatalogProduct) {
  if (product.availableStockQuantity <= 0) {
    return "Out of stock";
  }

  if (product.availableStockQuantity <= 3) {
    return "Low stock";
  }

  return `${product.availableStockQuantity} available`;
}

function listingMessage(status?: string, code?: string) {
  if (status === "created") {
    return { tone: "success" as const, title: "Product added", message: "The product is now listed in My products." };
  }

  if (status === "updated") {
    return { tone: "success" as const, title: "Margin updated", message: "Your reseller margin was updated through the listing RPC." };
  }

  if (status === "archived") {
    return { tone: "success" as const, title: "Listing archived", message: "The listing was soft archived and removed from active My products." };
  }

  if (status === "error") {
    return {
      tone: "danger" as const,
      title: code ?? "Listing action failed",
      message: listingErrorMessage(code)
    };
  }

  return null;
}

function listingErrorMessage(code?: string) {
  switch (code) {
    case "DUPLICATE_LISTING":
      return "This product is already active in your shop. Edit it from My products instead.";
    case "INVALID_MARGIN":
      return "Enter a reseller margin greater than zero and within the product limit.";
    case "RESELLER_REQUIRED":
      return "An approved reseller account is required to manage shop listings.";
    case "SUPABASE_AUTH_TOKEN_MISSING":
      return "We could not prepare your secure Supabase reseller session. Please sign in again.";
    case "RPC_PERMISSION_DENIED":
      return "Your signed-in profile is not allowed to manage this listing.";
    default:
      return "The listing action could not be completed. Try again or contact support.";
  }
}

function ListingNotice({ code, status }: { code?: string; status?: string }) {
  const notice = listingMessage(status, code);

  if (!notice) {
    return null;
  }

  return (
    <Card className={cn("border p-4", notice.tone === "danger" ? "border-[var(--color-danger)]/30 bg-red-50" : "border-[var(--color-success)]/30 bg-emerald-50")}>
      <div className="flex gap-3">
        <AlertCircle className={cn("mt-0.5 h-5 w-5 shrink-0", notice.tone === "danger" ? "text-[var(--color-danger)]" : "text-[var(--color-success)]")} aria-hidden />
        <div>
          <h2 className={cn("text-sm font-bold", notice.tone === "danger" ? "text-[var(--color-danger)]" : "text-[var(--color-success)]")}>{notice.title}</h2>
          <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">{notice.message}</p>
        </div>
      </div>
    </Card>
  );
}

function productImages(product: ResellerCatalogProduct) {
  if (product.imageCount <= 0) {
    return undefined;
  }

  return [
    {
      id: `${product.productId}-image-summary`,
      alt: `${product.name} approved product image metadata`,
      label: "IMG",
      tone: "home" as const,
      detail: `${product.imageCount} image${product.imageCount === 1 ? "" : "s"}`
    }
  ];
}

function ResellerCatalogShell({ children, title = "Product catalog" }: { children: React.ReactNode; title?: string }) {
  return (
    <MobileShell footer={<BottomNav active="Shop" />} title={title}>
      <div className="mb-4 flex justify-end">
        <AccountSignOutButton />
      </div>
      {children}
    </MobileShell>
  );
}

function filterClass(active: boolean) {
  return cn(
    "h-9 flex-none whitespace-nowrap rounded-full border px-4 text-sm font-semibold transition",
    active
      ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
      : "border-[var(--color-border)] bg-white text-[var(--color-muted)]"
  );
}

export function ResellerCatalogRpcScreen({
  error,
  products
}: {
  error: ResellerCatalogError | null;
  products: ResellerCatalogProduct[];
}) {
  const [query, setQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("all");
  const categories = useMemo(() => (
    [...new Set(products.map((product) => product.category).filter(Boolean))]
  ), [products]);
  const filteredProducts = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return products.filter((product) => {
      const matchesCategory = selectedCategory === "all" || product.category === selectedCategory;
      const matchesQuery = !normalizedQuery || [product.name, product.category, product.brand, product.supplierDisplayName]
        .filter(Boolean)
        .some((value) => value?.toLowerCase().includes(normalizedQuery));

      return matchesCategory && matchesQuery;
    });
  }, [products, query, selectedCategory]);

  return (
    <ResellerCatalogShell>
      <header>
        <h1 className="text-2xl font-bold">Browse approved products</h1>
        <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
          Review active supplier products with reseller-safe pricing and add approved products to your shop.
        </p>
      </header>

      {error ? (
        <Card className="mt-5 border-[var(--color-danger)]/30 bg-red-50 p-4">
          <div className="flex gap-3">
            <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-[var(--color-danger)]" aria-hidden />
            <div>
              <h2 className="text-sm font-bold text-[var(--color-danger)]">{error.code}</h2>
              <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">{error.message}</p>
            </div>
          </div>
        </Card>
      ) : null}

      <label className="relative mt-5 block">
        <span className="sr-only">Search approved products</span>
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-muted)]" aria-hidden="true" />
        <Input
          aria-label="Search approved products"
          className="pl-10"
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search products, categories, suppliers..."
          type="search"
          value={query}
        />
      </label>

      <ScrollableChipRow className="mt-4">
        <Filter className="mt-2 h-4 w-4 shrink-0 text-[var(--color-muted)]" aria-hidden="true" />
        <button className={filterClass(selectedCategory === "all")} onClick={() => setSelectedCategory("all")} type="button">
          All
        </button>
        {categories.map((category) => (
          <button
            className={filterClass(selectedCategory === category)}
            key={category}
            onClick={() => setSelectedCategory(category ?? "all")}
            type="button"
          >
            {category}
          </button>
        ))}
      </ScrollableChipRow>

      <section className="mt-6">
        <div className="mb-3 flex items-center justify-between gap-3">
          <h2 className="text-lg font-bold">Approved supplier products</h2>
          <StatusBadge status={`${filteredProducts.length} products`} tone="neutral" />
        </div>
        {filteredProducts.length > 0 ? (
          <ProductBrowseGrid ariaLabel="Approved reseller catalog products">
            {filteredProducts.map((product) => (
              <ProductGridCard
                badges={[product.approvalStatus, product.productStatus]}
                category={product.category ?? "Uncategorized"}
                href={`/reseller/products/${product.productId}`}
                imageAlt={`${product.name} product preview`}
                images={productImages(product)}
                key={product.productId}
                name={product.name}
                price={formatGhc(product.maxCustomerPriceAmount)}
                priceLabel="Max customer price"
                resellerCost={formatGhc(product.resellerCostAmount)}
                stockStatus={stockStatus(product)}
              />
            ))}
          </ProductBrowseGrid>
        ) : (
          <Card className="p-5 text-center">
            <Store className="mx-auto h-10 w-10 text-[var(--color-muted)]" aria-hidden />
            <h3 className="mt-3 text-base font-bold">No approved products yet</h3>
            <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
              Approved active supplier products will appear here after admin product review.
            </p>
          </Card>
        )}
      </section>
    </ResellerCatalogShell>
  );
}

export function ResellerCatalogDetailRpcScreen({
  action,
  listingCode,
  listingStatus,
  product
}: {
  action: ListingFormAction;
  listingCode?: string;
  listingStatus?: string;
  product: ResellerCatalogProduct;
}) {
  const canAddToShop = product.approvalStatus === "approved" && product.productStatus === "active" && product.availableStockQuantity > 0;

  return (
    <ResellerCatalogShell title="Product detail">
      <ListingNotice code={listingCode} status={listingStatus} />

      <Card className="p-4">
        <ProductImageGallery productName={product.name} images={productImages(product)} imageAlt={`${product.name} product preview`} />
        <div className="mt-4 flex flex-wrap gap-2">
          <StatusBadge status={product.approvalStatus} />
          <StatusBadge status={product.productStatus} />
          <StatusBadge status={stockStatus(product)} />
        </div>
        <p className="mt-3 text-xs font-bold uppercase text-[var(--color-muted)]">{product.category ?? "Uncategorized"}</p>
        <h1 className="mt-1 text-2xl font-bold leading-tight">{product.name}</h1>
        {product.supplierDisplayName ? <p className="mt-1 text-sm text-[var(--color-muted)]">{product.supplierDisplayName}</p> : null}
        {product.description ? <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">{product.description}</p> : null}
      </Card>

      <section className="mt-4 grid gap-4">
        <Card title="Reseller pricing">
          <div className="space-y-3 text-sm">
            <InfoRow label="Reseller cost" value={formatGhc(product.resellerCostAmount)} />
            <InfoRow label="Max customer price" value={formatGhc(product.maxCustomerPriceAmount)} />
            <InfoRow label="Currency" value={product.currencyCode} />
          </div>
        </Card>

        <Card title="Stock and status">
          <div className="space-y-3 text-sm">
            <InfoRow label="Available stock" value={`${product.availableStockQuantity}`} />
            <InfoRow label="Product status" value={product.productStatus} />
            <InfoRow label="Approval status" value={product.approvalStatus} />
            {!canAddToShop ? (
              <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-[#8A5A00]">
                Add to shop is available only for approved active products with stock.
              </p>
            ) : null}
          </div>
        </Card>

        <Card title="Add to shop">
          <form action={action} className="space-y-3">
            <input name="product_id" type="hidden" value={product.productId} />
            <label className="block text-sm font-semibold" htmlFor="reseller-margin">
              Reseller margin
            </label>
            <Input
              aria-label="Reseller margin"
              disabled={!canAddToShop}
              id="reseller-margin"
              min="0.01"
              name="reseller_margin"
              placeholder="Example: 25.00"
              required
              step="0.01"
              type="number"
            />
            <p className="text-xs leading-5 text-[var(--color-muted)]">
              Margin must be greater than zero and within the product limit.
            </p>
            <div className="rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-sm">
              <InfoRow label="Your cost" value={formatGhc(product.resellerCostAmount)} />
              <InfoRow label="Max customer price" value={formatGhc(product.maxCustomerPriceAmount)} />
              <p className="mt-3 text-xs leading-5 text-[var(--color-muted)]">
                Only your reseller margin is submitted. Final customer price is calculated by the backend RPC.
              </p>
            </div>
            <Button className="w-full" disabled={!canAddToShop} type="submit">
              Add to My Shop
            </Button>
          </form>
        </Card>

        <div className="grid grid-cols-2 gap-3">
          <Link
            className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-5 text-sm font-semibold text-[var(--color-primary)]"
            href="/reseller/my-products"
          >
            My products
          </Link>
          <Link
            className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-5 text-sm font-semibold text-[var(--color-primary)]"
            href="/reseller/products"
          >
            Back to catalog
          </Link>
        </div>
      </section>
    </ResellerCatalogShell>
  );
}

export function ResellerMyProductsRpcScreen({
  archiveAction,
  error,
  listings,
  listingCode,
  listingStatus,
  updateAction
}: {
  archiveAction: ListingFormAction;
  error: ResellerListingError | null;
  listings: ResellerShopProduct[];
  listingCode?: string;
  listingStatus?: string;
  updateAction: ListingFormAction;
}) {
  return (
    <ResellerCatalogShell title="My products">
      <header>
        <h1 className="text-2xl font-bold">My products</h1>
        <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
          Manage products listed in your reseller shop. This screen does not create orders, reserve stock, or connect checkout.
        </p>
      </header>

      <div className="mt-5 space-y-3">
        <ListingNotice code={listingCode} status={listingStatus} />
        {error ? (
          <Card className="border-[var(--color-danger)]/30 bg-red-50 p-4">
            <div className="flex gap-3">
              <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-[var(--color-danger)]" aria-hidden />
              <div>
                <h2 className="text-sm font-bold text-[var(--color-danger)]">{error.code}</h2>
                <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">{error.message}</p>
              </div>
            </div>
          </Card>
        ) : null}
      </div>

      <section className="mt-6">
        <div className="mb-3 flex items-center justify-between gap-3">
          <h2 className="text-lg font-bold">Live shop listings</h2>
          <StatusBadge status={`${listings.length} listings`} tone="neutral" />
        </div>

        {listings.length > 0 ? (
          <div className="grid gap-4">
            {listings.map((listing) => (
              <Card className="p-4" key={listing.listingId}>
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{listing.category ?? "Uncategorized"}</p>
                    <h3 className="mt-1 text-lg font-bold">{listing.name}</h3>
                    {listing.supplierDisplayName ? <p className="mt-1 text-sm text-[var(--color-muted)]">{listing.supplierDisplayName}</p> : null}
                  </div>
                  <StatusBadge status={listing.listingStatus} />
                </div>

                <div className="mt-4 grid gap-2 text-sm">
                  <InfoRow label="Your cost" value={formatGhc(listing.resellerCostAmount)} />
                  <InfoRow label="Your margin" value={formatGhc(listing.resellerMarginAmount)} />
                  <InfoRow label="Customer price" value={formatGhc(listing.customerProductPriceAmount)} />
                  <InfoRow label="Stock signal" value={`${listing.availableStockQuantity} available`} />
                </div>

                <form action={updateAction} className="mt-4 grid gap-3">
                  <input name="listing_id" type="hidden" value={listing.listingId} />
                  <label className="block text-sm font-semibold" htmlFor={`margin-${listing.listingId}`}>
                    Update margin
                  </label>
                  <Input
                    aria-label={`Update margin for ${listing.name}`}
                    defaultValue={listing.resellerMarginAmount ?? undefined}
                    id={`margin-${listing.listingId}`}
                    min="0.01"
                    name="reseller_margin"
                    step="0.01"
                    type="number"
                  />
                  <Button type="submit" variant="outline">
                    Save margin
                  </Button>
                </form>

                <form action={archiveAction} className="mt-3">
                  <input name="listing_id" type="hidden" value={listing.listingId} />
                  <Button className="w-full" type="submit" variant="soft-warning">
                    <Archive className="h-4 w-4" aria-hidden />
                    Archive listing
                  </Button>
                </form>
              </Card>
            ))}
          </div>
        ) : (
          <Card className="p-5 text-center">
            <Store className="mx-auto h-10 w-10 text-[var(--color-muted)]" aria-hidden />
            <h3 className="mt-3 text-base font-bold">No shop listings yet</h3>
            <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
              Add approved active products from the reseller catalog. Customer shop and checkout remain deferred.
            </p>
            <Link
              className="mt-4 inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-semibold text-white"
              href="/reseller/products"
            >
              Browse products
            </Link>
          </Card>
        )}
      </section>
    </ResellerCatalogShell>
  );
}

export function ResellerCatalogNotFoundRpcScreen({ error }: { error: ResellerCatalogError | null }) {
  return (
    <ResellerCatalogShell title="Product detail">
      <Card className="p-5 text-center">
        <AlertCircle className="mx-auto h-10 w-10 text-[var(--color-muted)]" aria-hidden />
        <h1 className="mt-3 text-xl font-bold">Product unavailable</h1>
        <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
          {error?.message ?? "This product is not approved, active, or available to this reseller account."}
        </p>
        <Link
          className="mt-4 inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-semibold text-white"
          href="/reseller/products"
        >
          Back to catalog
        </Link>
      </Card>
    </ResellerCatalogShell>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-b-0 last:pb-0">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="text-right font-bold">{value}</span>
    </div>
  );
}
