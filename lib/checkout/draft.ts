export type CheckoutDraftActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "VALIDATION_ERROR"
  | "CHECKOUT_LISTING_NOT_AVAILABLE"
  | "CHECKOUT_DRAFT_NOT_FOUND"
  | "CUSTOMER_ADDRESS_NOT_FOUND"
  | "CHECKOUT_DRAFT_NOT_ACTIVE"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CheckoutDraftActionState = {
  code: CheckoutDraftActionCode;
  message: string;
};

export type CheckoutDraft = {
  draftId: string;
  draftStatus: string;
  customerId: string;
  resellerProductId: string;
  productId: string;
  productName: string;
  productSlug: string;
  productImageSnapshot: Record<string, unknown>;
  quantity: number;
  finalCustomerPriceAmount: number | null;
  lineTotalAmount: number | null;
  currencyCode: string;
  deliveryAddressId: string | null;
  customerContactSnapshot: Record<string, unknown>;
  deliveryAddressSnapshot: Record<string, unknown>;
  publicListingSnapshot: Record<string, unknown>;
  convertedOrderId: string | null;
  abandonedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CheckoutDraftRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export type CheckoutDraftCreateInput = {
  listingId?: string | null;
  quantity?: string | number | null;
};

export type CheckoutDraftContactAddressInput = {
  draftId?: string | null;
  addressId?: string | null;
  contactPhone?: string | null;
};

export const initialCheckoutDraftActionState: CheckoutDraftActionState = {
  code: "OK",
  message: ""
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

function requireUuid(value: string | null | undefined, label: string) {
  const text = cleanOptionalText(value);

  if (!text || !uuidPattern.test(text)) {
    throw new Error(`${label} is required`);
  }

  return text;
}

function normalizeQuantity(value: string | number | null | undefined) {
  const numericValue = typeof value === "number" ? value : Number(value ?? 1);

  if (!Number.isInteger(numericValue) || numericValue < 1 || numericValue > 20) {
    throw new Error("Quantity must be between 1 and 20");
  }

  return numericValue;
}

export function buildCheckoutDraftCreatePayload(input: CheckoutDraftCreateInput) {
  return {
    p_listing_id: requireUuid(input.listingId, "Listing id"),
    p_quantity: normalizeQuantity(input.quantity)
  };
}

export function buildCheckoutDraftContactAddressPayload(input: CheckoutDraftContactAddressInput) {
  return {
    p_draft_id: requireUuid(input.draftId, "Draft id"),
    p_address_id: requireUuid(input.addressId, "Address id"),
    p_contact_phone: cleanOptionalText(input.contactPhone)
  };
}

export function mapCheckoutDraftRpcError(error: unknown): CheckoutDraftActionState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required")) {
    return { code: "AUTH_REQUIRED", message: "Sign in as a customer before starting checkout." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure customer session. Please sign in again." };
  }

  if (combined.includes("profile_sync_failed")) {
    return { code: "AUTH_REQUIRED", message: "We could not prepare your customer profile. Please refresh or sign in again." };
  }

  if (combined.includes("checkout_listing_not_available")) {
    return { code: "CHECKOUT_LISTING_NOT_AVAILABLE", message: "This product is not available for checkout draft creation." };
  }

  if (combined.includes("checkout_draft_not_found")) {
    return { code: "CHECKOUT_DRAFT_NOT_FOUND", message: "This checkout draft was not found for your customer account." };
  }

  if (combined.includes("customer_address_not_found")) {
    return { code: "CUSTOMER_ADDRESS_NOT_FOUND", message: "Choose one of your saved delivery addresses." };
  }

  if (combined.includes("checkout_draft_not_active")) {
    return { code: "CHECKOUT_DRAFT_NOT_ACTIVE", message: "This checkout draft is already abandoned and cannot be updated." };
  }

  if (combined.includes("listing id") || combined.includes("draft id") || combined.includes("address id") || combined.includes("quantity") || combined.includes("23514")) {
    return { code: "VALIDATION_ERROR", message: "Check the checkout draft fields, then try again." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your profile is not allowed to perform this checkout draft action." };
  }

  return { code: "UNKNOWN", message: "Checkout draft action failed. Try again or contact support." };
}

export async function createCheckoutDraftFromListingWithClient(client: CheckoutDraftRpcClient, input: CheckoutDraftCreateInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("create_checkout_draft_from_listing", buildCheckoutDraftCreatePayload(input));

    if (error) {
      return { draft: null, state: mapCheckoutDraftRpcError(error) };
    }

    const draft = mapCheckoutDraftRows(data)[0] ?? null;
    return draft
      ? { draft, state: { code: "OK" as const, message: "Checkout draft created." } }
      : { draft: null, state: { code: "UNKNOWN" as const, message: "Checkout draft was not returned." } };
  } catch (error) {
    return { draft: null, state: mapCheckoutDraftRpcError(error) };
  }
}

export async function getCheckoutDraftWithClient(client: CheckoutDraftRpcClient, draftId: string | null | undefined) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_checkout_draft", {
      p_draft_id: requireUuid(draftId, "Draft id")
    });

    if (error) {
      return { draft: null, state: mapCheckoutDraftRpcError(error) };
    }

    return {
      draft: mapCheckoutDraftRows(data)[0] ?? null,
      state: { code: "OK" as const, message: "" }
    };
  } catch (error) {
    return { draft: null, state: mapCheckoutDraftRpcError(error) };
  }
}

export async function updateCheckoutDraftContactAddressWithClient(client: CheckoutDraftRpcClient, input: CheckoutDraftContactAddressInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("update_checkout_draft_contact_address", buildCheckoutDraftContactAddressPayload(input));

    if (error) {
      return { draft: null, state: mapCheckoutDraftRpcError(error) };
    }

    return {
      draft: mapCheckoutDraftRows(data)[0] ?? null,
      state: { code: "OK" as const, message: "Delivery address attached to draft." }
    };
  } catch (error) {
    return { draft: null, state: mapCheckoutDraftRpcError(error) };
  }
}

export async function abandonCheckoutDraftWithClient(client: CheckoutDraftRpcClient, draftId: string | null | undefined) {
  try {
    const { data, error } = await client.rpc<unknown[]>("abandon_checkout_draft", {
      p_draft_id: requireUuid(draftId, "Draft id")
    });

    if (error) {
      return { draft: null, state: mapCheckoutDraftRpcError(error) };
    }

    return {
      draft: mapCheckoutDraftRows(data)[0] ?? null,
      state: { code: "OK" as const, message: "Checkout draft abandoned." }
    };
  } catch (error) {
    return { draft: null, state: mapCheckoutDraftRpcError(error) };
  }
}

export function buildCheckoutDraftCreateInputFromFormData(formData: FormData): CheckoutDraftCreateInput {
  return {
    listingId: formData.get("listing_id")?.toString(),
    quantity: formData.get("quantity")?.toString() ?? "1"
  };
}

export function buildCheckoutDraftContactAddressInputFromFormData(formData: FormData): CheckoutDraftContactAddressInput {
  return {
    draftId: formData.get("draft_id")?.toString(),
    addressId: formData.get("address_id")?.toString(),
    contactPhone: formData.get("contact_phone")?.toString()
  };
}

function mapCheckoutDraftRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapCheckoutDraftRow) : [];
}

function mapJsonObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined) {
    return null;
  }

  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
}

function nullableString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function mapCheckoutDraftRow(row: unknown): CheckoutDraft {
  const item = row as Record<string, unknown>;

  return {
    draftId: String(item.draft_id ?? ""),
    draftStatus: String(item.draft_status ?? "unknown"),
    customerId: String(item.customer_id ?? ""),
    resellerProductId: String(item.reseller_product_id ?? ""),
    productId: String(item.product_id ?? ""),
    productName: String(item.product_name ?? "Untitled product"),
    productSlug: String(item.product_slug ?? ""),
    productImageSnapshot: mapJsonObject(item.product_image_snapshot),
    quantity: Number(item.quantity ?? 0),
    finalCustomerPriceAmount: nullableNumber(item.final_customer_price_amount),
    lineTotalAmount: nullableNumber(item.line_total_amount),
    currencyCode: String(item.currency_code ?? "GHS"),
    deliveryAddressId: nullableString(item.delivery_address_id),
    customerContactSnapshot: mapJsonObject(item.customer_contact_snapshot),
    deliveryAddressSnapshot: mapJsonObject(item.delivery_address_snapshot),
    publicListingSnapshot: mapJsonObject(item.public_listing_snapshot),
    convertedOrderId: nullableString(item.converted_order_id),
    abandonedAt: nullableString(item.abandoned_at),
    createdAt: String(item.created_at ?? ""),
    updatedAt: String(item.updated_at ?? "")
  };
}
