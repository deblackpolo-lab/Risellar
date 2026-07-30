import { CheckoutDraftReviewScreen } from "@/components/customer/checkout-draft-rpc-screens";
import { getCheckoutDraftPageData } from "../actions";
import { type CheckoutDraftActionState } from "@/lib/checkout/draft";
import type { CheckoutOrderConfirmationState } from "@/lib/orders/confirm-checkout-order";

function messageFromSearchParams(searchParams?: { draft_error?: string; draft_message?: string }): CheckoutDraftActionState | CheckoutOrderConfirmationState | null {
  if (searchParams?.draft_message === "ADDRESS_ATTACHED") {
    return { code: "OK", message: "Delivery address attached to draft." };
  }

  if (searchParams?.draft_message === "DRAFT_ABANDONED") {
    return { code: "OK", message: "Checkout draft abandoned." };
  }

  if (searchParams?.draft_error) {
    if (searchParams.draft_error === "ACKNOWLEDGEMENT_REQUIRED") {
      return { code: "ACKNOWLEDGEMENT_REQUIRED", message: "Accept the Pay on Delivery acknowledgement before placing this order." };
    }

    if (searchParams.draft_error === "CHECKOUT_DRAFT_NOT_READY") {
      return { code: "CHECKOUT_DRAFT_NOT_READY", message: "This draft is not ready for final Pay on Delivery confirmation." };
    }

    if (searchParams.draft_error === "INSUFFICIENT_STOCK") {
      return { code: "INSUFFICIENT_STOCK", message: "This product just sold out or has less stock than requested. No order was placed." };
    }

    return { code: "UNKNOWN", message: "Checkout draft action failed. Try again or contact support." };
  }

  return null;
}

export default async function CheckoutDraftPage({
  params,
  searchParams
}: {
  params: Promise<{ draftId: string }>;
  searchParams?: Promise<{ draft_error?: string; draft_message?: string }>;
}) {
  const { draftId } = await params;
  const query = await searchParams;
  const result = await getCheckoutDraftPageData(draftId);

  return <CheckoutDraftReviewScreen addresses={result.addresses} draft={result.draft} error={result.error ?? messageFromSearchParams(query)} />;
}
