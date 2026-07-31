import {
  SupplierOrderDetailRpcScreen,
  SupplierOrderNotFoundRpcScreen
} from "@/components/supplier/supplier-order-rpc-screens";
import { initialSupplierOrderState, type SupplierOrderState } from "@/lib/orders/supplier-order-read";
import {
  acceptSupplierOrderFormAction,
  arrangeSupplierOrderDeliveryFormAction,
  getSupplierOrderForCurrentUser,
  markSupplierOrderDeliveredFormAction,
  markSupplierOrderOutForDeliveryFormAction,
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

  if (searchParams?.supplier_order_message === "DELIVERY_ARRANGED") {
    return { code: "OK", message: "Delivery arrangement saved" };
  }

  if (searchParams?.supplier_order_message === "OUT_FOR_DELIVERY") {
    return { code: "OK", message: "Order marked as out for delivery" };
  }

  if (searchParams?.supplier_order_message === "DELIVERED") {
    return { code: "OK", message: "Order marked as delivered" };
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
    ORDER_NOT_ARRANGED: "Arrange delivery before marking this order out for delivery.",
    RESERVATION_NOT_FOUND: "The stock reservation is unavailable.",
    RESERVATION_EXPIRED: "The stock reservation has expired.",
    RESERVATION_NOT_ACTIVE: "This order no longer has an active stock reservation.",
    ALREADY_CONFIRMED: "This order has already been accepted.",
    ALREADY_REJECTED: "This order has already been rejected.",
    ALREADY_PREPARING: "Preparation has already started.",
    ALREADY_READY: "This order is already ready for delivery.",
    ALREADY_ARRANGED: "Delivery arrangement has already been recorded.",
    ALREADY_OUT_FOR_DELIVERY: "This order is already out for delivery.",
    ALREADY_DELIVERED: "This order has already been marked delivered.",
    ORDER_NOT_OUT_FOR_DELIVERY: "Mark this order out for delivery before marking it delivered.",
    DELIVERY_ARRANGEMENT_NOT_FOUND: "The delivery arrangement is unavailable.",
    DISPATCH_NOT_RECORDED: "Dispatch has not been recorded for this order.",
    INVALID_DISPATCH_FIELD: "Dispatch details cannot include live tracking or verified delivery claims.",
    INVALID_DELIVERY_NOTE: "Delivery note cannot include payment, identity, tracking, or sensitive details.",
    PREPARATION_NOT_STARTED: "Preparation has not started for this order.",
    INVALID_DELIVERY_METHOD: "Choose a valid delivery method.",
    INVALID_DELIVERY_FEE: "Enter a valid delivery fee.",
    DELIVERY_FEE_TOO_HIGH: "The delivery fee is above the allowed limit.",
    EXPECTED_DATE_IN_PAST: "Choose today or a future expected delivery date.",
    INVALID_COURIER_PHONE: "Enter a valid courier or rider phone number.",
    FIELD_TOO_LONG: "Shorten the information and try again.",
    CONFLICTING_RETRY: "This retry does not match the saved order update. Refresh the order.",
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
      arrangeDeliveryAction={arrangeSupplierOrderDeliveryFormAction}
      markDeliveredAction={markSupplierOrderDeliveredFormAction}
      markOutForDeliveryAction={markSupplierOrderOutForDeliveryFormAction}
      markReadyForDeliveryAction={markSupplierOrderReadyForDeliveryFormAction}
      order={order}
      rejectAction={rejectSupplierOrderFormAction}
      startPreparingAction={startSupplierOrderPreparingFormAction}
    />
  );
}
