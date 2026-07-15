import { SupplierProductDetailScreen } from "@/components/supplier/screens";

export default async function SupplierProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <SupplierProductDetailScreen id={id} />;
}
