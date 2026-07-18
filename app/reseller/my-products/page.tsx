import { ResellerMyProductsRpcScreen } from "@/components/reseller/reseller-catalog-rpc-screens";
import {
  archiveResellerListingAction,
  getResellerShopProductsForCurrentUser,
  updateResellerListingMarginAction
} from "../products/actions";

export default async function ResellerMyProductsPage({
  searchParams
}: {
  searchParams?: Promise<{ code?: string; listing?: string }>;
}) {
  const query = searchParams ? await searchParams : {};
  const { listings, error } = await getResellerShopProductsForCurrentUser();

  return (
    <ResellerMyProductsRpcScreen
      archiveAction={archiveResellerListingAction}
      error={error}
      listings={listings}
      listingCode={query.code}
      listingStatus={query.listing}
      updateAction={updateResellerListingMarginAction}
    />
  );
}
