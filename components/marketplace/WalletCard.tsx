import { Card } from "@/components/ui/Card";

export function WalletCard({ balance = "Available Balance GH₵240" }: { balance?: string }) {
  return (
    <Card className="!bg-[var(--color-primary)] text-white">
      <p className="text-sm text-white/80">Wallet</p>
      <p className="mt-2 text-2xl font-bold">{balance}</p>
    </Card>
  );
}
