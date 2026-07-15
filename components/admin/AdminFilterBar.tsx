import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";

export function AdminFilterBar() {
  return (
    <div className="flex flex-wrap items-center gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)]">
      <Select className="max-w-44" defaultValue="all">
        <option value="all">All Statuses</option>
        <option value="pending">Pending</option>
      </Select>
      <Button type="button" variant="outline">
        Filter
      </Button>
    </div>
  );
}
