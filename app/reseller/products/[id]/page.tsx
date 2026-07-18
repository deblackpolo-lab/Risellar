import { ResellerCatalogDetailRpcScreen, ResellerCatalogNotFoundRpcScreen } from "@/components/reseller/reseller-catalog-rpc-screens";
import { getResellerCatalogProductForCurrentUser } from "../actions";

export default async function ProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { product, error } = await getResellerCatalogProductForCurrentUser(id);

  if (!product) {
    return <ResellerCatalogNotFoundRpcScreen error={error} />;
  }

  return <ResellerCatalogDetailRpcScreen product={product} />;
}
