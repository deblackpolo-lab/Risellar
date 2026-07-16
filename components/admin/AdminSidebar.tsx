"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ComponentType, ReactNode } from "react";
import { useState } from "react";
import {
  AlertTriangle,
  BadgeDollarSign,
  Banknote,
  ClipboardList,
  FileClock,
  LayoutDashboard,
  LifeBuoy,
  ListChecks,
  Megaphone,
  MessageSquareWarning,
  Package,
  ReceiptText,
  RotateCcw,
  Settings,
  ShieldAlert,
  Store,
  UserRound,
  Users,
  WalletCards
} from "lucide-react";
import { SearchBar } from "@/components/ui/SearchBar";
import { cn } from "@/lib/utils/cn";

type AdminNavItem = {
  href: string;
  icon: ComponentType<{ className?: string; "aria-hidden"?: boolean }>;
  label: string;
};

const adminNavItems: AdminNavItem[] = [
  { label: "Dashboard", href: "/admin/dashboard", icon: LayoutDashboard },
  { label: "Operations", href: "/admin/operations", icon: ListChecks },
  { label: "Orders", href: "/admin/orders", icon: ClipboardList },
  { label: "Products", href: "/admin/products", icon: Package },
  { label: "Suppliers", href: "/admin/suppliers", icon: Store },
  { label: "Resellers", href: "/admin/resellers", icon: Users },
  { label: "Customers", href: "/admin/customers", icon: UserRound },
  { label: "Settlements", href: "/admin/settlements", icon: WalletCards },
  { label: "Commissions", href: "/admin/commissions", icon: BadgeDollarSign },
  { label: "Withdrawals", href: "/admin/withdrawals", icon: Banknote },
  { label: "Promotions", href: "/admin/promotions", icon: Megaphone },
  { label: "Support", href: "/admin/support", icon: LifeBuoy },
  { label: "Disputes", href: "/admin/disputes", icon: MessageSquareWarning },
  { label: "Returns", href: "/admin/returns", icon: RotateCcw },
  { label: "Refunds", href: "/admin/refunds", icon: ReceiptText },
  { label: "Risk", href: "/admin/risk", icon: ShieldAlert },
  { label: "Audit Logs", href: "/admin/audit-logs", icon: FileClock },
  { label: "Manual Overrides", href: "/admin/manual-overrides", icon: AlertTriangle },
  { label: "Settings", href: "/admin/settings", icon: Settings }
];

function isActiveRoute(pathname: string | null, href: string) {
  if (!pathname) return false;
  if (href === "/admin/dashboard") return pathname === href || pathname === "/admin";
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function AdminShell({
  children,
  searchPlaceholder = "Search orders, queues, risks, suppliers...",
  statusDescription = "Mock-only admin workspace. No integrations, payment actions, or verification workflow are connected.",
  statusTitle = "Operations status",
  userRole = "Operations Manager"
}: {
  active?: string;
  children: ReactNode;
  searchPlaceholder?: string;
  statusDescription?: string;
  statusTitle?: string;
  userRole?: string;
}) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className="min-h-screen bg-[var(--color-page)] p-4 text-[var(--color-charcoal)] lg:p-6">
      <div className="flex min-h-[calc(100vh-3rem)] gap-5">
        <aside
          className={cn(
            "sticky top-6 hidden h-[calc(100vh-3rem)] shrink-0 flex-col overflow-hidden rounded-[var(--radius-lg)] bg-[var(--color-primary-dark)] text-white shadow-[var(--shadow-md)] transition-[width] duration-200 ease-in-out lg:flex",
            collapsed ? "w-20" : "w-72"
          )}
        >
          <button
            aria-label={collapsed ? "Expand admin sidebar" : "Collapse admin sidebar"}
            aria-pressed={collapsed}
            className="flex w-full items-center gap-3 border-b border-white/10 p-5 text-left transition hover:bg-white/5 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white/35"
            onClick={() => setCollapsed((value) => !value)}
            type="button"
          >
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-[var(--radius-md)] bg-white/10 text-lg font-extrabold text-[var(--color-accent)]">
              R
            </span>
            <span className={cn("min-w-0 transition-opacity duration-150", collapsed && "pointer-events-none opacity-0")}>
              <span className="block text-2xl font-bold leading-tight">Risellar</span>
              <span className="mt-1 block text-sm font-semibold text-[var(--color-accent)]">Admin Control</span>
            </span>
          </button>

          <nav aria-label="Admin navigation" className="scrollbar-none flex-1 space-y-1 overflow-y-auto px-3 py-4">
            {adminNavItems.map((item) => {
              const Icon = item.icon;
              const active = isActiveRoute(pathname, item.href);

              return (
                <Link
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "group flex min-h-11 items-center gap-3 rounded-[var(--radius-md)] px-3 text-sm font-semibold transition-[var(--transition-fast)] focus:outline-none focus:ring-2 focus:ring-white/35",
                    active ? "bg-white/15 text-white" : "text-white/78 hover:bg-white/10 hover:text-white",
                    collapsed && "justify-center px-0"
                  )}
                  href={item.href}
                  key={item.href}
                  title={collapsed ? item.label : undefined}
                >
                  <Icon className="h-4 w-4 shrink-0" aria-hidden />
                  <span className={cn("truncate transition-opacity duration-150", collapsed && "sr-only")}>{item.label}</span>
                </Link>
              );
            })}
          </nav>

          <div className={cn("m-4 rounded-[var(--radius-md)] border border-white/15 bg-white/10 p-4 transition-opacity", collapsed && "hidden")}>
            <p className="text-sm font-bold">{statusTitle}</p>
            <p className="mt-2 text-xs leading-5 text-white/80">{statusDescription}</p>
          </div>
        </aside>

        <main className="min-w-0 flex-1 space-y-5">
          <div className="flex flex-col gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)] xl:flex-row xl:items-center xl:justify-between">
            <SearchBar placeholder={searchPlaceholder} />
            <div className="flex items-center gap-3 text-sm">
              <div className="h-10 w-10 rounded-full bg-[var(--color-primary-soft)] text-center font-bold leading-10 text-[var(--color-primary)]">KA</div>
              <div>
                <p className="font-bold">Kwame Admin</p>
                <p className="text-xs text-[var(--color-muted)]">{userRole}</p>
              </div>
            </div>
          </div>
          {children}
        </main>
      </div>
    </div>
  );
}

export function AdminSidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-[640px] w-72 flex-col overflow-hidden rounded-[var(--radius-lg)] bg-[var(--color-primary-dark)] text-white shadow-[var(--shadow-md)]">
      <div className="flex items-center gap-3 border-b border-white/10 p-5">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-[var(--radius-md)] bg-white/10 text-lg font-extrabold text-[var(--color-accent)]">R</span>
        <div>
          <p className="text-2xl font-bold leading-tight">Risellar</p>
          <p className="mt-1 text-sm font-semibold text-[var(--color-accent)]">Admin Control</p>
        </div>
      </div>
      <nav aria-label="Admin navigation preview" className="scrollbar-none flex-1 space-y-1 overflow-y-auto px-3 py-4">
        {adminNavItems.map((item) => {
          const Icon = item.icon;
          const active = isActiveRoute(pathname, item.href);

          return (
            <Link
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex min-h-11 items-center gap-3 rounded-[var(--radius-md)] px-3 text-sm font-semibold transition-[var(--transition-fast)]",
                active ? "bg-white/15 text-white" : "text-white/78 hover:bg-white/10 hover:text-white"
              )}
              href={item.href}
              key={item.href}
            >
              <Icon className="h-4 w-4 shrink-0" aria-hidden />
              <span className="truncate">{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}

export { adminNavItems };
