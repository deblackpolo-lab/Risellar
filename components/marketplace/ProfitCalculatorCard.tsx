import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";

export function ProfitCalculatorCard() {
  return (
    <Card title="Profit Calculator">
      <label className="text-sm font-semibold" htmlFor="selling-price">
        Selling price
      </label>
      <Input className="mt-2" defaultValue="GH₵340" id="selling-price" />
      <p className="mt-3 text-sm text-[var(--color-success)]">Estimated profit: GH₵30</p>
    </Card>
  );
}
