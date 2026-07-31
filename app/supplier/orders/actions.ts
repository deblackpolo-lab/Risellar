"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  acceptSupplierOrderWithClient,
  arrangeSupplierOrderDeliveryWithClient,
  getSupplierOrderSafeWithClient,
  markSupplierOrderDeliveredWithClient,
  markSupplierOrderOutForDeliveryWithClient,
  listSupplierOrdersSafeWithClient,
  markReadyForDeliverySupplierOrderWithClient,
  mapSupplierOrderRpcError,
  reportSupplierOrderPaymentReceivedWithClient,
  rejectSupplierOrderWithClient,
  startPreparingSupplierOrderWithClient,
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

export async function startSupplierOrderPreparingFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const acknowledgement = formData.get("preparation_acknowledgement")?.toString();

    if (acknowledgement !== "confirmed") {
      throw new Error("VALIDATION_ERROR");
    }

    const supabase = await getSupplierOrderClient();
    const result = await startPreparingSupplierOrderWithClient(supabase, {
      orderId,
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=PREPARING`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function markSupplierOrderReadyForDeliveryFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const acknowledgement = formData.get("ready_for_delivery_acknowledgement")?.toString();

    if (acknowledgement !== "confirmed") {
      throw new Error("VALIDATION_ERROR");
    }

    const supabase = await getSupplierOrderClient();
    const result = await markReadyForDeliverySupplierOrderWithClient(supabase, {
      orderId,
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=READY_FOR_DELIVERY`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function arrangeSupplierOrderDeliveryFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const acknowledgement = formData.get("delivery_arrangement_acknowledgement")?.toString();

    if (acknowledgement !== "confirmed") {
      throw new Error("VALIDATION_ERROR");
    }

    const supabase = await getSupplierOrderClient();
    const result = await arrangeSupplierOrderDeliveryWithClient(supabase, {
      orderId,
      deliveryMethod: formData.get("delivery_method")?.toString(),
      agreedDeliveryFeeAmount: formData.get("agreed_delivery_fee_amount")?.toString(),
      expectedDeliveryDate: formData.get("expected_delivery_date")?.toString(),
      expectedTimeWindow: formData.get("expected_time_window")?.toString(),
      courierDisplayName: formData.get("courier_display_name")?.toString(),
      courierPhone: formData.get("courier_phone")?.toString(),
      customerInstruction: formData.get("customer_instruction")?.toString(),
      supplierPrivateNote: formData.get("supplier_private_note")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=DELIVERY_ARRANGED`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function markSupplierOrderOutForDeliveryFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const acknowledgement = formData.get("out_for_delivery_acknowledgement")?.toString();

    if (acknowledgement !== "confirmed") {
      throw new Error("VALIDATION_ERROR");
    }

    const supabase = await getSupplierOrderClient();
    const result = await markSupplierOrderOutForDeliveryWithClient(supabase, {
      orderId,
      dispatchReference: formData.get("dispatch_reference")?.toString(),
      customerDispatchInstruction: formData.get("customer_dispatch_instruction")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=OUT_FOR_DELIVERY`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function markSupplierOrderDeliveredFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const acknowledgement = formData.get("delivered_acknowledgement")?.toString();

    if (acknowledgement !== "confirmed") {
      throw new Error("VALIDATION_ERROR");
    }

    const supabase = await getSupplierOrderClient();
    const result = await markSupplierOrderDeliveredWithClient(supabase, {
      orderId,
      deliveryConfirmationNote: formData.get("delivery_confirmation_note")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=DELIVERED`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(result.state.code)}`;
  } catch (error) {
    const state = mapSupplierOrderRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(`/supplier/orders/${orderId}`)}`
      : `/supplier/orders/${orderId}?supplier_order_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function reportSupplierOrderPaymentReceivedFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString() ?? "";
  let nextPath = `/supplier/orders/${orderId}`;

  try {
    const acknowledgement = formData.get("payment_received_acknowledgement")?.toString();

    if (acknowledgement !== "confirmed") {
      throw new Error("VALIDATION_ERROR");
    }

    const supabase = await getSupplierOrderClient();
    const result = await reportSupplierOrderPaymentReceivedWithClient(supabase, {
      orderId,
      paymentReference: formData.get("payment_reference")?.toString(),
      supplierPrivateNote: formData.get("supplier_private_note")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    revalidatePath("/supplier/orders");
    revalidatePath(`/supplier/orders/${orderId}`);
    nextPath = result.order
      ? `/supplier/orders/${orderId}?supplier_order_message=PAYMENT_REPORTED`
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
