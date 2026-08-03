import { CustomerDisputeListScreen } from "@/components/customer/customer-dispute-rpc-screens";
import { getCustomerDisputesForCurrentUser } from "./actions";

export default async function CustomerDisputesPage({
  searchParams
}: {
  searchParams: Promise<{ status?: string; limit?: string }>;
}) {
  const params = await searchParams;
  const result = await getCustomerDisputesForCurrentUser({
    status: params.status,
    limit: params.limit
  });

  return <CustomerDisputeListScreen disputes={result.disputes} state={result.state} status={params.status} />;
}
