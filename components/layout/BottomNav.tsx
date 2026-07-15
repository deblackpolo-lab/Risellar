import { cn } from "@/lib/utils/cn";

const navItems = [
  { href: "/reseller/dashboard", label: "Home" },
  { href: "/reseller/products", label: "Shop" },
  { href: "/reseller/orders", label: "Orders" },
  { href: "/reseller/wallet", label: "Wallet" },
  { href: "/reseller/settings", label: "Account" }
];

export function BottomNav({ active = "Home" }: { active?: string }) {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-[var(--z-header)] border-t border-[var(--color-border)] bg-white/95 px-4 pb-[calc(0.75rem+env(safe-area-inset-bottom))] pt-3 shadow-[var(--shadow-md)] backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-2">
        {navItems.map((item) => (
          <a
            aria-current={item.label === active ? "page" : undefined}
            className={cn(
              "flex min-h-11 min-w-0 flex-col items-center justify-center rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-focus-ring)]",
              item.label === active && "bg-[var(--color-primary-soft)] text-[var(--color-primary)]"
            )}
            href={item.href}
            key={item.label}
          >
            <span className="mb-1 h-1.5 w-1.5 rounded-full bg-current" aria-hidden="true" />
            {item.label}
          </a>
        ))}
      </div>
    </nav>
  );
}
