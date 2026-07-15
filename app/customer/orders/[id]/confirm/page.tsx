import { CustomerOrderConfirmScreen } from "@/components/customer/screens";

export default async function CustomerOrderConfirmPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <CustomerOrderConfirmScreen id={id} />;
}
