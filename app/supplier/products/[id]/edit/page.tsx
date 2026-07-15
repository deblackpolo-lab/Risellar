import { SupplierEditProductScreen } from "@/components/supplier/screens";

export default async function SupplierEditProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <SupplierEditProductScreen id={id} />;
}
