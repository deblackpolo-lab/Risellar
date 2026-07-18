"use client";

import { useState } from "react";
import { useClerk } from "@clerk/nextjs";
import { LogOut } from "lucide-react";
import { Button } from "@/components/ui";

export function AccountSignOutButton({
  ariaLabel,
  className,
  label = "Sign out"
}: {
  ariaLabel?: string;
  className?: string;
  label?: string;
}) {
  const { signOut } = useClerk();
  const [isSigningOut, setIsSigningOut] = useState(false);

  async function handleSignOut() {
    setIsSigningOut(true);
    await signOut({ redirectUrl: "/sign-in" });
  }

  return (
    <Button aria-label={ariaLabel} className={className} disabled={isSigningOut} onClick={() => void handleSignOut()} type="button" variant="outline">
      <LogOut className="h-4 w-4" aria-hidden="true" />
      {isSigningOut ? "Signing out..." : label}
    </Button>
  );
}
