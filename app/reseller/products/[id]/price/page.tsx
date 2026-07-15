import { ResellerPriceScreen } from "@/components/reseller/screens";

export default async function ResellerProductPricePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <ResellerPriceScreen id={id} />;
}
