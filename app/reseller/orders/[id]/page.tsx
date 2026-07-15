import { ResellerOrderDetailScreen } from "@/components/reseller/screens";

export default async function ResellerOrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <ResellerOrderDetailScreen id={id} />;
}
