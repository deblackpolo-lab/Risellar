import { CustomerOrderTrackingScreen } from "@/components/customer/screens";

export default async function CustomerOrderPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <CustomerOrderTrackingScreen id={id} />;
}
