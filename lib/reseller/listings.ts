export type ResellerListingActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "RESELLER_REQUIRED"
  | "DUPLICATE_LISTING"
  | "INVALID_MARGIN"
  | "RPC_PERMISSION_DENIED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "UNKNOWN";

export type ResellerListingError = {
  code: ResellerListingActionCode;
  message: string;
};

export type ResellerShopProduct = {
  listingId: string;
  productId: string;
  shopId: string;
  supplierId: string;
  supplierDisplayName: string | null;
  category: string | null;
  name: string;
  slug: string;
  description: string | null;
  brand: string | null;
  listingStatus: string;
  productStatus: string;
  approvalStatus: string;
  resellerCostAmount: number | null;
  resellerMarginAmount: number | null;
  customerProductPriceAmount: number | null;
  currencyCode: string;
  availableStockQuantity: number;
  imageCount: number;
  shareSlug: string | null;
  createdAt: string;
  updatedAt: string;
};

type ResellerListingRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type ResellerListingRpcResult<T> = PromiseLike<{
  data: T | null;
  error: ResellerListingRpcError | null;
}>;

export type ResellerListingRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): ResellerListingRpcResult<T>;
};

export type ResellerListingActionResult =
  | { ok: true; listingId: string }
  | { ok: false; error: ResellerListingError };

export function mapResellerListingRpcError(error: unknown): ResellerListingError {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as ResellerListingRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required")) {
    return { code: "AUTH_REQUIRED", message: "Sign in with an approved reseller account to manage your shop." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return {
      code: "SUPABASE_AUTH_TOKEN_MISSING",
      message: "We could not prepare your secure Supabase reseller session. Please sign in again."
    };
  }

  if (combined.includes("duplicate active reseller listing")) {
    return {
      code: "DUPLICATE_LISTING",
      message: "This product is already active in your shop. Edit it from My products instead."
    };
  }

  if (
    combined.includes("margin must be greater than zero")
    || combined.includes("margin exceeds")
    || combined.includes("margin is required")
  ) {
    return {
      code: "INVALID_MARGIN",
      message: "Enter a reseller margin greater than zero and within the product limit."
    };
  }

  if (combined.includes("approved reseller") || combined.includes("reseller_required") || combined.includes("reseller account")) {
    return { code: "RESELLER_REQUIRED", message: "An approved reseller account is required to manage shop listings." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your signed-in profile is not allowed to manage this listing." };
  }

  return { code: "UNKNOWN", message: "Shop listing action failed. Try again or contact support." };
}

export async function createResellerListingWithClient(
  client: ResellerListingRpcClient,
  input: { productId: string; resellerMargin: number }
): Promise<ResellerListingActionResult> {
  const { data, error } = await client.rpc<string>("create_reseller_product_listing", {
    p_product_id: input.productId,
    p_reseller_margin: input.resellerMargin
  });

  if (error) {
    return { ok: false, error: mapResellerListingRpcError(error) };
  }

  return { ok: true, listingId: String(data ?? "") };
}

export async function updateResellerListingWithClient(
  client: ResellerListingRpcClient,
  input: { listingId: string; resellerMargin: number }
): Promise<ResellerListingActionResult> {
  const { data, error } = await client.rpc<string>("update_reseller_product_listing", {
    p_listing_id: input.listingId,
    p_reseller_margin: input.resellerMargin,
    p_listing_status: null
  });

  if (error) {
    return { ok: false, error: mapResellerListingRpcError(error) };
  }

  return { ok: true, listingId: String(data ?? input.listingId) };
}

export async function archiveResellerListingWithClient(
  client: ResellerListingRpcClient,
  input: { listingId: string }
): Promise<ResellerListingActionResult> {
  const { data, error } = await client.rpc<string>("archive_reseller_product_listing", {
    p_listing_id: input.listingId
  });

  if (error) {
    return { ok: false, error: mapResellerListingRpcError(error) };
  }

  return { ok: true, listingId: String(data ?? input.listingId) };
}

export async function listResellerShopProductsWithClient(client: ResellerListingRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("get_reseller_shop_products");

  if (error) {
    return {
      listings: [] as ResellerShopProduct[],
      error: mapResellerListingRpcError(error)
    };
  }

  return {
    listings: mapResellerShopProductRows(Array.isArray(data) ? data : []),
    error: null
  };
}

export function mapResellerShopProductRows(rows: unknown[]): ResellerShopProduct[] {
  return rows.map(mapResellerShopProduct);
}

function mapResellerShopProduct(row: unknown): ResellerShopProduct {
  const item = row as Record<string, unknown>;

  return {
    listingId: String(item.listing_id ?? ""),
    productId: String(item.product_id ?? ""),
    shopId: String(item.shop_id ?? ""),
    supplierId: String(item.supplier_id ?? ""),
    supplierDisplayName: nullableString(item.supplier_display_name),
    category: nullableString(item.category),
    name: String(item.name ?? "Untitled product"),
    slug: String(item.slug ?? ""),
    description: nullableString(item.description),
    brand: nullableString(item.brand),
    listingStatus: String(item.listing_status ?? "unknown"),
    productStatus: String(item.product_status ?? "unknown"),
    approvalStatus: String(item.approval_status ?? "unknown"),
    resellerCostAmount: nullableNumber(item.reseller_cost_amount),
    resellerMarginAmount: nullableNumber(item.reseller_margin_amount),
    customerProductPriceAmount: nullableNumber(item.customer_product_price_amount),
    currencyCode: String(item.currency_code ?? "GHS"),
    availableStockQuantity: Math.max(0, Number(item.available_stock_quantity ?? 0)),
    imageCount: Math.max(0, Number(item.image_count ?? 0)),
    shareSlug: nullableString(item.share_slug),
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
