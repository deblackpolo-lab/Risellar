import { auth } from "@clerk/nextjs/server";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { AdminSettlementDetailScreen } from "@/components/admin/admin-supplier-settlement-rpc-screens";
import {
  getAdminSupplierSettlementSafeWithClient,
  mapAdminSettlementRpcError,
  type AdminSettlementCode
} from "@/lib/admin/settlements/admin-supplier-settlement";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

type AdminSettlementDetailPageProps = {
  params: Promise<{
    orderId: string;
  }>;
  searchParams?: Promise<{
    error?: string;
    status?: string;
  }>;
};

export default async function AdminSettlementDetailPage({ params, searchParams }: AdminSettlementDetailPageProps) {
  const { orderId } = await params;
  const query = await searchParams;
  let settlement = null;
  let errorCode = query?.error as AdminSettlementCode | undefined;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const result = await getAdminSupplierSettlementSafeWithClient(createSupabaseUserServerClient(accessToken), orderId);
    settlement = result.settlement;

    if (result.state.code !== "OK") {
      errorCode = result.state.code;
    }
  } catch (error) {
    errorCode = mapAdminSettlementRpcError(error).code;
  }

  return (
    <AdminShell searchPlaceholder="Search settlements, suppliers, orders...">
      <AdminSettlementDetailScreen errorCode={errorCode} settlement={settlement} success={query?.status === "verified"} />
    </AdminShell>
  );
}
