const items = ["Overview", "Orders", "Products", "Settlements", "Risk"];

export function AdminSidebar() {
  return (
    <aside className="rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-4 text-white">
      <div className="text-lg font-bold">Risellar</div>
      <nav className="mt-5 space-y-1">
        {items.map((item) => (
          <div className="rounded-[var(--radius-md)] px-3 py-2 text-sm font-medium text-white/85 first:bg-white/15 first:text-white" key={item}>
            {item}
          </div>
        ))}
      </nav>
    </aside>
  );
}
