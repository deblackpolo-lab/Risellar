import { Upload } from "lucide-react";

export function FileUploadCard({ label = "Tap to upload", hint = "PNG, JPG or PDF" }: { label?: string; hint?: string }) {
  return (
    <div className="flex min-h-32 flex-col items-center justify-center rounded-[var(--radius-lg)] border border-dashed border-[var(--color-border)] bg-[var(--color-primary-subtle)] p-5 text-center">
      <Upload className="h-6 w-6 text-[var(--color-primary)]" aria-hidden />
      <div className="mt-2 text-sm font-semibold">{label}</div>
      <div className="mt-1 text-xs text-[var(--color-muted)]">{hint}</div>
    </div>
  );
}
