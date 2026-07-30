import { Button } from "@/components/ui";
import { startCheckoutDraftAction } from "@/app/checkout/draft/actions";

export function CheckoutDraftStartForm({
  listingId,
  returnTo
}: {
  listingId: string;
  returnTo: string;
}) {
  return (
    <form action={startCheckoutDraftAction} className="w-full">
      <input name="listing_id" type="hidden" value={listingId} />
      <input name="quantity" type="hidden" value="1" />
      <input name="return_to" type="hidden" value={returnTo} />
      <Button className="w-full" disabled={!listingId} type="submit">Start checkout</Button>
    </form>
  );
}
