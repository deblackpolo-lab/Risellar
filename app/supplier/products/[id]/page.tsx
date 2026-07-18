import { SupplierProductDetailRpcScreen, SupplierProductNotFoundRpcScreen } from "@/components/supplier/product-management-rpc-screens";
import { getSupplierProductForCurrentUser } from "../actions";

export default async function SupplierProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { product, error } = await getSupplierProductForCurrentUser(id);

  if (!product) {
    return <SupplierProductNotFoundRpcScreen error={error} />;
  }

  return <SupplierProductDetailRpcScreen product={product} />;
}
