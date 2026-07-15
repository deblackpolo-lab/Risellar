import { SupplierOrderDetailScreen } from "@/components/supplier/screens";

export default async function SupplierOrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <SupplierOrderDetailScreen id={id} />;
}
