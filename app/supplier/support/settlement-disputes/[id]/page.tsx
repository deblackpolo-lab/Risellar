import { SupplierSettlementDisputeDetailScreen } from "@/components/support/support-disputes-screens";

export default async function SupplierSettlementDisputeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <SupplierSettlementDisputeDetailScreen disputeId={id} />;
}
