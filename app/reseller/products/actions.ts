"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";
import {
  listResellerCatalogProductsWithClient,
  mapResellerCatalogRpcError
} from "@/lib/reseller/catalog";
import {
  archiveResellerListingWithClient,
  createResellerListingWithClient,
  listResellerShopProductsWithClient,
  mapResellerListingRpcError,
  updateResellerListingWithClient
} from "@/lib/reseller/listings";

async function getResellerCatalogClient() {
  const { getToken, userId } = await auth();

  if (!userId) {
    throw new Error("AUTH_REQUIRED");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
  }

  return createSupabaseUserServerClient(accessToken);
}

function parseMargin(formData: FormData) {
  const rawMargin = formData.get("reseller_margin");
  const margin = Number(rawMargin);

  if (!Number.isFinite(margin) || margin <= 0) {
    throw new Error("RESELLER_MARGIN_INVALID");
  }

  return Math.round(margin * 100) / 100;
}

function listingRedirectPath(path: string, status: "created" | "updated" | "archived" | "error", code?: string) {
  const params = new URLSearchParams();
  params.set("listing", status);

  if (code) {
    params.set("code", code);
  }

  return `${path}?${params.toString()}`;
}

export async function getResellerCatalogForCurrentUser() {
  try {
    const supabase = await getResellerCatalogClient();
    return await listResellerCatalogProductsWithClient(supabase);
  } catch (error) {
    return {
      products: [],
      error: mapResellerCatalogRpcError(error)
    };
  }
}

export async function getResellerCatalogProductForCurrentUser(productId: string) {
  const result = await getResellerCatalogForCurrentUser();

  return {
    product: result.products.find((product) => product.productId === productId || product.slug === productId) ?? null,
    error: result.error
  };
}

export async function getResellerShopProductsForCurrentUser() {
  try {
    const supabase = await getResellerCatalogClient();
    return await listResellerShopProductsWithClient(supabase);
  } catch (error) {
    return {
      listings: [],
      error: mapResellerListingRpcError(error)
    };
  }
}

export async function createResellerListingAction(formData: FormData) {
  const productId = String(formData.get("product_id") ?? "");
  let targetPath = listingRedirectPath(`/reseller/products/${productId}`, "error", "UNKNOWN");

  try {
    const resellerMargin = parseMargin(formData);
    const supabase = await getResellerCatalogClient();
    const result = await createResellerListingWithClient(supabase, { productId, resellerMargin });

    if (!result.ok) {
      targetPath = listingRedirectPath(`/reseller/products/${productId}`, "error", result.error.code);
    } else {
      revalidatePath("/reseller/my-products");
      revalidatePath("/reseller/products");
      targetPath = listingRedirectPath("/reseller/my-products", "created");
    }
  } catch (error) {
    const mapped = mapResellerListingRpcError(error);
    targetPath = listingRedirectPath(`/reseller/products/${productId}`, "error", mapped.code === "UNKNOWN" ? "INVALID_MARGIN" : mapped.code);
  }

  redirect(targetPath);
}

export async function updateResellerListingMarginAction(formData: FormData) {
  const listingId = String(formData.get("listing_id") ?? "");
  let targetPath = listingRedirectPath("/reseller/my-products", "error", "UNKNOWN");

  try {
    const resellerMargin = parseMargin(formData);
    const supabase = await getResellerCatalogClient();
    const result = await updateResellerListingWithClient(supabase, { listingId, resellerMargin });

    if (!result.ok) {
      targetPath = listingRedirectPath("/reseller/my-products", "error", result.error.code);
    } else {
      revalidatePath("/reseller/my-products");
      targetPath = listingRedirectPath("/reseller/my-products", "updated");
    }
  } catch (error) {
    const mapped = mapResellerListingRpcError(error);
    targetPath = listingRedirectPath("/reseller/my-products", "error", mapped.code === "UNKNOWN" ? "INVALID_MARGIN" : mapped.code);
  }

  redirect(targetPath);
}

export async function archiveResellerListingAction(formData: FormData) {
  const listingId = String(formData.get("listing_id") ?? "");
  let targetPath = listingRedirectPath("/reseller/my-products", "error", "UNKNOWN");

  try {
    const supabase = await getResellerCatalogClient();
    const result = await archiveResellerListingWithClient(supabase, { listingId });

    if (!result.ok) {
      targetPath = listingRedirectPath("/reseller/my-products", "error", result.error.code);
    } else {
      revalidatePath("/reseller/my-products");
      targetPath = listingRedirectPath("/reseller/my-products", "archived");
    }
  } catch (error) {
    const mapped = mapResellerListingRpcError(error);
    targetPath = listingRedirectPath("/reseller/my-products", "error", mapped.code);
  }

  redirect(targetPath);
}
