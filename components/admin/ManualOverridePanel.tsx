import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Textarea } from "@/components/ui/Textarea";

export function ManualOverridePanel() {
  return (
    <div className="space-y-3 rounded-[var(--radius-lg)] border border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)] p-4">
      <Alert title="Manual override requires reason and audit log" tone="danger" />
      <Textarea placeholder="Reason for override..." />
      <Button type="button" variant="danger">
        Apply Override
      </Button>
    </div>
  );
}
