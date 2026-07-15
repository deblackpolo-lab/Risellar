import { CustomerDeliveryQuoteScreen } from "@/components/customer/screens";

export default async function CustomerDeliveryQuotePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <CustomerDeliveryQuoteScreen id={id} />;
}
