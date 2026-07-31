import { SupplierOrdersRpcScreen } from "@/components/supplier/supplier-order-rpc-screens";
import { getSupplierOrdersForCurrentUser } from "./actions";

export default async function SupplierOrdersPage() {
  const { orders, state } = await getSupplierOrdersForCurrentUser();

  return <SupplierOrdersRpcScreen error={state.code === "OK" ? null : state} orders={orders} />;
}
