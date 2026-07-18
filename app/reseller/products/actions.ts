"use server";

import { auth } from "@clerk/nextjs/server";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";
import {
  listResellerCatalogProductsWithClient,
  mapResellerCatalogRpcError
} from "@/lib/reseller/catalog";

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
