import { Search } from "lucide-react";
import { Input } from "./Input";

export function SearchBar({ placeholder = "Search products..." }: { placeholder?: string }) {
  return (
    <label className="relative block">
      <span className="sr-only">{placeholder}</span>
      <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-muted)]" />
      <Input className="pl-10" placeholder={placeholder} />
    </label>
  );
}
