import "server-only";

import { createClient } from "@supabase/supabase-js";

function requireAdminEnv(name: "NEXT_PUBLIC_SUPABASE_URL" | "SUPABASE_SERVICE_ROLE_KEY") {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing ${name}. Add it to .env.local before using Supabase admin helpers.`);
  }

  return value;
}

export function createSupabaseAdminClient() {
  // Server-only: never import this helper into client components or browser code.
  return createClient(
    requireAdminEnv("NEXT_PUBLIC_SUPABASE_URL"),
    requireAdminEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }
  );
}
