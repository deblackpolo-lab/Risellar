import { auth } from "@clerk/nextjs/server";
import { AdminProductApprovalAccessDenied, AdminProductApprovalDetailScreen } from "@/components/admin/product-approval-rpc-screens";
import { getRoleOnboardingAdminAccess } from "@/lib/auth/admin-access";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import { canReviewSupplierProducts, type AdminProductReviewActionCode } from "@/lib/admin/product-approval";
import { loadAdminProductApprovalItem, type AdminProductApprovalQueryClient } from "@/lib/admin/product-approval-data";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

type SearchParams = Promise<{
  error?: AdminProductReviewActionCode;
  status?: "approved" | "rejected";
}>;

export default async function AdminProductDetailPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams: SearchParams;
}) {
  const { id } = await params;
  const { error, status } = await searchParams;
  const { getToken, userId } = await auth();

  if (!userId) {
    return <AdminProductApprovalAccessDenied />;
  }

  const profile = await getCurrentSyncedProfile();
  const accessToken = await getToken();

  if (!accessToken) {
    return <AdminProductApprovalDetailScreen error="SUPABASE_AUTH_TOKEN_MISSING" product={null} />;
  }

  const adminAccess = await getRoleOnboardingAdminAccess({ accessToken, profile });

  if (!canReviewSupplierProducts(adminAccess)) {
    return <AdminProductApprovalAccessDenied />;
  }

  const supabase = createSupabaseUserServerClient(accessToken) as unknown as AdminProductApprovalQueryClient;
  const { product, error: loadError } = await loadAdminProductApprovalItem(supabase, id);

  return <AdminProductApprovalDetailScreen error={error ?? (loadError ? "UNKNOWN" : undefined)} product={product} status={status} />;
}
