const steps = ["Order placed", "Awaiting confirmation", "Delivery quote pending", "Preparing"];

export function OrderTimeline() {
  return (
    <ol className="space-y-3">
      {steps.map((step, index) => (
        <li className="flex gap-3 text-sm" key={step}>
          <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-[var(--color-primary)] text-xs font-bold text-white">
            {index + 1}
          </span>
          <span className={index === 1 ? "font-semibold text-[var(--color-warning)]" : "text-[var(--color-muted)]"}>{step}</span>
        </li>
      ))}
    </ol>
  );
}
