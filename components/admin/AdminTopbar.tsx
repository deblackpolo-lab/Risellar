import { SearchBar } from "@/components/ui/SearchBar";
import { Avatar } from "@/components/ui/Avatar";

export function AdminTopbar() {
  return (
    <div className="flex items-center justify-between gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)]">
      <SearchBar placeholder="Search orders, resellers, suppliers..." />
      <div className="flex items-center gap-3">
        <Avatar name="Admin User" />
        <div className="hidden text-sm sm:block">
          <div className="font-bold">Admin</div>
          <div className="text-[var(--color-muted)]">Operations</div>
        </div>
      </div>
    </div>
  );
}
