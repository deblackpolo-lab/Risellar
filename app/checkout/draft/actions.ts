"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  abandonCheckoutDraftWithClient,
  buildCheckoutDraftContactAddressInputFromFormData,
  buildCheckoutDraftCreateInputFromFormData,
  createCheckoutDraftFromListingWithClient,
  getCheckoutDraftWithClient,
  initialCheckoutDraftActionState,
  mapCheckoutDraftRpcError,
  updateCheckoutDraftContactAddressWithClient,
  type CheckoutDraftActionState
} from "@/lib/checkout/draft";
import { listCustomerDeliveryAddressesWithClient } from "@/lib/customer/profile-address";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function getCheckoutDraftClient() {
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

export async function startCheckoutDraftAction(formData: FormData) {
  const returnTo = formData.get("return_to")?.toString() ?? "/";
  let nextPath = returnTo;

  try {
    const supabase = await getCheckoutDraftClient();
    const result = await createCheckoutDraftFromListingWithClient(supabase, buildCheckoutDraftCreateInputFromFormData(formData));

    if (result.draft) {
      nextPath = `/checkout/draft/${result.draft.draftId}`;
    } else {
      nextPath = `${returnTo}?checkout_error=${encodeURIComponent(result.state.code)}`;
    }
  } catch (error) {
    const state = mapCheckoutDraftRpcError(error);
    nextPath = state.code === "AUTH_REQUIRED"
      ? `/sign-in?redirect_url=${encodeURIComponent(returnTo)}`
      : `${returnTo}?checkout_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function getCheckoutDraftPageData(draftId: string) {
  try {
    const supabase = await getCheckoutDraftClient();
    const [draftResult, addressResult] = await Promise.all([
      getCheckoutDraftWithClient(supabase, draftId),
      listCustomerDeliveryAddressesWithClient(supabase)
    ]);

    return {
      draft: draftResult.draft,
      addresses: addressResult.addresses,
      error: draftResult.draft ? null : draftResult.state
    };
  } catch (error) {
    return {
      draft: null,
      addresses: [],
      error: mapCheckoutDraftRpcError(error)
    };
  }
}

export async function attachCheckoutDraftAddressAction(
  _previousState: CheckoutDraftActionState = initialCheckoutDraftActionState,
  formData: FormData
) {
  try {
    const supabase = await getCheckoutDraftClient();
    const result = await updateCheckoutDraftContactAddressWithClient(supabase, buildCheckoutDraftContactAddressInputFromFormData(formData));

    if (result.draft) {
      revalidatePath(`/checkout/draft/${result.draft.draftId}`);
    }

    return result.state;
  } catch (error) {
    return mapCheckoutDraftRpcError(error);
  }
}

export async function attachCheckoutDraftAddressFormAction(formData: FormData) {
  const draftId = formData.get("draft_id")?.toString() ?? "";
  let nextPath = `/checkout/draft/${draftId}`;

  try {
    const supabase = await getCheckoutDraftClient();
    await updateCheckoutDraftContactAddressWithClient(supabase, buildCheckoutDraftContactAddressInputFromFormData(formData));
    revalidatePath(`/checkout/draft/${draftId}`);
    nextPath = `/checkout/draft/${draftId}?draft_message=ADDRESS_ATTACHED`;
  } catch (error) {
    const state = mapCheckoutDraftRpcError(error);
    nextPath = `/checkout/draft/${draftId}?draft_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}

export async function abandonCheckoutDraftAction(
  _previousState: CheckoutDraftActionState = initialCheckoutDraftActionState,
  formData: FormData
) {
  try {
    const supabase = await getCheckoutDraftClient();
    const result = await abandonCheckoutDraftWithClient(supabase, formData.get("draft_id")?.toString());

    if (result.draft) {
      revalidatePath(`/checkout/draft/${result.draft.draftId}`);
    }

    return result.state;
  } catch (error) {
    return mapCheckoutDraftRpcError(error);
  }
}

export async function abandonCheckoutDraftFormAction(formData: FormData) {
  const draftId = formData.get("draft_id")?.toString() ?? "";
  let nextPath = `/checkout/draft/${draftId}`;

  try {
    const supabase = await getCheckoutDraftClient();
    await abandonCheckoutDraftWithClient(supabase, draftId);
    revalidatePath(`/checkout/draft/${draftId}`);
    nextPath = `/checkout/draft/${draftId}?draft_message=DRAFT_ABANDONED`;
  } catch (error) {
    const state = mapCheckoutDraftRpcError(error);
    nextPath = `/checkout/draft/${draftId}?draft_error=${encodeURIComponent(state.code)}`;
  }

  redirect(nextPath);
}
