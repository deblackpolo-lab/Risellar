import { SupplierProductsRpcScreen } from "@/components/supplier/product-management-rpc-screens";
import { getSupplierProductsForCurrentUser } from "./actions";

export default async function SupplierProductsPage() {
  const { products, error } = await getSupplierProductsForCurrentUser();

  return <SupplierProductsRpcScreen error={error} products={products} />;
}
