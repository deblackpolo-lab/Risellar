import { CheckoutDraftReviewScreen } from "@/components/customer/checkout-draft-rpc-screens";
import { getCheckoutDraftPageData } from "../actions";
import { type CheckoutDraftActionState } from "@/lib/checkout/draft";

function messageFromSearchParams(searchParams?: { draft_error?: string; draft_message?: string }): CheckoutDraftActionState | null {
  if (searchParams?.draft_message === "ADDRESS_ATTACHED") {
    return { code: "OK", message: "Delivery address attached to draft." };
  }

  if (searchParams?.draft_message === "DRAFT_ABANDONED") {
    return { code: "OK", message: "Checkout draft abandoned." };
  }

  if (searchParams?.draft_error) {
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
