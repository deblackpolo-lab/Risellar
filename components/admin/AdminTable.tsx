import { StatusBadge } from "@/components/ui/StatusBadge";

const rows = [
  ["RSR-8842", "Ama Serwaa", "Awaiting Confirmation", "GH₵340"],
  ["RSR-8799", "Kofi Appiah", "Settlement Due", "GH₵40"],
  ["RSR-8890", "Esi Owusu", "Supplier Restricted", "GH₵310"]
];

export function AdminTable() {
  return (
    <div className="overflow-hidden rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white shadow-[var(--shadow-sm)]">
      <table className="w-full text-left text-sm">
        <thead className="bg-[var(--color-muted-soft)] text-xs uppercase text-[var(--color-muted)]">
          <tr>
            <th className="px-4 py-3">Order</th>
            <th className="px-4 py-3">Customer</th>
            <th className="px-4 py-3">Status</th>
            <th className="px-4 py-3">Amount</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr className="border-t border-[var(--color-border)]" key={row[0]}>
              {row.map((cell, index) => (
                <td className="px-4 py-3" key={cell}>
                  {index === 2 ? <StatusBadge status={cell} /> : cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
