"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  addCustomerDisputeResponseWithClient,
  buildCustomerDisputeOpenInputFromFormData,
  buildCustomerDisputeResponseInputFromFormData,
  getCustomerDisputeSafeWithClient,
  initialCustomerDisputeActionState,
  listCustomerDisputesSafeWithClient,
  mapCustomerDisputeRpcError,
  openCustomerDisputeWithClient,
  type CustomerDisputeActionState,
  type CustomerDisputeListParams
} from "@/lib/customer/disputes";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function getCustomerDisputeClient() {
  const { getToken, userId } = await auth();

  if (!userId) {
    throw new Error("AUTH_REQUIRED");
  }

  const profile = await getCurrentSyncedProfile();

  if (!profile) {
    throw new Error("PROFILE_SYNC_FAILED");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
  }

  return createSupabaseUserServerClient(accessToken);
}

export async function getCustomerDisputesForCurrentUser(params: CustomerDisputeListParams = {}) {
  try {
    const supabase = await getCustomerDisputeClient();
    return await listCustomerDisputesSafeWithClient(supabase, params);
  } catch (error) {
    return {
      disputes: [],
      state: mapCustomerDisputeRpcError(error)
    };
  }
}

export async function getCustomerDisputeForCurrentUser(disputeId: string) {
  try {
    const supabase = await getCustomerDisputeClient();
    return await getCustomerDisputeSafeWithClient(supabase, disputeId);
  } catch (error) {
    return {
      dispute: null,
      state: mapCustomerDisputeRpcError(error)
    };
  }
}

export async function openCustomerDisputeAction(
  orderId: string,
  _previousState: CustomerDisputeActionState = initialCustomerDisputeActionState,
  formData: FormData
) {
  try {
    const supabase = await getCustomerDisputeClient();
    const input = buildCustomerDisputeOpenInputFromFormData(orderId, formData);
    const result = await openCustomerDisputeWithClient(supabase, input);

    revalidatePath("/customer/disputes");
    revalidatePath(`/customer/orders/${orderId}`);

    return result;
  } catch (error) {
    return mapCustomerDisputeRpcError(error);
  }
}

export async function addCustomerDisputeResponseAction(
  disputeId: string,
  _previousState: CustomerDisputeActionState = initialCustomerDisputeActionState,
  formData: FormData
) {
  try {
    const supabase = await getCustomerDisputeClient();
    const result = await addCustomerDisputeResponseWithClient(supabase, buildCustomerDisputeResponseInputFromFormData(disputeId, formData));

    revalidatePath("/customer/disputes");
    revalidatePath(`/customer/disputes/${disputeId}`);

    return result;
  } catch (error) {
    return mapCustomerDisputeRpcError(error);
  }
}
