export function Avatar({ name }: { name: string }) {
  const initials = name
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="grid h-10 w-10 place-items-center rounded-full bg-[var(--color-primary)] text-sm font-bold text-white">
      {initials}
    </div>
  );
}
