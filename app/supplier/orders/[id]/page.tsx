import {
  SupplierOrderDetailRpcScreen,
  SupplierOrderNotFoundRpcScreen
} from "@/components/supplier/supplier-order-rpc-screens";
import { initialSupplierOrderState, type SupplierOrderState } from "@/lib/orders/supplier-order-read";
import {
  acceptSupplierOrderFormAction,
  getSupplierOrderForCurrentUser,
  markSupplierOrderReadyForDeliveryFormAction,
  rejectSupplierOrderFormAction,
  startSupplierOrderPreparingFormAction
} from "../actions";

function stateFromSearchParams(searchParams?: { supplier_order_message?: string; supplier_order_error?: string }): SupplierOrderState {
  if (searchParams?.supplier_order_message === "ACCEPTED") {
    return { code: "OK", message: "Order accepted" };
  }

  if (searchParams?.supplier_order_message === "REJECTED") {
    return { code: "OK", message: "Order rejected and reserved stock released" };
  }

  if (searchParams?.supplier_order_message === "PREPARING") {
    return { code: "OK", message: "Order preparation started" };
  }

  if (searchParams?.supplier_order_message === "READY_FOR_DELIVERY") {
    return { code: "OK", message: "Order is ready for delivery" };
  }

  const errorCode = searchParams?.supplier_order_error;

  if (!errorCode) {
    return initialSupplierOrderState;
  }

  const messages: Partial<Record<SupplierOrderState["code"], string>> = {
    AUTH_REQUIRED: "Sign in to manage this order.",
    SUPABASE_AUTH_TOKEN_MISSING: "We could not verify your supplier session. Please sign in again.",
    SUPPLIER_REQUIRED: "Use an approved supplier account.",
    ORDER_NOT_FOUND: "This order is unavailable.",
    ORDER_NOT_ACTIONABLE: "This order cannot start preparation.",
    ORDER_NOT_CONFIRMED: "Accept this order before starting preparation.",
    ORDER_NOT_PREPARING: "Start preparing this order before marking it ready.",
    RESERVATION_NOT_FOUND: "The stock reservation is unavailable.",
    RESERVATION_EXPIRED: "The stock reservation has expired.",
    RESERVATION_NOT_ACTIVE: "This order no longer has an active stock reservation.",
    ALREADY_CONFIRMED: "This order has already been accepted.",
    ALREADY_REJECTED: "This order has already been rejected.",
    ALREADY_PREPARING: "Preparation has already started.",
    ALREADY_READY: "This order is already ready for delivery.",
    PREPARATION_NOT_STARTED: "Preparation has not started for this order.",
    INVALID_REJECTION_REASON: "Choose a valid rejection reason.",
    REJECTION_NOTE_TOO_LONG: "Keep the note within the allowed length.",
    STOCK_RELEASE_FAILED: "The reserved stock could not be released safely.",
    UNKNOWN: "We could not confirm the result. Refresh the order before trying again."
  };

  const code = errorCode as SupplierOrderState["code"];
  return { code, message: messages[code] ?? "We could not confirm the result. Refresh the order before trying again." };
}

export default async function SupplierOrderDetailPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ supplier_order_message?: string; supplier_order_error?: string }>;
}) {
  const { id } = await params;
  const query = await searchParams;
  const { order, state } = await getSupplierOrderForCurrentUser(id);

  if (!order) {
    return <SupplierOrderNotFoundRpcScreen state={state} />;
  }

  return (
    <SupplierOrderDetailRpcScreen
      acceptAction={acceptSupplierOrderFormAction}
      actionState={stateFromSearchParams(query)}
      markReadyForDeliveryAction={markSupplierOrderReadyForDeliveryFormAction}
      order={order}
      rejectAction={rejectSupplierOrderFormAction}
      startPreparingAction={startSupplierOrderPreparingFormAction}
    />
  );
}
