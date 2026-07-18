export type CustomerProfileAddressActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "VALIDATION_ERROR"
  | "ADDRESS_NOT_FOUND"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CustomerProfileAddressActionState = {
  code: CustomerProfileAddressActionCode;
  message: string;
};

export type CustomerDeliveryAddress = {
  id: string;
  customerId: string;
  label: string;
  recipientName: string;
  phone: string;
  region: string;
  city: string;
  area: string;
  streetAddress: string;
  landmark: string | null;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
};

export type CustomerContactInput = {
  fullName?: string | null;
  phone?: string | null;
  whatsapp?: string | null;
  email?: string | null;
};

export type CustomerAddressInput = {
  addressId?: string | null;
  label?: string | null;
  recipientName?: string | null;
  phone?: string | null;
  region?: string | null;
  city?: string | null;
  area?: string | null;
  streetAddress?: string | null;
  landmark?: string | null;
  isDefault?: boolean | string | null;
};

type CustomerProfileAddressRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type CustomerProfileAddressRpcResult<T> = PromiseLike<{
  data: T | null;
  error: CustomerProfileAddressRpcError | null;
}>;

export type CustomerProfileAddressRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): CustomerProfileAddressRpcResult<T>;
};

export const initialCustomerProfileAddressActionState: CustomerProfileAddressActionState = {
  code: "OK",
  message: ""
};

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

function requireText(value: string | null | undefined, label: string) {
  const text = cleanOptionalText(value);

  if (!text) {
    throw new Error(`${label} is required`);
  }

  return text;
}

function normalizeEmail(value: string | null | undefined) {
  const text = cleanOptionalText(value);
  return text ? text.toLowerCase() : null;
}

function normalizeBoolean(value: boolean | string | null | undefined) {
  return value === true || value === "true" || value === "on";
}

export function buildCustomerContactPayload(input: CustomerContactInput) {
  return {
    p_full_name: requireText(input.fullName, "Full name"),
    p_phone: requireText(input.phone, "Phone"),
    p_whatsapp: cleanOptionalText(input.whatsapp),
    p_email: normalizeEmail(input.email)
  };
}

export function buildCustomerAddressPayload(input: CustomerAddressInput) {
  return {
    p_label: requireText(input.label, "Address label"),
    p_recipient_name: requireText(input.recipientName, "Recipient name"),
    p_phone: requireText(input.phone, "Phone"),
    p_region: requireText(input.region, "Region"),
    p_city: requireText(input.city, "City"),
    p_area: requireText(input.area, "Area"),
    p_street_address: requireText(input.streetAddress, "Street address"),
    p_landmark: cleanOptionalText(input.landmark),
    p_is_default: normalizeBoolean(input.isDefault)
  };
}

export function mapCustomerProfileAddressRpcError(error: unknown): CustomerProfileAddressActionState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as CustomerProfileAddressRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required")) {
    return { code: "AUTH_REQUIRED", message: "Sign in before managing your contact or delivery addresses." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return {
      code: "SUPABASE_AUTH_TOKEN_MISSING",
      message: "We could not prepare your secure customer session. Please sign in again."
    };
  }

  if (combined.includes("profile_sync_failed")) {
    return {
      code: "AUTH_REQUIRED",
      message: "We could not prepare your customer profile. Please refresh or sign in again."
    };
  }

  if (
    combined.includes("is required")
    || combined.includes("23514")
    || combined.includes("validation")
    || combined.includes("full name")
    || combined.includes("phone")
    || combined.includes("address label")
  ) {
    return { code: "VALIDATION_ERROR", message: "Check the required contact and address fields, then try again." };
  }

  if (combined.includes("customer_address_not_found")) {
    return { code: "ADDRESS_NOT_FOUND", message: "That delivery address was not found for your customer account." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your profile is not allowed to perform this customer address action." };
  }

  return { code: "UNKNOWN", message: "Customer contact/address action failed. Try again or contact support." };
}

export async function upsertCustomerContactWithClient(client: CustomerProfileAddressRpcClient, input: CustomerContactInput) {
  try {
    const { error } = await client.rpc<unknown[]>("upsert_customer_contact", buildCustomerContactPayload(input));

    if (error) {
      return mapCustomerProfileAddressRpcError(error);
    }

    return { code: "OK" as const, message: "Contact details saved." };
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function createCustomerDeliveryAddressWithClient(client: CustomerProfileAddressRpcClient, input: CustomerAddressInput) {
  try {
    const { error } = await client.rpc<unknown[]>("create_customer_delivery_address", buildCustomerAddressPayload(input));

    if (error) {
      return mapCustomerProfileAddressRpcError(error);
    }

    return { code: "OK" as const, message: "Delivery address created." };
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function updateCustomerDeliveryAddressWithClient(client: CustomerProfileAddressRpcClient, input: CustomerAddressInput) {
  try {
    const addressId = requireText(input.addressId, "Address id");
    const { error } = await client.rpc<unknown[]>("update_customer_delivery_address", {
      p_address_id: addressId,
      ...buildCustomerAddressPayload(input)
    });

    if (error) {
      return mapCustomerProfileAddressRpcError(error);
    }

    return { code: "OK" as const, message: "Delivery address updated." };
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function archiveCustomerDeliveryAddressWithClient(client: CustomerProfileAddressRpcClient, addressId: string | null | undefined) {
  try {
    const { error } = await client.rpc<unknown[]>("archive_customer_delivery_address", {
      p_address_id: requireText(addressId, "Address id")
    });

    if (error) {
      return mapCustomerProfileAddressRpcError(error);
    }

    return { code: "OK" as const, message: "Delivery address archived." };
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function listCustomerDeliveryAddressesWithClient(client: CustomerProfileAddressRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("get_customer_delivery_addresses");

  if (error) {
    return {
      addresses: [] as CustomerDeliveryAddress[],
      error: mapCustomerProfileAddressRpcError(error)
    };
  }

  return {
    addresses: Array.isArray(data) ? data.map(mapCustomerDeliveryAddress) : [],
    error: null
  };
}

export function buildCustomerContactInputFromFormData(formData: FormData): CustomerContactInput {
  return {
    fullName: formData.get("full_name")?.toString(),
    phone: formData.get("phone")?.toString(),
    whatsapp: formData.get("whatsapp")?.toString(),
    email: formData.get("email")?.toString()
  };
}

export function buildCustomerAddressInputFromFormData(formData: FormData): CustomerAddressInput {
  return {
    addressId: formData.get("address_id")?.toString(),
    label: formData.get("label")?.toString(),
    recipientName: formData.get("recipient_name")?.toString(),
    phone: formData.get("phone")?.toString(),
    region: formData.get("region")?.toString(),
    city: formData.get("city")?.toString(),
    area: formData.get("area")?.toString(),
    streetAddress: formData.get("street_address")?.toString(),
    landmark: formData.get("landmark")?.toString(),
    isDefault: formData.get("is_default")?.toString()
  };
}

function mapCustomerDeliveryAddress(row: unknown): CustomerDeliveryAddress {
  const item = row as Record<string, unknown>;

  return {
    id: String(item.id ?? ""),
    customerId: String(item.customer_id ?? ""),
    label: String(item.label ?? ""),
    recipientName: String(item.recipient_name ?? ""),
    phone: String(item.phone ?? ""),
    region: String(item.region ?? ""),
    city: String(item.city ?? ""),
    area: String(item.area ?? ""),
    streetAddress: String(item.street_address ?? ""),
    landmark: cleanOptionalText(typeof item.landmark === "string" ? item.landmark : null),
    isDefault: item.is_default === true,
    createdAt: String(item.created_at ?? ""),
    updatedAt: String(item.updated_at ?? "")
  };
}
