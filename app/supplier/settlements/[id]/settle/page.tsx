import { SettlementSettleScreen } from "@/components/supplier/settlement-screens";

export default async function SupplierSettlementSettlePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <SettlementSettleScreen settlementId={id} />;
}
