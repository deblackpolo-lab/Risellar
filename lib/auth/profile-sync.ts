import "server-only";

import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import {
  findOrCreateProfileForClerkIdentity,
  normalizeClerkIdentity,
  type ClerkIdentitySource,
  type ProfileInsert,
  type ProfileRepository,
  type SyncedProfile
} from "./profile-sync-core";
import { getCurrentClerkUser } from "./clerk";

function createSupabaseProfileRepository(): ProfileRepository {
  const supabase = createSupabaseAdminClient();

  return {
    async findByClerkUserId(clerkUserId: string) {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, clerk_user_id, email, full_name, primary_role, account_status")
        .eq("clerk_user_id", clerkUserId)
        .maybeSingle();

      if (error) {
        throw new Error(`Failed to read Risellar profile: ${error.message}`);
      }

      return data as SyncedProfile | null;
    },
    async createProfile(profile: ProfileInsert) {
      const { data, error } = await supabase
        .from("profiles")
        .insert(profile)
        .select("id, clerk_user_id, email, full_name, primary_role, account_status")
        .single();

      if (error) {
        throw new Error(`Failed to create Risellar profile: ${error.message}`);
      }

      return data as SyncedProfile;
    }
  };
}

export async function findOrCreateProfileFromClerkIdentity(
  identity: ClerkIdentitySource,
  repository = createSupabaseProfileRepository()
) {
  return findOrCreateProfileForClerkIdentity(normalizeClerkIdentity(identity), repository);
}

export async function getCurrentSyncedProfile(repository = createSupabaseProfileRepository()) {
  const clerkUser = await getCurrentClerkUser();

  if (!clerkUser) {
    return null;
  }

  return findOrCreateProfileFromClerkIdentity(clerkUser, repository);
}
