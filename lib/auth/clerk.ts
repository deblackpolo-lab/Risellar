import "server-only";

import { auth, currentUser } from "@clerk/nextjs/server";
import { normalizeClerkIdentity } from "./profile-sync-core";

export async function getCurrentClerkUserId() {
  const { userId } = await auth();

  return userId;
}

export async function getCurrentClerkUser() {
  return currentUser();
}

export async function getCurrentClerkIdentity() {
  const user = await getCurrentClerkUser();

  if (!user) {
    return null;
  }

  return normalizeClerkIdentity(user);
}
