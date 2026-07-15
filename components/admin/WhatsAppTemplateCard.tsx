import { MessageCircle } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

export function WhatsAppTemplateCard() {
  return (
    <Card title="WhatsApp Template">
      <MessageCircle className="h-5 w-5 text-[var(--color-primary)]" aria-hidden />
      <p className="mt-3 text-sm text-[var(--color-muted)]">Manual helper copy for customer confirmation or settlement follow-up.</p>
      <Button className="mt-4" type="button" variant="outline">
        Copy Template
      </Button>
    </Card>
  );
}
