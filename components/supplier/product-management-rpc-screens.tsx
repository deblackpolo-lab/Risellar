"use client";

import Link from "next/link";
import { useActionState, useMemo, useState, type ReactNode } from "react";
import { ArrowLeft, Archive, Box, Edit3, Image, PackagePlus, Search } from "lucide-react";
import {
  archiveSupplierProductAction,
  createSupplierProductAction,
  updateSupplierProductAction
} from "@/app/supplier/products/actions";
import { Button, Card, Input, StatusBadge, Textarea } from "@/components/ui";
import {
  initialSupplierProductActionState,
  type SupplierProductActionState,
  type SupplierProductListItem
} from "@/lib/supplier/product-management";
import { cn } from "@/lib/utils/cn";

function formatMoney(amount: number, currencyCode: string) {
  return `${currencyCode} ${amount.toLocaleString("en-GH", { maximumFractionDigits: 2, minimumFractionDigits: 2 })}`;
}

function formatDate(value: string) {
  if (!value) {
    return "Not available";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function ActionMessage({ state }: { state: SupplierProductActionState }) {
  if (!state.message) {
    return null;
  }

  const isSuccess = state.code === "OK";

  return (
    <p
      role="status"
      className={
        isSuccess
          ? "rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] px-4 py-3 text-sm font-semibold text-[var(--color-success)]"
          : "rounded-[var(--radius-md)] border border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)] px-4 py-3 text-sm font-semibold text-[var(--color-danger)]"
      }
    >
      {state.message} {state.code !== "OK" ? `(${state.code})` : null}
    </p>
  );
}

function SupplierProductsShell({ children, eyebrow, title }: { children: ReactNode; eyebrow: string; title: string }) {
  return (
    <main className="min-h-screen bg-[var(--color-background)] pb-24">
      <section className="border-b border-[var(--color-border)] bg-white px-4 py-5">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-primary)]">{eyebrow}</p>
            <h1 className="text-2xl font-bold text-[var(--color-charcoal)]">{title}</h1>
          </div>
          <LinkButton className="hidden sm:inline-flex" href="/supplier/products/new">
            Add Product
          </LinkButton>
        </div>
      </section>
      <section className="mx-auto max-w-6xl px-4 py-5">{children}</section>
    </main>
  );
}

export function SupplierProductsRpcScreen({
  products,
  error
}: {
  products: SupplierProductListItem[];
  error: SupplierProductActionState | null;
}) {
  const [query, setQuery] = useState("");
  const filteredProducts = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    if (!normalizedQuery) {
      return products;
    }

    return products.filter((product) =>
      [product.name, product.category, product.brand, product.approvalStatus, product.productStatus]
        .filter(Boolean)
        .some((value) => value?.toLowerCase().includes(normalizedQuery))
    );
  }, [products, query]);

  return (
    <SupplierProductsShell eyebrow="Supplier workspace" title="Products">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <label className="relative block w-full sm:max-w-md">
          <Search className="pointer-events-none absolute left-3 top-3 h-4 w-4 text-[var(--color-muted)]" aria-hidden="true" />
          <span className="sr-only">Search supplier products</span>
          <Input
            aria-label="Search supplier products"
            className="pl-10"
            placeholder="Search products"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
        <LinkButton href="/supplier/products/new">
          <PackagePlus className="h-4 w-4" aria-hidden="true" />
          Add Product
        </LinkButton>
      </div>

      {error ? <ActionMessage state={error} /> : null}

      {filteredProducts.length === 0 ? (
        <Card className="mt-4 text-center">
          <Box className="mx-auto h-10 w-10 text-[var(--color-muted)]" aria-hidden="true" />
          <h2 className="mt-3 text-lg font-bold text-[var(--color-charcoal)]">No supplier products yet</h2>
          <p className="mt-2 text-sm text-[var(--color-muted)]">Create a product for admin review. Products remain pending until approval.</p>
          <LinkButton className="mt-4" href="/supplier/products/new">
            Add Product
          </LinkButton>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {filteredProducts.map((product) => (
            <ProductCard key={product.productId} product={product} />
          ))}
        </div>
      )}
    </SupplierProductsShell>
  );
}

function ProductCard({ product }: { product: SupplierProductListItem }) {
  return (
    <Card className="flex h-full flex-col gap-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-bold text-[var(--color-charcoal)]">{product.name}</h2>
          <p className="text-sm text-[var(--color-muted)]">{product.category ?? "Uncategorized"}</p>
        </div>
        <StatusBadge status={product.approvalStatus.replaceAll("_", " ")} />
      </div>
      <p className="line-clamp-3 text-sm text-[var(--color-muted)]">{product.description ?? "No description provided."}</p>
      <div className="grid grid-cols-2 gap-3 text-sm">
        <div>
          <p className="text-xs font-semibold uppercase text-[var(--color-muted)]">Base price</p>
          <p className="font-bold text-[var(--color-charcoal)]">{formatMoney(product.basePriceAmount, product.currencyCode)}</p>
        </div>
        <div>
          <p className="text-xs font-semibold uppercase text-[var(--color-muted)]">Images</p>
          <p className="font-bold text-[var(--color-charcoal)]">{product.imageCount}</p>
        </div>
      </div>
      <div className="mt-auto flex gap-2">
        <LinkButton className="flex-1" href={`/supplier/products/${product.productId}`} variant="outline">
          View
        </LinkButton>
        <LinkButton className="flex-1" href={`/supplier/products/${product.productId}/edit`} variant="ghost">
          Edit
        </LinkButton>
      </div>
    </Card>
  );
}

export function SupplierProductCreateRpcScreen() {
  const [state, action, pending] = useActionState(createSupplierProductAction, initialSupplierProductActionState);

  return (
    <SupplierProductsShell eyebrow="Product setup" title="Add product">
      <BackLink />
      <ProductForm action={action} pending={pending} state={state} submitLabel="Save Product" />
    </SupplierProductsShell>
  );
}

export function SupplierProductEditRpcScreen({ product }: { product: SupplierProductListItem }) {
  const [state, action, pending] = useActionState(updateSupplierProductAction, initialSupplierProductActionState);

  return (
    <SupplierProductsShell eyebrow="Product setup" title="Edit product">
      <BackLink href={`/supplier/products/${product.productId}`} />
      <ProductForm action={action} pending={pending} product={product} state={state} submitLabel="Save Changes" />
    </SupplierProductsShell>
  );
}

function ProductForm({
  action,
  pending,
  product,
  state,
  submitLabel
}: {
  action: (payload: FormData) => void;
  pending: boolean;
  product?: SupplierProductListItem;
  state: SupplierProductActionState;
  submitLabel: string;
}) {
  return (
    <form action={action} className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
      {product ? <input name="product_id" type="hidden" value={product.productId} /> : null}
      <Card title="Product details">
        <div className="grid gap-4">
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Product name
            <Input name="product_name" required defaultValue={product?.name ?? ""} />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Category
            <Input name="category" defaultValue={product?.category ?? ""} placeholder="Skincare, electronics, fashion" />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Description
            <Textarea name="description" defaultValue={product?.description ?? ""} placeholder="Describe the product clearly for admin review." />
          </label>
          {product ? (
            <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
              Brand
              <Input name="brand" defaultValue={product.brand ?? ""} />
            </label>
          ) : null}
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
              Base price
              <Input min="0.01" name="base_price" required step="0.01" type="number" defaultValue={product?.basePriceAmount ?? ""} />
            </label>
            {!product ? (
              <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
                Stock quantity
                <Input min="0" name="stock_quantity" required step="1" type="number" defaultValue="0" />
              </label>
            ) : null}
          </div>
          <ActionMessage state={state} />
          <Button loading={pending} type="submit">
            {submitLabel}
          </Button>
        </div>
      </Card>
      <Card title="Admin-controlled fields">
        <div className="space-y-3 text-sm text-[var(--color-muted)]">
          <p>Products are submitted for review. Approval status, live status, platform margin, and reseller pricing remain controlled outside supplier forms.</p>
          <p>Image upload is not connected yet. Product image metadata can be added later after storage UI QA.</p>
          {product ? (
            <div className="flex flex-wrap gap-2 pt-2">
              <StatusBadge status={product.productStatus.replaceAll("_", " ")} />
              <StatusBadge status={product.approvalStatus.replaceAll("_", " ")} />
            </div>
          ) : null}
        </div>
      </Card>
    </form>
  );
}

export function SupplierProductDetailRpcScreen({ product }: { product: SupplierProductListItem }) {
  const [state, action, pending] = useActionState(archiveSupplierProductAction, initialSupplierProductActionState);

  return (
    <SupplierProductsShell eyebrow="Product detail" title={product.name}>
      <BackLink />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
        <Card>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm font-semibold text-[var(--color-primary)]">{product.category ?? "Uncategorized"}</p>
              <h2 className="mt-1 text-xl font-bold text-[var(--color-charcoal)]">{product.name}</h2>
              <p className="mt-3 text-sm text-[var(--color-muted)]">{product.description ?? "No description provided."}</p>
            </div>
            <Image className="h-8 w-8 text-[var(--color-muted)]" aria-hidden="true" />
          </div>
          <div className="mt-5 grid gap-3 sm:grid-cols-3">
            <SummaryItem label="Base price" value={formatMoney(product.basePriceAmount, product.currencyCode)} />
            <SummaryItem label="Images" value={String(product.imageCount)} />
            <SummaryItem label="Updated" value={formatDate(product.updatedAt)} />
          </div>
          <div className="mt-5 flex flex-wrap gap-2">
            <StatusBadge status={product.productStatus.replaceAll("_", " ")} />
            <StatusBadge status={product.approvalStatus.replaceAll("_", " ")} />
          </div>
        </Card>
        <Card title="Actions">
          <div className="grid gap-3">
            <LinkButton href={`/supplier/products/${product.productId}/edit`} variant="outline">
              <Edit3 className="h-4 w-4" aria-hidden="true" />
              Edit safe fields
            </LinkButton>
            <form action={action} className="grid gap-3">
              <input name="product_id" type="hidden" value={product.productId} />
              <Textarea name="reason" placeholder="Archive reason, optional" />
              <Button loading={pending} type="submit" variant="danger">
                <Archive className="h-4 w-4" aria-hidden="true" />
                Archive product
              </Button>
            </form>
            <ActionMessage state={state} />
          </div>
        </Card>
      </div>
    </SupplierProductsShell>
  );
}

export function SupplierProductNotFoundRpcScreen({ error }: { error?: SupplierProductActionState | null }) {
  return (
    <SupplierProductsShell eyebrow="Product detail" title="Product not found">
      <BackLink />
      {error ? <ActionMessage state={error} /> : null}
      <Card>
        <p className="text-sm text-[var(--color-muted)]">This product is not available for the current supplier account.</p>
      </Card>
    </SupplierProductsShell>
  );
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
      <p className="text-xs font-semibold uppercase text-[var(--color-muted)]">{label}</p>
      <p className="mt-1 font-bold text-[var(--color-charcoal)]">{value}</p>
    </div>
  );
}

function BackLink({ href = "/supplier/products" }: { href?: string }) {
  return (
    <Link className="mb-4 inline-flex items-center gap-2 text-sm font-semibold text-[var(--color-primary)]" href={href}>
      <ArrowLeft className="h-4 w-4" aria-hidden="true" />
      Back
    </Link>
  );
}

function LinkButton({
  children,
  className,
  href,
  variant = "primary"
}: {
  children: ReactNode;
  className?: string;
  href: string;
  variant?: "primary" | "outline" | "ghost";
}) {
  return (
    <Link
      className={cn(
        "inline-flex h-9 items-center justify-center gap-2 whitespace-nowrap rounded-[var(--radius-md)] px-4 text-sm font-semibold transition-[var(--transition-fast)]",
        variant === "primary"
          ? "bg-[var(--color-primary)] text-white shadow-[var(--shadow-sm)] hover:bg-[var(--color-primary-hover)]"
          : null,
        variant === "outline"
          ? "border border-[var(--color-primary)] bg-white text-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)]"
          : null,
        variant === "ghost" ? "bg-transparent text-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)]" : null,
        className
      )}
      href={href}
    >
      {children}
    </Link>
  );
}
