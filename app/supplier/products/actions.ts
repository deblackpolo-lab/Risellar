"use server";

import { auth } from "@clerk/nextjs/server";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";
import {
  archiveSupplierProductWithClient,
  buildSupplierProductArchiveInputFromFormData,
  buildSupplierProductInputFromFormData,
  buildSupplierProductUpdateInputFromFormData,
  createSupplierProductWithClient,
  initialSupplierProductActionState,
  listSupplierProductsWithClient,
  mapSupplierProductRpcError,
  updateSupplierProductWithClient,
  type SupplierProductActionState
} from "@/lib/supplier/product-management";

async function getSupplierProductClient() {
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

export async function getSupplierProductsForCurrentUser() {
  try {
    const supabase = await getSupplierProductClient();
    return await listSupplierProductsWithClient(supabase);
  } catch (error) {
    return {
      products: [],
      error: mapSupplierProductRpcError(error)
    };
  }
}

export async function getSupplierProductForCurrentUser(productId: string) {
  const result = await getSupplierProductsForCurrentUser();

  return {
    product: result.products.find((product) => product.productId === productId || product.slug === productId) ?? null,
    error: result.error
  };
}

export async function createSupplierProductAction(
  _previousState: SupplierProductActionState = initialSupplierProductActionState,
  formData: FormData
) {
  try {
    const supabase = await getSupplierProductClient();
    return await createSupplierProductWithClient(supabase, buildSupplierProductInputFromFormData(formData));
  } catch (error) {
    return mapSupplierProductRpcError(error);
  }
}

export async function updateSupplierProductAction(
  _previousState: SupplierProductActionState = initialSupplierProductActionState,
  formData: FormData
) {
  try {
    const supabase = await getSupplierProductClient();
    return await updateSupplierProductWithClient(supabase, buildSupplierProductUpdateInputFromFormData(formData));
  } catch (error) {
    return mapSupplierProductRpcError(error);
  }
}

export async function archiveSupplierProductAction(
  _previousState: SupplierProductActionState = initialSupplierProductActionState,
  formData: FormData
) {
  try {
    const supabase = await getSupplierProductClient();
    return await archiveSupplierProductWithClient(supabase, buildSupplierProductArchiveInputFromFormData(formData));
  } catch (error) {
    return mapSupplierProductRpcError(error);
  }
}
