import type { ReactNode } from "react";
import {
  AdminDetailPanel,
  AdminFilterBar,
  AdminMetricCard,
  AdminQueueCard,
  AdminSidebar,
  AdminTable,
  AdminTopbar,
  AuditLogItem,
  ManualOverridePanel,
  WhatsAppTemplateCard
} from "@/components/admin";
import {
  CommissionCard,
  DeliveryOptionCard,
  OrderCard,
  OrderTimeline,
  PaymentMethodCard,
  PriceBreakdownCard,
  ProductCard,
  ProductDetailHero,
  ProductListItem,
  ProfitCalculatorCard,
  PromotionCard,
  RiskScoreCard,
  SettlementCard,
  StockStatusCard,
  TrendingInsightCard,
  WalletCard
} from "@/components/marketplace";
import {
  Alert,
  Avatar,
  Button,
  Card,
  Checkbox,
  EmptyState,
  ErrorState,
  FileUploadCard,
  Input,
  LoadingState,
  ModalDrawerPlaceholder,
  RadioCard,
  SearchBar,
  Select,
  StatusBadge,
  Tabs,
  Textarea
} from "@/components/ui";
import { designTokens } from "@/lib/constants/design-tokens";
import { sampleAdminQueues, sampleAuditLogItems, sampleRiskActions, sampleWhatsAppTemplates } from "@/lib/mock/admin";
import { sampleCommissions, sampleSettlements, sampleWallet } from "@/lib/mock/finance";
import { sampleDeliveryOptions, sampleOrders, samplePaymentMethods, sampleTimelineEvents } from "@/lib/mock/orders";
import { sampleCustomers, sampleResellers, sampleSuppliers, sampleTeamMembers } from "@/lib/mock/people";
import { sampleProducts, sampleStockStates, sampleVariants } from "@/lib/mock/products";
import { sampleInsights, samplePromotions } from "@/lib/mock/promotions";
import { statusCatalog } from "@/lib/status/status-definitions";

const colorRows = [
  ["Primary Green", designTokens.colors.primary],
  ["Secondary Green", designTokens.colors.secondary],
  ["Amber Accent", designTokens.colors.accent],
  ["Cream", designTokens.colors.cream],
  ["Light Gray", designTokens.colors.page],
  ["Charcoal", designTokens.colors.charcoal]
];

const spacingRows = [
  ["Radius md", designTokens.radius.md],
  ["Radius lg", designTokens.radius.lg],
  ["Shadow sm", designTokens.shadows.sm],
  ["Shadow md", designTokens.shadows.md]
];

export default function DesignSystemPage() {
  const product = sampleProducts[0];
  const order = sampleOrders[0];
  const settlement = sampleSettlements[0];
  const commission = sampleCommissions[0];

  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-8 text-[var(--color-charcoal)] sm:px-6 lg:px-10">
      <div className="mx-auto max-w-7xl space-y-8">
        <header className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[var(--shadow-sm)]">
          <p className="text-sm font-bold uppercase text-[var(--color-primary)]">Risellar Phase 2</p>
          <h1 className="mt-3 text-3xl font-bold leading-tight">Component Library + Design-System Gallery</h1>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-[var(--color-muted)]">
            Frontend foundation only. This gallery refines reusable components for later PWA/mobile-first reseller,
            supplier, customer checkout, and desktop admin work without building real app screens.
          </p>
        </header>

        <GallerySection title="1. Brand Colors">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-6">
            {colorRows.map(([label, value]) => (
              <Card key={label}>
                <div className="h-16 rounded-[var(--radius-md)]" style={{ backgroundColor: value }} />
                <p className="mt-3 text-sm font-bold">{label}</p>
                <p className="text-xs text-[var(--color-muted)]">{value}</p>
              </Card>
            ))}
          </div>
        </GallerySection>

        <GallerySection title="2. Typography">
          <Card>
            <p className="text-sm font-semibold text-[var(--color-primary)]">Plus Jakarta Sans direction</p>
            <h2 className="mt-2 text-3xl font-bold">Pick. Share. Sell. Earn.</h2>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
              Calm marketplace UI with confident financial figures, compact labels, and clear hierarchy for Ghanaian
              reseller, supplier, customer, and admin workflows.
            </p>
          </Card>
        </GallerySection>

        <GallerySection title="3. Spacing / Radius / Shadows">
          <div className="grid gap-4 md:grid-cols-4">
            {spacingRows.map(([label, value]) => (
              <Card key={label}>
                <p className="text-sm font-bold">{label}</p>
                <p className="mt-2 text-xs text-[var(--color-muted)]">{value}</p>
              </Card>
            ))}
          </div>
        </GallerySection>

        <GallerySection title="4. Buttons">
          <div className="flex flex-wrap gap-3">
            <Button size="large">Primary large</Button>
            <Button variant="secondary">Secondary</Button>
            <Button variant="outline">Outline</Button>
            <Button variant="ghost">Ghost</Button>
            <Button variant="danger">Danger</Button>
            <Button variant="soft-warning">Soft warning</Button>
            <Button size="compact">Compact</Button>
            <Button size="table-action" variant="outline">
              View
            </Button>
            <Button loading>Loading</Button>
            <Button disabled>Disabled</Button>
          </div>
        </GallerySection>

        <GallerySection title="5. Forms and Inputs">
          <div className="grid gap-4 lg:grid-cols-3">
            <Card title="Text controls">
              <div className="space-y-3">
                <Input aria-label="Phone number" defaultValue="+233 24 123 4567" />
                <Input aria-label="Invalid settlement amount" defaultValue="GH₵0" state="error" />
                <Input aria-label="Verified account name" defaultValue="Ama Serwaa" state="success" />
                <Select aria-label="Payment method" defaultValue="momo">
                  <option value="momo">MTN MoMo</option>
                  <option value="cash">Pay on Delivery</option>
                </Select>
                <Textarea aria-label="Delivery note" defaultValue="Call me on arrival. I will be around." />
              </div>
            </Card>
            <Card title="Selection controls">
              <div className="space-y-3">
                <label className="flex items-center gap-2 text-sm">
                  <Checkbox defaultChecked /> Save as default delivery address
                </label>
                <RadioCard description="Customer pays when the item arrives." selected title="Pay on Delivery" />
                <SearchBar />
              </div>
            </Card>
            <Card title="Upload and shell">
              <FileUploadCard hint="PNG, JPG or PDF. Max 5MB." label="Upload proof of settlement" />
              <div className="mt-3">
                <ModalDrawerPlaceholder />
              </div>
            </Card>
          </div>
        </GallerySection>

        <GallerySection title="6. Badges and Statuses">
          <div className="grid gap-4 lg:grid-cols-3">
            {Object.entries(statusCatalog).map(([domain, statuses]) => (
              <Card key={domain} title={`${domain[0].toUpperCase()}${domain.slice(1)} statuses`}>
                <div className="flex flex-wrap gap-2">
                  {statuses.slice(0, 9).map((status) => (
                    <StatusBadge key={`${domain}-${status.label}`} status={status.label} />
                  ))}
                </div>
              </Card>
            ))}
          </div>
        </GallerySection>

        <GallerySection title="7. Cards">
          <div className="grid gap-4 md:grid-cols-3">
            <Card title="Trust card">
              <p className="text-sm text-[var(--color-muted)]">100% trusted marketplace with verified suppliers.</p>
            </Card>
            <Alert title="Settlement overdue requires attention" tone="danger" />
            <Card title="Avatar">
              <Avatar name="Kofi Mensah" />
            </Card>
          </div>
        </GallerySection>

        <GallerySection title="8. Product and Marketplace Components">
          <div className="grid gap-4 lg:grid-cols-[1.2fr_1fr]">
            <ProductDetailHero
              category={product.category}
              customerPrice={product.customerPrice}
              name={product.name}
              resellerMargin={product.resellerMargin}
              status={product.tag}
              stock={product.stock}
              supplierBasePrice={product.supplierBasePrice}
            />
            <div className="grid gap-4 sm:grid-cols-2">
              <ProductCard name={product.name} price={product.customerPrice} status={product.tag} />
              <ProductListItem name={sampleProducts[2].name} price={sampleProducts[2].customerPrice} stock={sampleProducts[2].stock} />
            </div>
          </div>
        </GallerySection>

        <GallerySection title="9. Price / Profit / Commission Components">
          <div className="grid gap-4 md:grid-cols-3">
            <PriceBreakdownCard
              customerPrice={product.customerPrice}
              platformMargin={product.platformMargin}
              resellerMargin={product.resellerMargin}
              supplierBasePrice={product.supplierBasePrice}
            />
            <ProfitCalculatorCard />
            <CommissionCard amount={commission.amount} />
          </div>
        </GallerySection>

        <GallerySection title="10. Stock and Inventory Components">
          <div className="grid gap-4 md:grid-cols-3">
            <StockStatusCard />
            <Card title="Variant stock">
              <div className="space-y-3 text-sm">
                {sampleVariants.map((variant) => (
                  <Row key={variant.name} label={variant.name} value={`${variant.stock} units`} badge={variant.status} />
                ))}
              </div>
            </Card>
            <Card title="Stock states">
              <div className="flex flex-wrap gap-2">
                {sampleStockStates.map((status) => (
                  <StatusBadge key={status} status={status} />
                ))}
              </div>
            </Card>
          </div>
        </GallerySection>

        <GallerySection title="11. Orders and Timeline Components">
          <div className="grid gap-4 md:grid-cols-3">
            <OrderCard id={order.id} status={order.status} total={order.total} />
            <Card title="Timeline">
              <OrderTimeline />
            </Card>
            <Card title="Timeline data">
              <div className="space-y-3 text-sm">
                {sampleTimelineEvents.slice(0, 4).map((event) => (
                  <Row key={event.label} label={event.label} value={event.time} badge={event.status} />
                ))}
              </div>
            </Card>
          </div>
        </GallerySection>

        <GallerySection title="12. Delivery and Payment Components">
          <div className="grid gap-4 md:grid-cols-4">
            <DeliveryOptionCard />
            <PaymentMethodCard />
            {sampleDeliveryOptions.map((option) => (
              <Card key={option.name} title={option.name}>
                <p className="text-lg font-bold text-[var(--color-primary)]">{option.price}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{option.timing}</p>
                <div className="mt-3">
                  <StatusBadge status={option.status} />
                </div>
              </Card>
            ))}
            {samplePaymentMethods.map((method) => (
              <Card key={method.name} title={method.name}>
                <p className="text-sm text-[var(--color-muted)]">{method.detail}</p>
                <div className="mt-3">
                  <StatusBadge status={method.status} />
                </div>
              </Card>
            ))}
          </div>
        </GallerySection>

        <GallerySection title="13. Settlement and Wallet Components">
          <div className="grid gap-4 md:grid-cols-3">
            <SettlementCard amount={settlement.dueAmount} />
            <WalletCard balance={sampleWallet.availableBalance} />
            <Card title="Settlement breakdown">
              <div className="space-y-3 text-sm">
                <Row label="Supplier" value={settlement.supplier} />
                <Row label="Due amount" value={settlement.dueAmount} badge={settlement.status} />
                <Row label="Reseller commission" value={settlement.resellerCommission} />
              </div>
            </Card>
          </div>
        </GallerySection>

        <GallerySection title="14. Promotions and Insights Components">
          <div className="grid gap-4 md:grid-cols-3">
            <PromotionCard />
            <TrendingInsightCard />
            <Card title="Promotion queue">
              <div className="space-y-3 text-sm">
                {samplePromotions.map((promotion) => (
                  <Row key={promotion.title} label={promotion.title} value={promotion.budget} badge={promotion.label} />
                ))}
              </div>
            </Card>
            {sampleInsights.map((insight) => (
              <Card key={insight.title} title={insight.title}>
                <p className="text-lg font-bold text-[var(--color-primary)]">{insight.metric}</p>
                <div className="mt-3">
                  <StatusBadge status={insight.status} />
                </div>
              </Card>
            ))}
          </div>
        </GallerySection>

        <GallerySection title="15. Admin Components">
          <div className="grid gap-4 lg:grid-cols-[220px_1fr]">
            <AdminSidebar />
            <div className="space-y-4">
              <AdminTopbar />
              <div className="grid gap-4 md:grid-cols-4">
                <AdminMetricCard label="Today's Orders" trend="+18.6%" value="1,248" />
                <AdminMetricCard label="Settlement Due" trend="+12%" value="GH₵27,650" />
                <AdminQueueCard count={sampleAdminQueues[0].count} status={sampleAdminQueues[0].status} title={sampleAdminQueues[0].title} />
                <AdminQueueCard count={sampleAdminQueues[1].count} status={sampleAdminQueues[1].status} title={sampleAdminQueues[1].title} />
              </div>
              <AdminFilterBar />
              <AdminTable />
            </div>
          </div>
        </GallerySection>

        <GallerySection title="16. Risk / Audit / Manual Override Components">
          <div className="grid gap-4 md:grid-cols-3">
            <RiskScoreCard />
            <ManualOverridePanel />
            <AdminDetailPanel />
            <AuditLogItem />
            <WhatsAppTemplateCard />
            <Card title="Risk actions">
              <div className="space-y-3 text-sm">
                {sampleRiskActions.map((action) => (
                  <Row key={action.label} label={action.label} value={action.value} badge={action.status} />
                ))}
              </div>
            </Card>
            <Card title="Audit log data">
              <div className="space-y-3 text-sm">
                {sampleAuditLogItems.map((item) => (
                  <Row key={`${item.actor}-${item.time}`} label={`${item.actor}: ${item.action}`} value={item.time} />
                ))}
              </div>
            </Card>
            <Card title="WhatsApp templates">
              <div className="space-y-3 text-sm">
                {sampleWhatsAppTemplates.map((template) => (
                  <Row key={template.title} label={template.title} value={template.channel} />
                ))}
              </div>
            </Card>
          </div>
        </GallerySection>

        <GallerySection title="17. Empty / Error / Loading States">
          <div className="grid gap-4 md:grid-cols-3">
            <EmptyState action="Add Products" description="Add products to your shop and start receiving orders." title="Your shop is empty" />
            <ErrorState description="This product is currently unavailable. You can be notified when it is back." title="Product Out of Stock" />
            <LoadingState />
          </div>
        </GallerySection>

        <GallerySection title="18. Responsive Examples">
          <div className="grid gap-4 lg:grid-cols-[360px_1fr]">
            <Card title="Mobile-first PWA card">
              <div className="mx-auto max-w-[320px] rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-md)]">
                <ProductCard name={product.name} price={product.customerPrice} status={product.stock} />
              </div>
            </Card>
            <Card title="Desktop admin density">
              <AdminTable />
            </Card>
          </div>
          <div className="mt-4 grid gap-4 md:grid-cols-3">
            {sampleSuppliers.map((supplier) => (
              <Card key={supplier.name} title={supplier.name}>
                <p className="text-sm text-[var(--color-muted)]">{supplier.location}</p>
                <StatusBadge status={supplier.status} />
              </Card>
            ))}
            {sampleResellers.slice(0, 1).map((reseller) => (
              <Card key={reseller.name} title={reseller.name}>
                <p className="text-sm text-[var(--color-muted)]">{reseller.area}</p>
                <StatusBadge status={reseller.status} />
              </Card>
            ))}
            {sampleCustomers.slice(0, 1).map((customer) => (
              <Card key={customer.name} title={customer.name}>
                <p className="text-sm text-[var(--color-muted)]">{customer.deliveryArea}</p>
              </Card>
            ))}
            {sampleTeamMembers.map((member) => (
              <Card key={member.name} title={member.name}>
                <p className="text-sm font-semibold text-[var(--color-primary)]">{member.role}</p>
                <StatusBadge status={member.status} />
              </Card>
            ))}
          </div>
          <div className="mt-4">
            <Tabs active="All" items={["All", "Due", "Overdue", "Paid"]} />
          </div>
        </GallerySection>
      </div>
    </main>
  );
}

function GallerySection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h2 className="mb-4 text-xl font-bold">{title}</h2>
      {children}
    </section>
  );
}

function Row({ badge, label, value }: { badge?: string; label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="flex shrink-0 items-center gap-2 font-bold">
        {value}
        {badge ? <StatusBadge status={badge} /> : null}
      </span>
    </div>
  );
}
