import { SupplierFinanceRpcPage } from "../finance/finance-page";

export default function SupplierSettlementsPage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; from?: string; to?: string }>;
}) {
  return <SupplierFinanceRpcPage searchParams={searchParams} title="Supplier settlements" />;
}
