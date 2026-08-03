import { CustomerDisputeDetailScreen, CustomerDisputeUnavailableScreen } from "@/components/customer/customer-dispute-rpc-screens";
import { getCustomerDisputeForCurrentUser } from "../actions";

export default async function CustomerDisputeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const result = await getCustomerDisputeForCurrentUser(id);

  if (!result.dispute) {
    return <CustomerDisputeUnavailableScreen message={result.state.message} />;
  }

  return <CustomerDisputeDetailScreen dispute={result.dispute} />;
}
