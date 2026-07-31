import "server-only";

import {
  startPreparingSupplierOrderWithClient,
  type SupplierOrderDecisionInput,
  type SupplierOrderRpcClient
} from "./supplier-order-read";

export async function startSupplierOrderPreparation(client: SupplierOrderRpcClient, input: SupplierOrderDecisionInput) {
  return startPreparingSupplierOrderWithClient(client, input);
}
