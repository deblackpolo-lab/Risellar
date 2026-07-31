"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  acceptSupplierOrderWithClient,
  getSupplierOrderSafeWithClient,
  listSupplierOrdersSafeWithClient,
  mapSupplierOrderRpcError,
  rejectSupplierOrderWithClient,
  type SupplierOrderListInput
} from "@/lib/orders/supplier-order-read";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function getSupplierOrderClient() {
  const { getToken, userId } = await auth();

  if (!userId) {
    throw new Error("AUTH_REQUIRED");
  }

  const profile = await getCurrentSyncedProfile();

  if (!profile) {
    throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
  }

  return createSupabaseUserServerClient(accessToken);
}

export async function getSupplierOrdersForCurrentUser(input: SupplierOrderListInput = {}) {
  try {
    const supabase = await getSupplierOrderClient();
    return await listSupplierOrdersSafeWithClient(supabase, input);
  } catch (error) {
    return {
      orders: [],
      state: mapSupplierOrderRpcError(error)
    };
  }
}

export async function getSupplierOrderForCurrentUser(orderId: string) {
  try {
    const supabase = await getSupplierOrderClient();
    return await getSupplierOrderSafeWithClient(supabase, orderId);
  } catch (error) {
    return {
      order: null,
      state: mapSupplierOrderRpcError(error)
    };
  }
}

export async function acceptSupplierOrderFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const supabase = await getSupplierOrderClient();
    const result = await acceptSupplierOrderWithClient(supabase, {
      orderId,
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=ACCEPTED`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function rejectSupplierOrderFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const supabase = await getSupplierOrderClient();
    const result = await rejectSupplierOrderWithClient(supabase, {
      orderId,
      reasonCode: formData.get("reason_code")?.toString(),
      reasonNote: formData.get("reason_note")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=REJECTED`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}
