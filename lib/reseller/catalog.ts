export type ResellerCatalogActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "RESELLER_REQUIRED"
  | "RPC_PERMISSION_DENIED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "UNKNOWN";

export type ResellerCatalogError = {
  code: ResellerCatalogActionCode;
  message: string;
};

export type ResellerCatalogProduct = {
  productId: string;
  supplierId: string;
  supplierDisplayName: string | null;
  category: string | null;
  name: string;
  slug: string;
  description: string | null;
  brand: string | null;
  productStatus: string;
  approvalStatus: string;
  resellerCostAmount: number | null;
  maxCustomerPriceAmount: number | null;
  currencyCode: string;
  availableStockQuantity: number;
  imageCount: number;
  createdAt: string;
  updatedAt: string;
};

type ResellerCatalogRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type ResellerCatalogRpcResult<T> = PromiseLike<{
  data: T | null;
  error: ResellerCatalogRpcError | null;
}>;

export type ResellerCatalogRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): ResellerCatalogRpcResult<T>;
};

export const resellerCatalogForbiddenFields = [
  "base_price_amount",
  "platform_margin_amount",
  "max_reseller_margin_amount",
  "approved_by_profile_id",
  "rejection_reason",
  "supplier_private_phone",
  "supplier_contact_phone",
  "payout_account",
  "settlement_status",
  "risk_level",
  "internal_notes",
  "admin_notes"
] as const;

export function mapResellerCatalogRpcError(error: unknown): ResellerCatalogError {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as ResellerCatalogRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required")) {
    return { code: "AUTH_REQUIRED", message: "Sign in with an approved reseller account to browse products." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return {
      code: "SUPABASE_AUTH_TOKEN_MISSING",
      message: "We could not prepare your secure Supabase reseller session. Please sign in again."
    };
  }

  if (combined.includes("approved reseller") || combined.includes("reseller_required")) {
    return { code: "RESELLER_REQUIRED", message: "An approved reseller account is required to browse supplier products." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your signed-in profile is not allowed to view this catalog." };
  }

  return { code: "UNKNOWN", message: "Product catalog is unavailable. Try again or contact support." };
}

export async function listResellerCatalogProductsWithClient(client: ResellerCatalogRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("get_reseller_approved_products");

  if (error) {
    return {
      products: [] as ResellerCatalogProduct[],
      error: mapResellerCatalogRpcError(error)
    };
  }

  return {
    products: mapResellerCatalogRows(Array.isArray(data) ? data : []),
    error: null
  };
}

export function mapResellerCatalogRows(rows: unknown[]): ResellerCatalogProduct[] {
  return rows.map(mapResellerCatalogProduct).filter((product) => (
    product.approvalStatus === "approved"
    && product.productStatus === "active"
  ));
}

function mapResellerCatalogProduct(row: unknown): ResellerCatalogProduct {
  const item = row as Record<string, unknown>;

  return {
    productId: String(item.product_id ?? ""),
    supplierId: String(item.supplier_id ?? ""),
    supplierDisplayName: nullableString(item.supplier_display_name),
    category: nullableString(item.category),
    name: String(item.name ?? "Untitled product"),
    slug: String(item.slug ?? ""),
    description: nullableString(item.description),
    brand: nullableString(item.brand),
    productStatus: String(item.product_status ?? "unknown"),
    approvalStatus: String(item.approval_status ?? "unknown"),
    resellerCostAmount: nullableNumber(item.reseller_cost_amount),
    maxCustomerPriceAmount: nullableNumber(item.max_customer_price_amount),
    currencyCode: String(item.currency_code ?? "GHS"),
    availableStockQuantity: Math.max(0, Number(item.available_stock_quantity ?? 0)),
    imageCount: Math.max(0, Number(item.image_count ?? 0)),
    createdAt: String(item.created_at ?? ""),
    updatedAt: String(item.updated_at ?? "")
  };
}

function nullableString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined) {
    return null;
  }

  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}
