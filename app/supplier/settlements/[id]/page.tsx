import { SettlementDetailScreen } from "@/components/supplier/settlement-screens";

export default async function SupplierSettlementDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <SettlementDetailScreen settlementId={id} />;
}
