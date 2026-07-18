export type SupplierProductActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPPLIER_REQUIRED"
  | "VALIDATION_ERROR"
  | "DUPLICATE_OR_CONFLICT"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type SupplierProductActionState = {
  code: SupplierProductActionCode;
  message: string;
  productId?: string;
};

export type SupplierProductListItem = {
  productId: string;
  supplierId: string;
  category: string | null;
  name: string;
  slug: string;
  description: string | null;
  brand: string | null;
  productStatus: string;
  approvalStatus: string;
  basePriceAmount: number;
  resellerCostAmount: number | null;
  maxCustomerPriceAmount: number | null;
  currencyCode: string;
  createdAt: string;
  updatedAt: string;
  imageCount: number;
};

type SupplierProductRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type SupplierProductRpcResult<T> = PromiseLike<{
  data: T | null;
  error: SupplierProductRpcError | null;
}>;

export type SupplierProductRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): SupplierProductRpcResult<T>;
};

export type SupplierProductFormInput = {
  productName?: string | null;
  description?: string | null;
  category?: string | null;
  basePrice?: string | number | null;
  stockQuantity?: string | number | null;
  brand?: string | null;
};

export type SupplierProductUpdateInput = SupplierProductFormInput & {
  productId?: string | null;
};

export type SupplierProductArchiveInput = {
  productId?: string | null;
  reason?: string | null;
};

export const initialSupplierProductActionState: SupplierProductActionState = {
  code: "OK",
  message: ""
};

export const supplierProductForbiddenSubmitFields = [
  "approval_status",
  "product_status",
  "platform_margin_amount",
  "max_reseller_margin_amount",
  "reseller_cost_amount",
  "approved_at",
  "approved_by",
  "deleted_at"
] as const;

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

function requireProductName(value: string | null | undefined) {
  const productName = cleanOptionalText(value);

  if (!productName) {
    throw new Error("Product name is required");
  }

  return productName;
}

function parseBasePrice(value: string | number | null | undefined) {
  const amount = typeof value === "number" ? value : Number(value);

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("Base price must be greater than 0");
  }

  return amount;
}

function parseStockQuantity(value: string | number | null | undefined) {
  const quantity = value === null || value === undefined || value === "" ? 0 : Number(value);

  if (!Number.isInteger(quantity) || quantity < 0) {
    throw new Error("Stock quantity must be 0 or greater");
  }

  return quantity;
}

export function buildCreateSupplierProductPayload(input: SupplierProductFormInput) {
  return {
    p_product_name: requireProductName(input.productName),
    p_description: cleanOptionalText(input.description),
    p_category: cleanOptionalText(input.category),
    p_base_price: parseBasePrice(input.basePrice),
    p_stock_quantity: parseStockQuantity(input.stockQuantity),
    p_variants: null,
    p_image_metadata: null
  };
}

export function buildUpdateSupplierProductPayload(input: SupplierProductUpdateInput) {
  const productId = cleanOptionalText(input.productId);

  if (!productId) {
    throw new Error("Product id is required");
  }

  return {
    p_product_id: productId,
    p_product_name: input.productName === undefined ? null : cleanOptionalText(input.productName),
    p_description: input.description === undefined ? null : cleanOptionalText(input.description),
    p_category: input.category === undefined ? null : cleanOptionalText(input.category),
    p_base_price: input.basePrice === undefined || input.basePrice === null || input.basePrice === "" ? null : parseBasePrice(input.basePrice),
    p_brand: input.brand === undefined ? null : cleanOptionalText(input.brand)
  };
}

export function buildArchiveSupplierProductPayload(input: SupplierProductArchiveInput) {
  const productId = cleanOptionalText(input.productId);

  if (!productId) {
    throw new Error("Product id is required");
  }

  return {
    p_product_id: productId,
    p_reason: cleanOptionalText(input.reason)
  };
}

export function mapSupplierProductRpcError(error: unknown): SupplierProductActionState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as SupplierProductRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "AUTH_REQUIRED", message: "Sign in before managing supplier products." };
  }

  if (
    combined.includes("active approved supplier owner") ||
    combined.includes("supplier owner") ||
    combined.includes("supplier_required")
  ) {
    return { code: "SUPPLIER_REQUIRED", message: "An approved supplier owner profile is required to manage products." };
  }

  if (
    combined.includes("product name is required") ||
    combined.includes("base price must be greater than 0") ||
    combined.includes("stock quantity must be 0 or greater") ||
    combined.includes("product id is required") ||
    combined.includes("validation")
  ) {
    return { code: "VALIDATION_ERROR", message: "Check the product details and try again." };
  }

  if (combined.includes("duplicate") || combined.includes("conflict") || combined.includes("23505")) {
    return { code: "DUPLICATE_OR_CONFLICT", message: "A conflicting product record already exists." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your profile is not allowed to perform this product action." };
  }

  return { code: "UNKNOWN", message: "Product action failed. Try again or contact support." };
}

export async function listSupplierProductsWithClient(client: SupplierProductRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("get_supplier_products");

  if (error) {
    return {
      products: [],
      error: mapSupplierProductRpcError(error)
    };
  }

  return {
    products: Array.isArray(data) ? data.map(mapSupplierProductListItem) : [],
    error: null
  };
}

export async function createSupplierProductWithClient(client: SupplierProductRpcClient, input: SupplierProductFormInput) {
  try {
    const payload = buildCreateSupplierProductPayload(input);
    const { data, error } = await client.rpc<string>("create_supplier_product", payload);

    if (error) {
      return mapSupplierProductRpcError(error);
    }

    return {
      code: "OK" as const,
      message: "Product saved for admin review.",
      productId: data ?? undefined
    };
  } catch (error) {
    return mapSupplierProductRpcError(error);
  }
}

export async function updateSupplierProductWithClient(client: SupplierProductRpcClient, input: SupplierProductUpdateInput) {
  try {
    const payload = buildUpdateSupplierProductPayload(input);
    const { data, error } = await client.rpc<string>("update_supplier_product", payload);

    if (error) {
      return mapSupplierProductRpcError(error);
    }

    return {
      code: "OK" as const,
      message: "Product changes saved for review.",
      productId: data ?? payload.p_product_id
    };
  } catch (error) {
    return mapSupplierProductRpcError(error);
  }
}

export async function archiveSupplierProductWithClient(client: SupplierProductRpcClient, input: SupplierProductArchiveInput) {
  try {
    const payload = buildArchiveSupplierProductPayload(input);
    const { data, error } = await client.rpc<string>("archive_supplier_product", payload);

    if (error) {
      return mapSupplierProductRpcError(error);
    }

    return {
      code: "OK" as const,
      message: "Product archived.",
      productId: data ?? payload.p_product_id
    };
  } catch (error) {
    return mapSupplierProductRpcError(error);
  }
}

export function buildSupplierProductInputFromFormData(formData: FormData): SupplierProductFormInput {
  return {
    productName: formData.get("product_name")?.toString(),
    description: formData.get("description")?.toString(),
    category: formData.get("category")?.toString(),
    basePrice: formData.get("base_price")?.toString(),
    stockQuantity: formData.get("stock_quantity")?.toString(),
    brand: formData.get("brand")?.toString()
  };
}

export function buildSupplierProductUpdateInputFromFormData(formData: FormData): SupplierProductUpdateInput {
  return {
    ...buildSupplierProductInputFromFormData(formData),
    productId: formData.get("product_id")?.toString()
  };
}

export function buildSupplierProductArchiveInputFromFormData(formData: FormData): SupplierProductArchiveInput {
  return {
    productId: formData.get("product_id")?.toString(),
    reason: formData.get("reason")?.toString()
  };
}

function mapSupplierProductListItem(row: unknown): SupplierProductListItem {
  const item = row as Record<string, unknown>;

  return {
    productId: String(item.product_id ?? ""),
    supplierId: String(item.supplier_id ?? ""),
    category: nullableString(item.category),
    name: String(item.name ?? "Untitled product"),
    slug: String(item.slug ?? ""),
    description: nullableString(item.description),
    brand: nullableString(item.brand),
    productStatus: String(item.product_status ?? "unknown"),
    approvalStatus: String(item.approval_status ?? "unknown"),
    basePriceAmount: Number(item.base_price_amount ?? 0),
    resellerCostAmount: nullableNumber(item.reseller_cost_amount),
    maxCustomerPriceAmount: nullableNumber(item.max_customer_price_amount),
    currencyCode: String(item.currency_code ?? "GHS"),
    createdAt: String(item.created_at ?? ""),
    updatedAt: String(item.updated_at ?? ""),
    imageCount: Number(item.image_count ?? 0)
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
