export type AdminProductReviewDecision = "approved" | "rejected";

export type AdminProductReviewActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "ADMIN_REQUIRED"
  | "INVALID_REVIEW_DECISION"
  | "INVALID_PRODUCT_REVIEW"
  | "RPC_PERMISSION_DENIED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "UNKNOWN";

export type AdminProductReviewActionState = {
  code: AdminProductReviewActionCode;
  message: string;
  productId?: string;
};

export type AdminProductReviewAccess = {
  hasActiveAdminStaff: boolean;
} | null;

type AdminProductReviewRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type AdminProductReviewRpcResult<T> = PromiseLike<{
  data: T | null;
  error: AdminProductReviewRpcError | null;
}>;

export type AdminProductReviewRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): AdminProductReviewRpcResult<T>;
};

export type AdminProductReviewInput = {
  productId?: string | null;
  decision?: string | null;
  reviewNotes?: string | null;
};

export const adminProductReviewDecisions = ["approved", "rejected"] as const;

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

export function buildAdminProductReviewPayload(input: AdminProductReviewInput) {
  const productId = cleanOptionalText(input.productId);

  if (!productId) {
    throw new Error("Product id is required");
  }

  if (!adminProductReviewDecisions.includes(input.decision as AdminProductReviewDecision)) {
    throw new Error("Product review decision must be approved or rejected");
  }

  return {
    productId,
    decision: input.decision as AdminProductReviewDecision,
    reviewNotes: cleanOptionalText(input.reviewNotes)
  };
}

export function canReviewSupplierProducts(access: AdminProductReviewAccess) {
  return access?.hasActiveAdminStaff === true;
}

export function mapAdminProductReviewRpcError(error: unknown): AdminProductReviewActionState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as AdminProductReviewRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required")) {
    return { code: "AUTH_REQUIRED", message: "Sign in with an admin account before reviewing products." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return {
      code: "SUPABASE_AUTH_TOKEN_MISSING",
      message: "We could not prepare your secure Supabase admin session. Please sign in again."
    };
  }

  if (combined.includes("admin role is required") || combined.includes("admin_required")) {
    return { code: "ADMIN_REQUIRED", message: "Only admin users can review supplier products." };
  }

  if (combined.includes("approved or rejected") || combined.includes("invalid_review_decision")) {
    return { code: "INVALID_REVIEW_DECISION", message: "Product review decisions must be approved or rejected." };
  }

  if (combined.includes("product id is required") || combined.includes("product not found") || combined.includes("pending review")) {
    return { code: "INVALID_PRODUCT_REVIEW", message: "Choose a pending supplier product before reviewing." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your signed-in session is not allowed to review supplier products." };
  }

  return { code: "UNKNOWN", message: "Product review failed. Please try again." };
}

export async function reviewSupplierProductWithClient(client: AdminProductReviewRpcClient, input: AdminProductReviewInput) {
  try {
    const payload = buildAdminProductReviewPayload(input);
    const { data, error } = await client.rpc<string>("review_supplier_product", {
      p_product_id: payload.productId,
      p_decision: payload.decision,
      p_review_notes: payload.reviewNotes
    });

    if (error) {
      return mapAdminProductReviewRpcError(error);
    }

    return {
      code: "OK" as const,
      message: `Product ${payload.decision}.`,
      productId: data ?? payload.productId
    };
  } catch (error) {
    return mapAdminProductReviewRpcError(error);
  }
}
