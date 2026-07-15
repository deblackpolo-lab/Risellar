import { AlertCircle } from "lucide-react";
import { Button } from "./Button";

export function ErrorState({ title, description }: { title: string; description: string }) {
  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)] p-6 text-center">
      <AlertCircle className="mx-auto h-9 w-9 text-[var(--color-danger)]" aria-hidden />
      <h3 className="mt-3 text-base font-bold">{title}</h3>
      <p className="mx-auto mt-2 max-w-sm text-sm text-[var(--color-muted)]">{description}</p>
      <Button className="mt-4" type="button" variant="outline">
        Review details
      </Button>
    </div>
  );
}
