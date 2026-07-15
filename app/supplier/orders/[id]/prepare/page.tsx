import { SupplierPrepareOrderScreen } from "@/components/supplier/screens";

export default async function SupplierPrepareOrderPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <SupplierPrepareOrderScreen id={id} />;
}
