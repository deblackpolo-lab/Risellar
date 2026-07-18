import { ResellerCatalogDetailRpcScreen, ResellerCatalogNotFoundRpcScreen } from "@/components/reseller/reseller-catalog-rpc-screens";
import { createResellerListingAction } from "../actions";
import { getResellerCatalogProductForCurrentUser } from "../actions";

export default async function ProductDetailPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ code?: string; listing?: string }>;
}) {
  const { id } = await params;
  const query = searchParams ? await searchParams : {};
  const { product, error } = await getResellerCatalogProductForCurrentUser(id);

  if (!product) {
    return <ResellerCatalogNotFoundRpcScreen error={error} />;
  }

  return (
    <ResellerCatalogDetailRpcScreen
      action={createResellerListingAction}
      listingCode={query.code}
      listingStatus={query.listing}
      product={product}
    />
  );
}
