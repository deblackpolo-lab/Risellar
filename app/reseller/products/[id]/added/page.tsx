import { ResellerAddedProductScreen } from "@/components/reseller/screens";

export default async function ResellerProductAddedPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <ResellerAddedProductScreen id={id} />;
}
