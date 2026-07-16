import { CustomerDisputeDetailScreen } from "@/components/support/support-disputes-screens";

export default async function CustomerDisputeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CustomerDisputeDetailScreen disputeId={id} />;
}
