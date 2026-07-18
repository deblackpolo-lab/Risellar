import Link from "next/link";
import { CheckCircle2, Clock3, ImageIcon, PackageCheck, ShieldCheck, XCircle } from "lucide-react";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";
import type { AdminProductReviewActionCode } from "@/lib/admin/product-approval";
import { reviewSupplierProductAction } from "@/app/admin/products/actions";

export type AdminProductApprovalListItem = {
  productId: string;
  supplierId: string;
  supplierName: string | null;
  supplierBusinessName: string | null;
  category: string | null;
  name: string;
  description: string | null;
  productStatus: string;
  approvalStatus: string;
  basePriceAmount: number;
  currencyCode: string;
  createdAt: string;
  updatedAt: string;
  approvedAt: string | null;
  rejectionReason: string | null;
  stockQuantity: number;
  imageCount: number;
  primaryImagePath: string | null;
};

const errorMessages: Record<AdminProductReviewActionCode, string> = {
  AUTH_REQUIRED: "Sign in with an admin account before reviewing products.",
  ADMIN_REQUIRED: "Only admin users can review supplier products.",
  INVALID_REVIEW_DECISION: "Product review decisions must be approved or rejected.",
  INVALID_PRODUCT_REVIEW: "Choose a pending supplier product before reviewing.",
  RPC_PERMISSION_DENIED: "Your signed-in session is not allowed to review supplier products.",
  SUPABASE_AUTH_TOKEN_MISSING: "We could not prepare your secure Supabase admin session. Please sign in again.",
  UNKNOWN: "Product review failed. Please try again.",
  OK: ""
};

function formatDate(value: string | null) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function formatMoney(amount: number, currencyCode: string) {
  return `${currencyCode} ${amount.toFixed(2)}`;
}

function ProductImagePlaceholder({ product }: { product: AdminProductApprovalListItem }) {
  return (
    <div className="grid h-16 w-16 shrink-0 place-items-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] text-[var(--color-muted)]">
      <ImageIcon className="h-6 w-6" aria-hidden />
      <span className="sr-only">{product.primaryImagePath ? "Product image metadata exists" : "No product image metadata"}</span>
    </div>
  );
}

function ReviewActions({ product }: { product: AdminProductApprovalListItem }) {
  const pending = product.approvalStatus === "pending_review";

  if (!pending) {
    return (
      <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] p-3 text-sm font-semibold text-[var(--color-muted)]">
        Reviewed products are locked from this action panel.
      </div>
    );
  }

  return (
    <form action={reviewSupplierProductAction} className="grid gap-3">
      <input name="product_id" type="hidden" value={product.productId} />
      <label className="text-sm font-bold" htmlFor={`review-notes-${product.productId}`}>
        Review notes
      </label>
      <input
        className="min-h-11 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm"
        id={`review-notes-${product.productId}`}
        name="review_notes"
        placeholder="Optional audit note"
        type="text"
      />
      <div className="flex flex-wrap gap-2">
        <Button name="decision" size="compact" type="submit" value="approved">
          <CheckCircle2 className="h-4 w-4" aria-hidden />
          Approve
        </Button>
        <Button name="decision" size="compact" type="submit" value="rejected" variant="outline">
          <XCircle className="h-4 w-4" aria-hidden />
          Reject
        </Button>
      </div>
    </form>
  );
}

export function AdminProductApprovalAccessDenied() {
  return (
    <AdminShell searchPlaceholder="Search product approval queues...">
      <Card title="Admin access required">
        <div className="flex gap-3 text-sm leading-6 text-[var(--color-muted)]">
          <ShieldCheck className="mt-1 h-5 w-5 shrink-0 text-[var(--color-warning)]" aria-hidden />
          <p>Only active admin staff can review supplier products. Suppliers cannot approve their own products.</p>
        </div>
      </Card>
    </AdminShell>
  );
}

export function AdminProductApprovalListScreen({
  products,
  error,
  status
}: {
  products: AdminProductApprovalListItem[];
  error?: AdminProductReviewActionCode;
  status?: "approved" | "rejected";
}) {
  const pendingCount = products.filter((product) => product.approvalStatus === "pending_review").length;
  const actionMessage = status
    ? `Product ${status}. The audited product review RPC completed without direct client table mutation.`
    : error
      ? errorMessages[error] ?? errorMessages.UNKNOWN
      : null;

  return (
    <AdminShell searchPlaceholder="Search product approvals...">
      <section className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[0_14px_36px_rgba(18,28,28,0.05)]">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Catalog governance</p>
            <h1 className="mt-2 text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">
              Product approval queue
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
              Review supplier-created products through the audited admin RPC. Approved products are not connected to customer or reseller catalogs yet.
            </p>
          </div>
          <StatusBadge status={`${pendingCount} Pending`} tone={pendingCount > 0 ? "warning" : "success"} />
        </div>
      </section>

      {actionMessage ? (
        <div className="rounded-[var(--radius-md)] border border-[var(--color-primary-soft)] bg-[var(--color-primary-subtle)] p-4 text-sm font-semibold text-[var(--color-primary)]">
          {actionMessage}
        </div>
      ) : null}

      {products.length === 0 ? (
        <Card title="No supplier products need review">
          <div className="flex gap-3 text-sm leading-6 text-[var(--color-muted)]">
            <Clock3 className="mt-1 h-5 w-5 shrink-0 text-[var(--color-primary)]" aria-hidden />
            <p>Supplier-created products will appear here after create or price-change submissions.</p>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          {products.map((product) => (
            <Card className="space-y-4" key={product.productId}>
              <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                <div className="flex min-w-0 gap-3">
                  <ProductImagePlaceholder product={product} />
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <StatusBadge status={product.approvalStatus} />
                      <StatusBadge status={product.productStatus} tone="info" />
                    </div>
                    <h2 className="mt-2 text-lg font-extrabold tracking-normal text-[var(--color-charcoal)]">
                      {product.name}
                    </h2>
                    <p className="mt-1 text-sm text-[var(--color-muted)]">
                      {product.supplierBusinessName ?? product.supplierName ?? "Supplier unavailable"} · {product.category ?? "Uncategorized"}
                    </p>
                  </div>
                </div>
                <Link className="text-sm font-bold text-[var(--color-primary)]" href={`/admin/products/${product.productId}`}>
                  View detail
                </Link>
              </div>

              <div className="grid gap-3 md:grid-cols-4">
                {[
                  ["Base price", formatMoney(product.basePriceAmount, product.currencyCode)],
                  ["Stock", String(product.stockQuantity)],
                  ["Images", String(product.imageCount)],
                  ["Updated", formatDate(product.updatedAt)]
                ].map(([label, value]) => (
                  <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={label}>
                    <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{label}</p>
                    <p className="mt-1 break-words text-sm font-semibold text-[var(--color-charcoal)]">{value}</p>
                  </div>
                ))}
              </div>
            </Card>
          ))}
        </div>
      )}
    </AdminShell>
  );
}

export function AdminProductApprovalDetailScreen({
  product,
  error,
  status
}: {
  product: AdminProductApprovalListItem | null;
  error?: AdminProductReviewActionCode;
  status?: "approved" | "rejected";
}) {
  const actionMessage = status
    ? `Product ${status}. The audited product review RPC completed.`
    : error
      ? errorMessages[error] ?? errorMessages.UNKNOWN
      : null;

  if (!product) {
    return (
      <AdminShell searchPlaceholder="Search product approvals...">
        <Card title="Product not found">
          <p className="text-sm leading-6 text-[var(--color-muted)]">The requested supplier product is unavailable to this admin session.</p>
        </Card>
      </AdminShell>
    );
  }

  return (
    <AdminShell searchPlaceholder="Search product approvals...">
      <section className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[0_14px_36px_rgba(18,28,28,0.05)]">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Product detail</p>
            <h1 className="mt-2 text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">{product.name}</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
              Supplier product review uses the audited admin RPC. This page does not expose direct approval status fields.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <StatusBadge status={product.approvalStatus} />
            <StatusBadge status={product.productStatus} tone="info" />
          </div>
        </div>
      </section>

      {actionMessage ? (
        <div className="rounded-[var(--radius-md)] border border-[var(--color-primary-soft)] bg-[var(--color-primary-subtle)] p-4 text-sm font-semibold text-[var(--color-primary)]">
          {actionMessage}
        </div>
      ) : null}

      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="space-y-5">
          <Card title="Product metadata">
            <div className="mb-5 flex items-center gap-4 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] p-3">
              <ProductImagePlaceholder product={product} />
              <div>
                <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">Image metadata</p>
                <p className="mt-1 text-sm font-semibold text-[var(--color-primary)]">
                  {product.primaryImagePath ? "Private product image metadata exists" : "No product image metadata"}
                </p>
              </div>
            </div>
            <div className="grid gap-3 md:grid-cols-2">
              {[
                ["Supplier", product.supplierBusinessName ?? product.supplierName ?? "Unavailable"],
                ["Category", product.category ?? "Uncategorized"],
                ["Base price", formatMoney(product.basePriceAmount, product.currencyCode)],
                ["Stock quantity", String(product.stockQuantity)],
                ["Submitted", formatDate(product.createdAt)],
                ["Updated", formatDate(product.updatedAt)]
              ].map(([label, value]) => (
                <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={label}>
                  <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{label}</p>
                  <p className="mt-1 break-words text-sm font-semibold text-[var(--color-charcoal)]">{value}</p>
                </div>
              ))}
            </div>
            {product.description ? <p className="mt-4 text-sm leading-6 text-[var(--color-muted)]">{product.description}</p> : null}
          </Card>

          <Card title="Review state">
            <div className="flex items-start gap-3 text-sm leading-6 text-[var(--color-muted)]">
              <PackageCheck className="mt-1 h-5 w-5 shrink-0 text-[var(--color-primary)]" aria-hidden />
              <p>
                Approval updates must go through `review_supplier_product`. Supplier self-approval and public catalog exposure remain blocked.
              </p>
            </div>
            {product.rejectionReason ? (
              <p className="mt-3 rounded-[var(--radius-md)] border border-[var(--color-danger)]/30 bg-red-50 p-3 text-sm font-semibold text-[var(--color-danger)]">
                {product.rejectionReason}
              </p>
            ) : null}
          </Card>
        </div>

        <div className="space-y-5">
          <Card title="Approve or reject">
            <ReviewActions product={product} />
          </Card>
          <Card title="Catalog scope">
            <p className="text-sm leading-6 text-[var(--color-muted)]">
              Approval is backend/admin-only. Customer catalog, reseller catalog, checkout, stock reservation, orders, payments, delivery, settlements, and commissions remain disconnected.
            </p>
          </Card>
        </div>
      </div>
    </AdminShell>
  );
}
