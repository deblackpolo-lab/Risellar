"use client";

import { useEffect, useState } from "react";
import { Home, PackageCheck, ReceiptText, UserRound, Wallet } from "lucide-react";
import { cn } from "@/lib/utils/cn";

const navItems = [
  { href: "/reseller/dashboard", icon: Home, label: "Home" },
  { href: "/reseller/products", icon: PackageCheck, label: "Products" },
  { href: "/reseller/orders", icon: ReceiptText, label: "Orders" },
  { href: "/reseller/wallet", icon: Wallet, label: "Wallet" },
  { href: "/reseller/settings", icon: UserRound, label: "Profile" }
];

const activeAliases: Record<string, string> = {
  Account: "Profile",
  "My products": "Products",
  Shop: "Products",
  Support: "Profile"
};

export function BottomNav({ active = "Home" }: { active?: string }) {
  const [pathname, setPathname] = useState("");

  useEffect(() => {
    setPathname(window.location.pathname);
  }, []);

  const activeLabel = inferActiveLabel(pathname) ?? activeAliases[active] ?? active;

  return (
    <nav className="fixed inset-x-0 bottom-0 z-[var(--z-header)] border-t border-[var(--color-border)] bg-white/95 px-4 pb-[calc(0.75rem+env(safe-area-inset-bottom))] pt-3 shadow-[var(--shadow-md)] backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-2">
        {navItems.map((item) => {
          const Icon = item.icon;
          const selected = item.label === activeLabel;

          return (
            <a
              aria-current={selected ? "page" : undefined}
              aria-label={item.label}
              className={cn(
                "flex min-h-12 min-w-0 flex-col items-center justify-center rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-focus-ring)]",
                selected && "bg-[var(--color-primary-soft)] text-[var(--color-primary)]"
              )}
              href={item.href}
              key={item.label}
            >
              <Icon className="mb-1 h-4 w-4" aria-hidden />
              <span className="truncate">{item.label}</span>
            </a>
          );
        })}
      </div>
    </nav>
  );
}

function inferActiveLabel(pathname: string) {
  if (pathname.startsWith("/reseller/products") || pathname.startsWith("/reseller/my-products")) return "Products";
  if (pathname.startsWith("/reseller/orders")) return "Orders";
  if (pathname.startsWith("/reseller/wallet") || pathname.startsWith("/reseller/withdraw") || pathname.startsWith("/reseller/earnings")) return "Wallet";
  if (pathname.startsWith("/reseller/settings") || pathname.startsWith("/reseller/support")) return "Profile";
  if (pathname.startsWith("/reseller/dashboard")) return "Home";
  return null;
}
