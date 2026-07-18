import { ResellerCatalogRpcScreen } from "@/components/reseller/reseller-catalog-rpc-screens";
import { getResellerCatalogForCurrentUser } from "./actions";

export default async function ResellerProductsPage() {
  const { products, error } = await getResellerCatalogForCurrentUser();

  return <ResellerCatalogRpcScreen error={error} products={products} />;
}
