import { Box } from "lucide-react";
import { Button } from "./Button";

export function EmptyState({ title, description, action = "Get started" }: { title: string; description: string; action?: string }) {
  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-6 text-center shadow-[var(--shadow-sm)]">
      <Box className="mx-auto h-9 w-9 text-[var(--color-primary)]" aria-hidden />
      <h3 className="mt-3 text-base font-bold">{title}</h3>
      <p className="mx-auto mt-2 max-w-sm text-sm text-[var(--color-muted)]">{description}</p>
      <Button className="mt-4" type="button">
        {action}
      </Button>
    </div>
  );
}
