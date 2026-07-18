"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  archiveCustomerDeliveryAddressWithClient,
  buildCustomerAddressInputFromFormData,
  buildCustomerContactInputFromFormData,
  createCustomerDeliveryAddressWithClient,
  initialCustomerProfileAddressActionState,
  listCustomerDeliveryAddressesWithClient,
  mapCustomerProfileAddressRpcError,
  updateCustomerDeliveryAddressWithClient,
  upsertCustomerContactWithClient,
  type CustomerProfileAddressActionState
} from "@/lib/customer/profile-address";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function getCustomerPhaseAClient() {
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

export async function getCustomerAddressesForCurrentUser() {
  try {
    const supabase = await getCustomerPhaseAClient();
    return await listCustomerDeliveryAddressesWithClient(supabase);
  } catch (error) {
    return {
      addresses: [],
      error: mapCustomerProfileAddressRpcError(error)
    };
  }
}

export async function saveCustomerContactAction(
  _previousState: CustomerProfileAddressActionState = initialCustomerProfileAddressActionState,
  formData: FormData
) {
  try {
    const supabase = await getCustomerPhaseAClient();
    const result = await upsertCustomerContactWithClient(supabase, buildCustomerContactInputFromFormData(formData));
    revalidatePath("/customer/addresses");
    return result;
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function createCustomerAddressAction(
  _previousState: CustomerProfileAddressActionState = initialCustomerProfileAddressActionState,
  formData: FormData
) {
  try {
    const supabase = await getCustomerPhaseAClient();
    const result = await createCustomerDeliveryAddressWithClient(supabase, buildCustomerAddressInputFromFormData(formData));
    revalidatePath("/customer/addresses");
    return result;
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function updateCustomerAddressAction(
  _previousState: CustomerProfileAddressActionState = initialCustomerProfileAddressActionState,
  formData: FormData
) {
  try {
    const supabase = await getCustomerPhaseAClient();
    const result = await updateCustomerDeliveryAddressWithClient(supabase, buildCustomerAddressInputFromFormData(formData));
    revalidatePath("/customer/addresses");
    return result;
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}

export async function archiveCustomerAddressAction(
  _previousState: CustomerProfileAddressActionState = initialCustomerProfileAddressActionState,
  formData: FormData
) {
  try {
    const supabase = await getCustomerPhaseAClient();
    const result = await archiveCustomerDeliveryAddressWithClient(supabase, formData.get("address_id")?.toString());
    revalidatePath("/customer/addresses");
    return result;
  } catch (error) {
    return mapCustomerProfileAddressRpcError(error);
  }
}
