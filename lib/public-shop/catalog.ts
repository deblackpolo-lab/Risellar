export type PublicShopError = {
  code: "NOT_FOUND" | "RPC_PERMISSION_DENIED" | "UNKNOWN";
  message: string;
};

export type PublicShopSummary = {
  slug: string;
  displayName: string;
  bio: string | null;
};

export type PublicShopProduct = {
  listingId: string;
  productSlug: string;
  shareSlug: string;
  name: string;
  description: string | null;
  category: string | null;
  brand: string | null;
  listingStatus: string;
  productStatus: string;
  approvalStatus: string;
  finalCustomerPriceAmount: number | null;
  currencyCode: string;
  stockAvailabilityLabel: string;
  imageCount: number;
  primaryImageAlt: string | null;
};

type PublicShopRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type PublicShopRpcResult<T> = PromiseLike<{
  data: T | null;
  error: PublicShopRpcError | null;
}>;

export type PublicShopRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PublicShopRpcResult<T>;
};

export const publicShopForbiddenFields = [
  "base_price_amount",
  "platform_margin_amount",
  "reseller_margin_amount",
  "supplier_contact_phone",
  "supplier_private_phone",
  "payout_details_masked",
  "payout_account",
  "risk_level",
  "internal_notes",
  "admin_notes",
  "settlement_status",
  "commission_available_amount",
  "commission_pending_amount",
  "supplier_team_members",
  "permissions"
] as const;

export async function listPublicResellerShopWithClient(client: PublicShopRpcClient, shopSlug: string) {
  const { data, error } = await client.rpc<unknown[]>("get_public_reseller_shop", {
    p_shop_slug: shopSlug
  });

  if (error) {
    return {
      shop: null,
      products: [] as PublicShopProduct[],
      error: mapPublicShopRpcError(error)
    };
  }

  const rows = Array.isArray(data) ? data : [];
  const products = mapPublicShopRows(rows);
  const shop = mapPublicShopSummary(rows[0], shopSlug);

  return {
    shop,
    products,
    error: shop ? null : ({ code: "NOT_FOUND", message: "This shop is not available yet." } satisfies PublicShopError)
  };
}

export async function readPublicResellerShopProductWithClient(
  client: PublicShopRpcClient,
  shopSlug: string,
  productSlug: string
) {
  const { data, error } = await client.rpc<unknown[]>("get_public_reseller_shop_product", {
    p_shop_slug: shopSlug,
    p_product_slug: productSlug
  });

  if (error) {
    return {
      shop: null,
      product: null,
      error: mapPublicShopRpcError(error)
    };
  }

  const rows = Array.isArray(data) ? data : [];
  const products = mapPublicShopRows(rows);
  const shop = mapPublicShopSummary(rows[0], shopSlug);

  return {
    shop,
    product: products[0] ?? null,
    error: shop && products[0] ? null : ({ code: "NOT_FOUND", message: "This product is not available in this shop." } satisfies PublicShopError)
  };
}

export function mapPublicShopRows(rows: unknown[]): PublicShopProduct[] {
  return rows.map(mapPublicShopProduct).filter((product) => (
    product.listingStatus === "active"
    && product.productStatus === "active"
    && product.approvalStatus === "approved"
  ));
}

function mapPublicShopSummary(row: unknown, fallbackSlug: string): PublicShopSummary | null {
  if (!row || typeof row !== "object") {
    return null;
  }

  const item = row as Record<string, unknown>;
  const displayName = nullableString(item.shop_display_name);

  if (!displayName) {
    return null;
  }

  return {
    slug: String(item.shop_slug ?? fallbackSlug),
    displayName,
    bio: nullableString(item.shop_bio)
  };
}

function mapPublicShopProduct(row: unknown): PublicShopProduct {
  const item = row as Record<string, unknown>;

  return {
    listingId: String(item.listing_id ?? ""),
    productSlug: String(item.product_slug ?? ""),
    shareSlug: String(item.share_slug ?? ""),
    name: String(item.name ?? "Untitled product"),
    description: nullableString(item.description),
    category: nullableString(item.category),
    brand: nullableString(item.brand),
    listingStatus: String(item.listing_status ?? "unknown"),
    productStatus: String(item.product_status ?? "unknown"),
    approvalStatus: String(item.approval_status ?? "unknown"),
    finalCustomerPriceAmount: nullableNumber(item.customer_product_price_amount),
    currencyCode: String(item.currency_code ?? "GHS"),
    stockAvailabilityLabel: String(item.stock_availability_label ?? "Stock pending"),
    imageCount: Math.max(0, Number(item.image_count ?? 0)),
    primaryImageAlt: nullableString(item.primary_image_alt)
  };
}

function mapPublicShopRpcError(error: unknown): PublicShopError {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as PublicShopRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "This shop cannot be shown publicly." };
  }

  return { code: "UNKNOWN", message: "Public shop is unavailable. Try again later." };
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
