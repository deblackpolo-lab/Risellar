"use client";

import Link from "next/link";
import { AlertCircle, Filter, Search, Store } from "lucide-react";
import { useMemo, useState } from "react";
import { AccountSignOutButton } from "@/components/auth/AccountSignOutButton";
import { BottomNav, MobileShell } from "@/components/layout";
import { ProductBrowseGrid, ProductGridCard, ProductImageGallery } from "@/components/marketplace";
import { Button, Card, Input, ScrollableChipRow, StatusBadge } from "@/components/ui";
import type { ResellerCatalogError, ResellerCatalogProduct } from "@/lib/reseller/catalog";
import { cn } from "@/lib/utils/cn";

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
          Review active supplier products with reseller-safe pricing and stock signals. Adding products to a shop is still planned.
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

export function ResellerCatalogDetailRpcScreen({ product }: { product: ResellerCatalogProduct }) {
  return (
    <ResellerCatalogShell title="Product detail">
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
            <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-[#8A5A00]">
              Add to shop planned. This page does not create listings, reserve stock, or start checkout.
            </p>
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-3">
          <Button disabled>Add to shop planned</Button>
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
