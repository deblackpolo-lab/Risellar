"use client";

import Link from "next/link";
import { Search, ShieldCheck, ShoppingBag } from "lucide-react";
import { useMemo, useState } from "react";
import { MobileShell } from "@/components/layout";
import { ProductBrowseGrid, ProductGridCard, ProductImageGallery } from "@/components/marketplace";
import { Button, Card, Input, ScrollableChipRow, StatusBadge } from "@/components/ui";
import type { PublicShopError, PublicShopProduct, PublicShopSummary } from "@/lib/public-shop/catalog";

function formatGhc(value: number | null) {
  if (value === null) {
    return "Price pending";
  }

  return `GH₵${value.toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function productImages(product: PublicShopProduct) {
  if (product.imageCount <= 0) {
    return undefined;
  }

  return [
    {
      id: `${product.listingId}-public-image-summary`,
      alt: product.primaryImageAlt ?? `${product.name} product image`,
      label: "IMG",
      tone: "home" as const,
      detail: `${product.imageCount} image${product.imageCount === 1 ? "" : "s"}`
    }
  ];
}

function shopProductHref(shopSlug: string, product: PublicShopProduct) {
  return `/shop/${shopSlug}/product/${product.shareSlug || product.productSlug}`;
}

export function PublicShopRpcScreen({
  error,
  products,
  shop
}: {
  error: PublicShopError | null;
  products: PublicShopProduct[];
  shop: PublicShopSummary | null;
}) {
  const [query, setQuery] = useState("");
  const filteredProducts = useMemo(() => {
    const normalized = query.trim().toLowerCase();

    if (!normalized) {
      return products;
    }

    return products.filter((product) => (
      `${product.name} ${product.category ?? ""} ${product.brand ?? ""}`.toLowerCase().includes(normalized)
    ));
  }, [products, query]);
  const categories = useMemo(() => [...new Set(products.map((product) => product.category).filter(Boolean))], [products]);

  return (
    <MobileShell>
      <section className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)]">
        <div className="grid h-16 w-16 place-items-center rounded-2xl bg-[var(--color-primary)] text-lg font-black text-white">
          {(shop?.displayName ?? "RS").slice(0, 2).toUpperCase()}
        </div>
        <h1 className="mt-4 text-2xl font-bold text-[var(--color-charcoal)]">{shop?.displayName ?? "Shop unavailable"}</h1>
        <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
          {shop?.bio ?? "Browse active approved reseller listings. Checkout is not connected yet."}
        </p>
      </section>

      {error ? (
        <Card className="border-[var(--color-danger)]/30 bg-red-50 p-4">
          <h2 className="text-sm font-bold text-[var(--color-danger)]">{error.code}</h2>
          <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">{error.message}</p>
        </Card>
      ) : null}

      <label className="relative mt-4 block">
        <span className="sr-only">Search shop products</span>
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-muted)]" aria-hidden />
        <Input
          aria-label="Search shop products"
          className="pl-10"
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search products..."
          type="search"
          value={query}
        />
      </label>

      <ScrollableChipRow className="mt-3">
        <button className="h-9 flex-none whitespace-nowrap rounded-full border border-[var(--color-primary)] bg-[var(--color-primary)] px-4 text-sm font-semibold text-white" type="button">
          All
        </button>
        {categories.map((category) => (
          <span className="h-9 flex-none whitespace-nowrap rounded-full border border-[var(--color-border)] bg-white px-4 py-2 text-sm font-semibold text-[var(--color-charcoal)]" key={category}>
            {category}
          </span>
        ))}
      </ScrollableChipRow>

      <Card className="bg-[var(--color-accent-soft)] p-4">
        <div className="flex items-center gap-3">
          <ShieldCheck className="h-5 w-5 text-[var(--color-primary)]" aria-hidden />
          <div>
            <p className="text-base font-bold text-[var(--color-charcoal)]">Read-only preview</p>
            <p className="text-sm leading-5 text-[var(--color-muted)]">Checkout, order creation, stock reservation, and payment are not connected yet.</p>
          </div>
        </div>
      </Card>

      <section className="grid gap-3">
        <div className="flex items-center justify-between">
          <h2 className="text-[18px] font-semibold leading-6 text-[var(--color-charcoal)]">Active products</h2>
          <span className="text-sm font-semibold text-[var(--color-primary)]">{filteredProducts.length} shown</span>
        </div>
        {filteredProducts.length > 0 && shop ? (
          <ProductBrowseGrid ariaLabel="Public reseller shop products">
            {filteredProducts.map((product) => (
              <ProductGridCard
                badges={[product.stockAvailabilityLabel]}
                category={product.category ?? "Uncategorized"}
                href={shopProductHref(shop.slug, product)}
                imageAlt={product.primaryImageAlt ?? `${product.name} product image`}
                images={productImages(product)}
                key={product.listingId}
                name={product.name}
                price={formatGhc(product.finalCustomerPriceAmount)}
                priceLabel="Final customer price"
                stockStatus={product.stockAvailabilityLabel}
              />
            ))}
          </ProductBrowseGrid>
        ) : (
          <Card className="p-5 text-center">
            <ShoppingBag className="mx-auto h-12 w-12 text-[var(--color-muted)]" aria-hidden />
            <h3 className="mt-3 text-base font-bold">No active products yet</h3>
            <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
              Active approved reseller listings will appear here when available.
            </p>
          </Card>
        )}
      </section>
    </MobileShell>
  );
}

export function PublicShopProductRpcScreen({
  error,
  product,
  shop
}: {
  error: PublicShopError | null;
  product: PublicShopProduct | null;
  shop: PublicShopSummary | null;
}) {
  return (
    <MobileShell>
      {product && shop ? (
        <>
          <section className="grid gap-4">
            <ProductImageGallery productName={product.name} images={productImages(product)} imageAlt={product.primaryImageAlt ?? `${product.name} product image`} />
            <div className="space-y-2">
              <StatusBadge tone={product.stockAvailabilityLabel.includes("Low") ? "warning" : "success"}>{product.stockAvailabilityLabel}</StatusBadge>
              <h1 className="text-[23px] font-bold leading-[1.2] text-[var(--color-charcoal)]">{product.name}</h1>
              <p className="text-sm font-semibold text-[var(--color-muted)]">Sold by {shop.displayName}</p>
              <p className="text-2xl font-extrabold text-[var(--color-primary)]">{formatGhc(product.finalCustomerPriceAmount)}</p>
              {product.description ? <p className="text-sm leading-6 text-[var(--color-muted)]">{product.description}</p> : null}
            </div>
          </section>

          <Card title="Product details">
            <div className="space-y-3 text-sm">
              <InfoRow label="Category" value={product.category ?? "Uncategorized"} />
              <InfoRow label="Brand" value={product.brand ?? "Not specified"} />
              <InfoRow label="Currency" value={product.currencyCode} />
            </div>
          </Card>

          <Card className="bg-[var(--color-warning-soft)] p-4">
            <p className="text-sm font-bold text-[#8A5A00]">Checkout planned</p>
            <p className="mt-1 text-sm leading-6 text-[#8A5A00]">
              This read-only product page does not create orders, reserve stock, collect payments, or start delivery.
            </p>
          </Card>

          <div className="grid grid-cols-2 gap-3">
            <Button className="w-full" disabled variant="outline">Add to cart planned</Button>
            <Button className="w-full" disabled>Buy later</Button>
          </div>

          <Link
            className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-5 text-sm font-semibold text-[var(--color-primary)]"
            href={`/shop/${shop.slug}`}
          >
            Back to shop
          </Link>
        </>
      ) : (
        <Card className="p-5 text-center">
          <ShoppingBag className="mx-auto h-12 w-12 text-[var(--color-muted)]" aria-hidden />
          <h1 className="mt-3 text-xl font-bold">Product unavailable</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
            {error?.message ?? "This product is not active, approved, or listed in this public shop."}
          </p>
        </Card>
      )}
    </MobileShell>
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
