import { auth } from "@clerk/nextjs/server";
import { AdminProductApprovalAccessDenied, AdminProductApprovalListScreen } from "@/components/admin/product-approval-rpc-screens";
import { getRoleOnboardingAdminAccess } from "@/lib/auth/admin-access";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import { canReviewSupplierProducts, type AdminProductReviewActionCode } from "@/lib/admin/product-approval";
import { loadAdminProductApprovalItems, type AdminProductApprovalQueryClient } from "@/lib/admin/product-approval-data";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

type SearchParams = Promise<{
  error?: AdminProductReviewActionCode;
  status?: "approved" | "rejected";
}>;

export default async function AdminProductsPage({ searchParams }: { searchParams: SearchParams }) {
  const { error, status } = await searchParams;
  const { getToken, userId } = await auth();

  if (!userId) {
    return <AdminProductApprovalAccessDenied />;
  }

  const profile = await getCurrentSyncedProfile();
  const accessToken = await getToken();

  if (!accessToken) {
    return <AdminProductApprovalListScreen error="SUPABASE_AUTH_TOKEN_MISSING" products={[]} />;
  }

  const adminAccess = await getRoleOnboardingAdminAccess({ accessToken, profile });

  if (!canReviewSupplierProducts(adminAccess)) {
    return <AdminProductApprovalAccessDenied />;
  }

  const supabase = createSupabaseUserServerClient(accessToken) as unknown as AdminProductApprovalQueryClient;
  const { products, error: loadError } = await loadAdminProductApprovalItems(supabase);

  return <AdminProductApprovalListScreen error={error ?? (loadError ? "UNKNOWN" : undefined)} products={products} status={status} />;
}
