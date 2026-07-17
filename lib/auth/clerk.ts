import "server-only";

import { auth, currentUser } from "@clerk/nextjs/server";

export async function getCurrentClerkUserId() {
  const { userId } = await auth();

  return userId;
}

export async function getCurrentClerkUser() {
  return currentUser();
}
