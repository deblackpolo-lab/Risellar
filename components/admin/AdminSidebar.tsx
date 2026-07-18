"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ComponentType, ReactNode } from "react";
import { useState } from "react";
import {
  AlertTriangle,
  BadgeDollarSign,
  Banknote,
  Bell,
  ClipboardList,
  FileClock,
  LayoutDashboard,
  LifeBuoy,
  ListChecks,
  LogOut,
  Megaphone,
  MessageSquareWarning,
  Package,
  PanelLeftClose,
  PanelLeftOpen,
  ReceiptText,
  RotateCcw,
  Settings,
  ShieldAlert,
  ShieldCheck,
  Store,
  UserCheck,
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
  { label: "Onboarding Requests", href: "/admin/onboarding-requests", icon: UserCheck },
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
  userRole = "Operations Manager"
}: {
  active?: string;
  children: ReactNode;
  searchPlaceholder?: string;
  userRole?: string;
}) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className="min-h-screen bg-[linear-gradient(180deg,var(--color-page)_0%,#F8FAF7_44%,var(--color-page)_100%)] p-4 text-[var(--color-charcoal)] lg:p-6">
      <div className="flex min-h-[calc(100vh-3rem)] gap-5">
        <aside
          className={cn(
            "sticky top-6 hidden h-[calc(100vh-3rem)] shrink-0 flex-col overflow-hidden rounded-[var(--radius-xl)] bg-[linear-gradient(180deg,var(--color-primary-dark),#063D30)] text-white shadow-[0_18px_54px_rgba(6,104,79,0.22)] transition-[width] duration-200 ease-in-out lg:flex",
            collapsed ? "w-[5.25rem]" : "w-[18.5rem]"
          )}
        >
          <button
            aria-label={collapsed ? "Expand admin sidebar" : "Collapse admin sidebar"}
            aria-pressed={collapsed}
            className="flex w-full items-center gap-3 border-b border-white/10 p-5 text-left transition hover:bg-white/5 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white/35"
            onClick={() => setCollapsed((value) => !value)}
            type="button"
          >
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[var(--radius-md)] bg-white/10 text-lg font-extrabold text-[var(--color-accent)] ring-1 ring-white/15">
              R
            </span>
            <span className={cn("min-w-0 flex-1 transition-opacity duration-150", collapsed && "pointer-events-none opacity-0")}>
              <span className="block text-2xl font-bold leading-tight">Risellar</span>
              <span className="mt-1 block text-sm font-semibold text-[var(--color-accent)]">Admin Control</span>
            </span>
            <span className={cn("grid h-8 w-8 shrink-0 place-items-center rounded-full bg-white/10 text-white/80", collapsed && "hidden")}>
              <PanelLeftClose className="h-4 w-4" aria-hidden />
            </span>
            <PanelLeftOpen className={cn("h-4 w-4 shrink-0 text-white/80", !collapsed && "hidden")} aria-hidden />
          </button>

          <nav aria-label="Admin navigation" className="scrollbar-none flex-1 space-y-1 overflow-y-auto px-3 py-4">
            {adminNavItems.map((item) => {
              const Icon = item.icon;
              const active = isActiveRoute(pathname, item.href);

              return (
                <Link
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "group relative flex min-h-11 items-center gap-3 rounded-[var(--radius-md)] px-3 text-sm font-semibold transition-[var(--transition-fast)] focus:outline-none focus:ring-2 focus:ring-white/35",
                    active ? "bg-white/15 text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08)]" : "text-white/78 hover:bg-white/10 hover:text-white",
                    collapsed && "justify-center px-0"
                  )}
                  href={item.href}
                  key={item.href}
                  title={collapsed ? item.label : undefined}
                >
                  <span className={cn("h-7 w-1 rounded-full", active && !collapsed ? "bg-[var(--color-accent)]" : "bg-transparent")} aria-hidden />
                  <span className={cn("grid h-8 w-8 shrink-0 place-items-center rounded-full", active ? "bg-white/12" : "bg-transparent group-hover:bg-white/10")}>
                    <Icon className="h-4 w-4" aria-hidden />
                  </span>
                  <span className={cn("truncate transition-opacity duration-150", collapsed && "sr-only")}>{item.label}</span>
                </Link>
              );
            })}
          </nav>

          <div className="border-t border-white/10 p-3">
            <button
              aria-label="Logout mock action"
              className={cn(
                "group flex min-h-11 w-full items-center gap-3 rounded-[var(--radius-md)] px-3 text-left text-sm font-semibold text-white/78 transition hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-white/35",
                collapsed && "justify-center px-0"
              )}
              title={collapsed ? "Logout" : undefined}
              type="button"
            >
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full group-hover:bg-white/10">
                <LogOut className="h-4 w-4" aria-hidden />
              </span>
              <span className={cn("truncate", collapsed && "sr-only")}>Logout</span>
            </button>
          </div>
        </aside>

        <main className="min-w-0 flex-1 space-y-5">
          <div className="flex flex-col gap-3 rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white/96 p-4 shadow-[0_12px_32px_rgba(18,28,28,0.05)] xl:flex-row xl:items-center xl:justify-between">
            <div className="w-full max-w-md">
              <SearchBar placeholder={searchPlaceholder} />
            </div>
            <div className="flex flex-wrap items-center gap-3 text-sm">
              <span className="inline-flex min-h-9 items-center gap-2 rounded-full border border-[var(--color-primary-soft)] bg-[var(--color-primary-subtle)] px-3 text-xs font-bold text-[var(--color-primary)]">
                <ShieldCheck className="h-4 w-4" aria-hidden />
                Frontend only
              </span>
              <button
                aria-label="View mock admin notifications"
                className="grid h-10 w-10 place-items-center rounded-full border border-[var(--color-border)] bg-white text-[var(--color-muted)] transition hover:border-[var(--color-primary)] hover:text-[var(--color-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]"
                type="button"
              >
                <Bell className="h-4 w-4" aria-hidden />
              </button>
              <div className="flex items-center gap-3 rounded-full border border-[var(--color-border)] bg-white px-2 py-1.5 shadow-[var(--shadow-sm)]">
                <div className="h-9 w-9 rounded-full bg-[var(--color-primary-soft)] text-center font-bold leading-9 text-[var(--color-primary)]">KA</div>
                <div className="pr-3">
                  <p className="font-bold leading-tight">Kwame Admin</p>
                  <p className="text-xs text-[var(--color-muted)]">{userRole}</p>
                </div>
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
    <aside className="flex h-[640px] w-72 flex-col overflow-hidden rounded-[var(--radius-xl)] bg-[linear-gradient(180deg,var(--color-primary-dark),#063D30)] text-white shadow-[0_18px_54px_rgba(6,104,79,0.22)]">
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
              className={cn("flex min-h-11 items-center gap-3 rounded-[var(--radius-md)] px-3 text-sm font-semibold transition-[var(--transition-fast)]", active ? "bg-white/15 text-white" : "text-white/78 hover:bg-white/10 hover:text-white")}
              href={item.href}
              key={item.href}
            >
              <span className={cn("h-7 w-1 rounded-full", active ? "bg-[var(--color-accent)]" : "bg-transparent")} aria-hidden />
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-white/8">
                <Icon className="h-4 w-4" aria-hidden />
              </span>
              <span className="truncate">{item.label}</span>
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-white/10 p-3">
        <button
          aria-label="Logout mock action"
          className="flex min-h-11 w-full items-center gap-3 rounded-[var(--radius-md)] px-3 text-sm font-semibold text-white/78 transition hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-white/35"
          type="button"
        >
          <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-white/8">
            <LogOut className="h-4 w-4" aria-hidden />
          </span>
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
}

export { adminNavItems };
