import { ResellerCommissionDisputeDetailScreen } from "@/components/support/support-disputes-screens";

export default async function ResellerCommissionDisputeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ResellerCommissionDisputeDetailScreen disputeId={id} />;
}
