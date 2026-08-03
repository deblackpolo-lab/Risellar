import { redirect } from "next/navigation";

export default async function CustomerReportIssuePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  redirect(`/customer/orders/${id}/report-problem`);
}
