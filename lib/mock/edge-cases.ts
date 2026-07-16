import type { ComponentType } from "react";
import {
  AlertTriangle,
  Ban,
  BellOff,
  Boxes,
  CheckCircle2,
  Clock3,
  CreditCard,
  FileQuestion,
  FileWarning,
  HelpCircle,
  Hourglass,
  Lock,
  MegaphoneOff,
  PackageCheck,
  PackageX,
  RefreshCcw,
  ShieldAlert,
  ShieldCheck,
  ShoppingBag,
  ShoppingCart,
  Signal,
  Sparkles,
  Store,
  Truck,
  UserX,
  Wallet,
  WifiOff,
  Wrench
} from "lucide-react";
import type { StatusTone } from "@/lib/status/status-tones";

export type EdgeCaseRole = "shared" | "customer" | "reseller" | "supplier" | "admin";
export type EdgeCaseKind =
  | "empty"
  | "error"
  | "loading"
  | "not-found"
  | "offline"
  | "permission"
  | "pending"
  | "restricted"
  | "suspended"
  | "failure"
  | "success"
  | "action"
  | "financial"
  | "stock"
  | "verification"
  | "settlement"
  | "commission"
  | "delivery";

export type EdgeCaseMetric = {
  label: string;
  value: string;
  status?: string;
};

export type EdgeCaseAction = {
  label: string;
  variant?: "primary" | "secondary" | "outline" | "ghost" | "danger" | "soft-warning";
};

export type EdgeCaseDefinition = {
  path: string;
  role: EdgeCaseRole;
  kind: EdgeCaseKind;
  title: string;
  description: string;
  status: string;
  tone: StatusTone;
  icon: ComponentType<{ className?: string; "aria-hidden"?: boolean }>;
  primaryAction: EdgeCaseAction;
  secondaryAction?: EdgeCaseAction;
  helperText?: string;
  metrics?: EdgeCaseMetric[];
  panelTitle?: string;
  panelItems?: string[];
};

export const requiredEdgeCasePaths = [
  "/edge-cases",
  "/edge-cases/loading",
  "/edge-cases/empty",
  "/edge-cases/error",
  "/edge-cases/not-found",
  "/edge-cases/offline",
  "/edge-cases/permission-denied",
  "/edge-cases/account-pending",
  "/edge-cases/account-restricted",
  "/edge-cases/account-suspended",
  "/edge-cases/customer/empty-cart",
  "/edge-cases/customer/no-orders",
  "/edge-cases/customer/awaiting-confirmation",
  "/edge-cases/customer/confirmation-expired",
  "/edge-cases/customer/delivery-quote-pending",
  "/edge-cases/customer/delivery-failed",
  "/edge-cases/customer/payment-failed",
  "/edge-cases/customer/product-out-of-stock",
  "/edge-cases/customer/product-reserved",
  "/edge-cases/customer/support-submitted",
  "/edge-cases/reseller/no-products",
  "/edge-cases/reseller/no-orders",
  "/edge-cases/reseller/no-commission",
  "/edge-cases/reseller/commission-pending",
  "/edge-cases/reseller/withdrawal-failed",
  "/edge-cases/reseller/product-out-of-stock",
  "/edge-cases/reseller/price-review-needed",
  "/edge-cases/reseller/shop-restricted",
  "/edge-cases/reseller/pro-locked",
  "/edge-cases/supplier/no-products",
  "/edge-cases/supplier/no-orders",
  "/edge-cases/supplier/product-pending-approval",
  "/edge-cases/supplier/product-rejected",
  "/edge-cases/supplier/verification-pending",
  "/edge-cases/supplier/verification-rejected",
  "/edge-cases/supplier/low-stock",
  "/edge-cases/supplier/out-of-stock",
  "/edge-cases/supplier/settlement-overdue",
  "/edge-cases/supplier/proof-submitted",
  "/edge-cases/supplier/restricted",
  "/edge-cases/supplier/promotion-paused",
  "/edge-cases/supplier/inventory-manager-access-denied",
  "/edge-cases/admin/no-orders",
  "/edge-cases/admin/empty-queue",
  "/edge-cases/admin/no-disputes",
  "/edge-cases/admin/no-audit-logs",
  "/edge-cases/admin/permission-denied",
  "/edge-cases/admin/manual-override-warning",
  "/edge-cases/admin/commission-release-blocked",
  "/edge-cases/admin/record-not-found"
] as const;

export const edgeCaseDefinitions: EdgeCaseDefinition[] = [
  {
    path: "/edge-cases",
    role: "shared",
    kind: "empty",
    title: "Empty States + Edge Cases",
    description: "Reusable mock-only Risellar states for every role and operational edge case.",
    status: "Preview Index",
    tone: "success",
    icon: Sparkles,
    primaryAction: { label: "Browse edge states" },
    helperText: "Internal preview section for frontend QA."
  },
  {
    path: "/edge-cases/loading",
    role: "shared",
    kind: "loading",
    title: "Loading Risellar data",
    description: "We are preparing the latest mock marketplace state for this preview.",
    status: "Loading",
    tone: "info",
    icon: Hourglass,
    primaryAction: { label: "Wait a moment", variant: "outline" },
    helperText: "Use skeletons for cards and tables. Avoid trapping the user."
  },
  {
    path: "/edge-cases/empty",
    role: "shared",
    kind: "empty",
    title: "Nothing here yet",
    description: "This space will fill up once activity starts.",
    status: "Empty",
    tone: "neutral",
    icon: Boxes,
    primaryAction: { label: "Browse products" },
    secondaryAction: { label: "Return to dashboard", variant: "outline" }
  },
  {
    path: "/edge-cases/error",
    role: "shared",
    kind: "error",
    title: "Something needs attention",
    description: "We could not show this mock state. Try again or contact support.",
    status: "Error",
    tone: "danger",
    icon: AlertTriangle,
    primaryAction: { label: "Try again", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/not-found",
    role: "shared",
    kind: "not-found",
    title: "Record not found",
    description: "This order, ticket, or product may have been removed from the mock preview.",
    status: "Not Found",
    tone: "neutral",
    icon: FileQuestion,
    primaryAction: { label: "Return to dashboard" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/offline",
    role: "shared",
    kind: "offline",
    title: "Network issue",
    description: "Check your connection and try again. Saved mock screens remain available in this preview.",
    status: "Offline",
    tone: "warning",
    icon: WifiOff,
    primaryAction: { label: "Try again", variant: "soft-warning" },
    secondaryAction: { label: "Go back", variant: "outline" }
  },
  {
    path: "/edge-cases/permission-denied",
    role: "shared",
    kind: "permission",
    title: "You do not have access",
    description: "This section is restricted to an approved owner, staff member, or admin role.",
    status: "Permission Denied",
    tone: "danger",
    icon: Lock,
    primaryAction: { label: "Request access", variant: "outline" },
    secondaryAction: { label: "Go back", variant: "ghost" }
  },
  {
    path: "/edge-cases/account-pending",
    role: "shared",
    kind: "pending",
    title: "Account review is pending",
    description: "We are checking your account details. You can keep browsing while review continues.",
    status: "Pending Review",
    tone: "warning",
    icon: Clock3,
    primaryAction: { label: "View status", variant: "soft-warning" },
    helperText: "Pending states should feel reassuring, not blocked."
  },
  {
    path: "/edge-cases/account-restricted",
    role: "shared",
    kind: "restricted",
    title: "Account restricted",
    description: "Some actions are limited until the issue is resolved.",
    status: "Restricted",
    tone: "danger",
    icon: ShieldAlert,
    primaryAction: { label: "Contact support", variant: "danger" },
    secondaryAction: { label: "Review policy", variant: "outline" }
  },
  {
    path: "/edge-cases/account-suspended",
    role: "shared",
    kind: "suspended",
    title: "Account suspended",
    description: "This account cannot sell, buy, or receive new orders at this time.",
    status: "Suspended",
    tone: "danger",
    icon: Ban,
    primaryAction: { label: "Contact support", variant: "danger" },
    secondaryAction: { label: "Review policy", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/empty-cart",
    role: "customer",
    kind: "empty",
    title: "Your cart is empty",
    description: "Browse trusted reseller shops and add products when you are ready.",
    status: "Empty Cart",
    tone: "neutral",
    icon: ShoppingCart,
    primaryAction: { label: "Browse products" },
    secondaryAction: { label: "Return to shop", variant: "outline" },
    metrics: [{ label: "Customer", value: "Nana Yaw" }]
  },
  {
    path: "/edge-cases/customer/no-orders",
    role: "customer",
    kind: "empty",
    title: "No orders yet",
    description: "When you place an order through a reseller shop, it will appear here.",
    status: "No Orders",
    tone: "neutral",
    icon: PackageCheck,
    primaryAction: { label: "Browse products" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/awaiting-confirmation",
    role: "customer",
    kind: "pending",
    title: "Confirm your order",
    description: "Please confirm within 1 hour so the reseller can reserve this item for you.",
    status: "Awaiting Confirmation",
    tone: "warning",
    icon: Clock3,
    primaryAction: { label: "Confirm order" },
    secondaryAction: { label: "Cancel order", variant: "outline" },
    metrics: [
      { label: "Order", value: "RSR-20260713-00021" },
      { label: "Product price", value: "GH₵340" }
    ]
  },
  {
    path: "/edge-cases/customer/confirmation-expired",
    role: "customer",
    kind: "failure",
    title: "Confirmation expired",
    description: "The item was released because the order was not confirmed in time.",
    status: "Expired",
    tone: "danger",
    icon: Clock3,
    primaryAction: { label: "Browse products" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/delivery-quote-pending",
    role: "customer",
    kind: "delivery",
    title: "Delivery quote pending",
    description: "We are confirming the final delivery fee before dispatch. You can approve or cancel when the quote is ready.",
    status: "Delivery Quote Pending",
    tone: "warning",
    icon: Truck,
    primaryAction: { label: "View order" },
    secondaryAction: { label: "Contact support", variant: "outline" },
    metrics: [
      { label: "Estimated delivery", value: "GH₵45" },
      { label: "Delivery area", value: "Madina, Accra" }
    ],
    helperText: "Delivery cost is separate from the product price."
  },
  {
    path: "/edge-cases/customer/delivery-failed",
    role: "customer",
    kind: "delivery",
    title: "Delivery was unsuccessful",
    description: "The rider could not reach you. Please update the delivery details or contact support.",
    status: "Delivery Failed",
    tone: "danger",
    icon: Truck,
    primaryAction: { label: "Update delivery details", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/payment-failed",
    role: "customer",
    kind: "failure",
    title: "Payment failed",
    description: "We could not process the online payment. You can try again or choose Pay on Delivery.",
    status: "Payment Failed",
    tone: "danger",
    icon: CreditCard,
    primaryAction: { label: "Try again", variant: "danger" },
    secondaryAction: { label: "Use Pay on Delivery", variant: "outline" },
    helperText: "Pay Online remains a placeholder in this frontend phase."
  },
  {
    path: "/edge-cases/customer/product-out-of-stock",
    role: "customer",
    kind: "stock",
    title: "This product is out of stock",
    description: "You cannot order this item right now. We can show similar products instead.",
    status: "Out of Stock",
    tone: "danger",
    icon: PackageX,
    primaryAction: { label: "View similar products" },
    secondaryAction: { label: "Contact support", variant: "outline" },
    metrics: [{ label: "Customer price", value: "GH₵340" }]
  },
  {
    path: "/edge-cases/customer/product-reserved",
    role: "customer",
    kind: "stock",
    title: "Someone just reserved this item",
    description: "If they do not confirm, it may become available again.",
    status: "Reserved",
    tone: "warning",
    icon: PackageCheck,
    primaryAction: { label: "Notify me", variant: "soft-warning" },
    secondaryAction: { label: "View similar products", variant: "outline" },
    metrics: [
      { label: "Product price", value: "GH₵340" },
      { label: "Stock status", value: "Reserved", status: "Reserved" }
    ]
  },
  {
    path: "/edge-cases/customer/support-submitted",
    role: "customer",
    kind: "success",
    title: "Support issue submitted",
    description: "Thanks. Our team will review your issue and update you here.",
    status: "Submitted",
    tone: "success",
    icon: CheckCircle2,
    primaryAction: { label: "View ticket" },
    secondaryAction: { label: "Copy support message", variant: "outline" },
    metrics: [{ label: "Ticket", value: "TKT-RSR-20260713-00021" }]
  },
  {
    path: "/edge-cases/reseller/no-products",
    role: "reseller",
    kind: "empty",
    title: "Your shop is empty",
    description: "Add trusted products to your shop and start receiving orders.",
    status: "No Products",
    tone: "neutral",
    icon: Store,
    primaryAction: { label: "Browse products" },
    secondaryAction: { label: "Learn how to sell", variant: "outline" },
    metrics: [{ label: "Shop", value: "Ama's Beauty Plug" }]
  },
  {
    path: "/edge-cases/reseller/no-orders",
    role: "reseller",
    kind: "empty",
    title: "No orders yet",
    description: "Share your shop or product links. Customer orders will appear here.",
    status: "No Orders",
    tone: "neutral",
    icon: ShoppingBag,
    primaryAction: { label: "Share my shop" },
    secondaryAction: { label: "Browse products", variant: "outline" }
  },
  {
    path: "/edge-cases/reseller/no-commission",
    role: "reseller",
    kind: "empty",
    title: "No commission yet",
    description: "Commissions appear after successful orders and verified supplier settlement.",
    status: "No Commission",
    tone: "neutral",
    icon: Wallet,
    primaryAction: { label: "Browse products" },
    secondaryAction: { label: "View orders", variant: "outline" }
  },
  {
    path: "/edge-cases/reseller/commission-pending",
    role: "reseller",
    kind: "commission",
    title: "Commission is still pending",
    description: "This commission is pending until the supplier settlement is verified.",
    status: "Commission Pending",
    tone: "warning",
    icon: Wallet,
    primaryAction: { label: "View order" },
    secondaryAction: { label: "Contact support", variant: "outline" },
    metrics: [
      { label: "Pending commission", value: "GH₵30", status: "Pending" },
      { label: "Supplier settlement", value: "Awaiting verification", status: "Awaiting Settlement" }
    ],
    helperText: "Pending commission is not withdrawable."
  },
  {
    path: "/edge-cases/reseller/withdrawal-failed",
    role: "reseller",
    kind: "failure",
    title: "Withdrawal failed",
    description: "We could not process your withdrawal. Check your MoMo details and try again.",
    status: "Withdrawal Failed",
    tone: "danger",
    icon: AlertTriangle,
    primaryAction: { label: "Try again", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" },
    metrics: [{ label: "Amount", value: "GH₵90" }]
  },
  {
    path: "/edge-cases/reseller/product-out-of-stock",
    role: "reseller",
    kind: "stock",
    title: "Product is out of stock",
    description: "This product is hidden from new customer orders until the supplier restocks.",
    status: "Out of Stock",
    tone: "danger",
    icon: PackageX,
    primaryAction: { label: "View similar products" },
    secondaryAction: { label: "Remove from shop", variant: "outline" }
  },
  {
    path: "/edge-cases/reseller/price-review-needed",
    role: "reseller",
    kind: "action",
    title: "Price review needed",
    description: "The supplier changed the base price. Review your selling price before sharing again.",
    status: "Needs Reseller Review",
    tone: "warning",
    icon: RefreshCcw,
    primaryAction: { label: "Review price", variant: "soft-warning" },
    metrics: [
      { label: "Current customer price", value: "GH₵340" },
      { label: "Suggested update", value: "GH₵360" }
    ]
  },
  {
    path: "/edge-cases/reseller/shop-restricted",
    role: "reseller",
    kind: "restricted",
    title: "Shop restricted",
    description: "Your shop is limited while Risellar reviews account activity.",
    status: "Restricted",
    tone: "danger",
    icon: ShieldAlert,
    primaryAction: { label: "Contact support", variant: "danger" },
    secondaryAction: { label: "Review policy", variant: "outline" }
  },
  {
    path: "/edge-cases/reseller/pro-locked",
    role: "reseller",
    kind: "permission",
    title: "Pro insights locked",
    description: "Complete successful orders to unlock advanced insights and caption tools.",
    status: "Pro Locked",
    tone: "warning",
    icon: Lock,
    primaryAction: { label: "Complete sales", variant: "soft-warning" },
    secondaryAction: { label: "Explore trending products", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/no-products",
    role: "supplier",
    kind: "empty",
    title: "No products added yet",
    description: "Add your first product so resellers can discover and sell it.",
    status: "No Products",
    tone: "neutral",
    icon: Boxes,
    primaryAction: { label: "Add product" },
    secondaryAction: { label: "Learn supplier rules", variant: "outline" },
    metrics: [{ label: "Supplier", value: "KNUST Gadgets" }]
  },
  {
    path: "/edge-cases/supplier/no-orders",
    role: "supplier",
    kind: "empty",
    title: "No orders yet",
    description: "Confirmed customer orders will appear here when resellers sell your products.",
    status: "No Orders",
    tone: "neutral",
    icon: PackageCheck,
    primaryAction: { label: "View products" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/product-pending-approval",
    role: "supplier",
    kind: "pending",
    title: "Product pending approval",
    description: "Admin is reviewing this product before resellers can add it to their shops.",
    status: "Pending Approval",
    tone: "warning",
    icon: Clock3,
    primaryAction: { label: "View product" },
    helperText: "Approval is mock-only in this frontend phase."
  },
  {
    path: "/edge-cases/supplier/product-rejected",
    role: "supplier",
    kind: "verification",
    title: "Product needs changes",
    description: "The product was rejected. Update the details and submit again.",
    status: "Rejected",
    tone: "danger",
    icon: FileWarning,
    primaryAction: { label: "Edit product", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/verification-pending",
    role: "supplier",
    kind: "verification",
    title: "Verification under review",
    description: "We are reviewing your business and Ghana Card details. This may take up to 24 hours.",
    status: "Verification Pending",
    tone: "warning",
    icon: ShieldCheck,
    primaryAction: { label: "View status", variant: "soft-warning" }
  },
  {
    path: "/edge-cases/supplier/verification-rejected",
    role: "supplier",
    kind: "verification",
    title: "More information required",
    description: "We could not verify your Ghana Card. Upload a clearer document to continue.",
    status: "More Info Required",
    tone: "danger",
    icon: ShieldAlert,
    primaryAction: { label: "Update information", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/low-stock",
    role: "supplier",
    kind: "stock",
    title: "Low stock alert",
    description: "This product is almost sold out. Restock soon to keep it visible.",
    status: "Only 1 left",
    tone: "warning",
    icon: AlertTriangle,
    primaryAction: { label: "Restock product", variant: "soft-warning" },
    metrics: [
      { label: "Available stock", value: "1", status: "Only 1 left" },
      { label: "Customer price", value: "GH₵340" }
    ]
  },
  {
    path: "/edge-cases/supplier/out-of-stock",
    role: "supplier",
    kind: "stock",
    title: "Product is out of stock",
    description: "This product is not visible for new reseller sales until stock is restored.",
    status: "Out of Stock",
    tone: "danger",
    icon: PackageX,
    primaryAction: { label: "Restock product", variant: "danger" },
    secondaryAction: { label: "View stock history", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/settlement-overdue",
    role: "supplier",
    kind: "settlement",
    title: "Settlement is overdue",
    description: "You have overdue settlements. Settle them to keep your products visible to resellers.",
    status: "Settlement Overdue",
    tone: "danger",
    icon: AlertTriangle,
    primaryAction: { label: "Settle now", variant: "danger" },
    secondaryAction: { label: "Upload proof placeholder", variant: "outline" },
    metrics: [
      { label: "Amount due", value: "GH₵40", status: "Overdue" },
      { label: "Order", value: "RSR-20260713-00021" }
    ],
    panelTitle: "Restriction risk",
    panelItems: ["Products may be hidden from reseller catalog.", "New orders can be blocked after repeated overdue settlements."]
  },
  {
    path: "/edge-cases/supplier/proof-submitted",
    role: "supplier",
    kind: "settlement",
    title: "Proof submitted",
    description: "Your settlement proof is awaiting admin finance verification.",
    status: "Proof Submitted",
    tone: "info",
    icon: FileQuestion,
    primaryAction: { label: "View settlement" },
    secondaryAction: { label: "Contact support", variant: "outline" },
    metrics: [{ label: "Amount due", value: "GH₵40", status: "Proof Submitted" }]
  },
  {
    path: "/edge-cases/supplier/restricted",
    role: "supplier",
    kind: "restricted",
    title: "Supplier account restricted",
    description: "New product visibility is limited until overdue settlements or verification issues are resolved.",
    status: "Supplier Restricted",
    tone: "danger",
    icon: ShieldAlert,
    primaryAction: { label: "Settle now", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/promotion-paused",
    role: "supplier",
    kind: "stock",
    title: "Promotion paused",
    description: "This promotion is paused because the product is out of stock.",
    status: "Paused",
    tone: "warning",
    icon: MegaphoneOff,
    primaryAction: { label: "Restock product", variant: "soft-warning" },
    secondaryAction: { label: "View promotion", variant: "outline" }
  },
  {
    path: "/edge-cases/supplier/inventory-manager-access-denied",
    role: "supplier",
    kind: "permission",
    title: "You do not have access to this page",
    description: "You do not have permission to edit payout or settlement settings. Ask the supplier owner for access.",
    status: "Access Denied",
    tone: "danger",
    icon: Lock,
    primaryAction: { label: "Request access", variant: "outline" },
    secondaryAction: { label: "Go back", variant: "ghost" },
    metrics: [{ label: "Inventory manager", value: "Akua Boateng" }]
  },
  {
    path: "/edge-cases/admin/no-orders",
    role: "admin",
    kind: "empty",
    title: "No orders today",
    description: "New order activity and support follow-ups will appear here.",
    status: "No Orders",
    tone: "neutral",
    icon: PackageCheck,
    primaryAction: { label: "View all orders" }
  },
  {
    path: "/edge-cases/admin/empty-queue",
    role: "admin",
    kind: "empty",
    title: "Queue is clear",
    description: "There are no pending approvals, disputes, or delivery items in this queue.",
    status: "Empty Queue",
    tone: "success",
    icon: CheckCircle2,
    primaryAction: { label: "View queue" }
  },
  {
    path: "/edge-cases/admin/no-disputes",
    role: "admin",
    kind: "empty",
    title: "No disputes",
    description: "Disputes will appear here when customers, resellers, or suppliers open a case.",
    status: "No Disputes",
    tone: "neutral",
    icon: HelpCircle,
    primaryAction: { label: "View support" }
  },
  {
    path: "/edge-cases/admin/no-audit-logs",
    role: "admin",
    kind: "empty",
    title: "No audit logs",
    description: "Audited admin actions will appear here once changes are made.",
    status: "No Audit Logs",
    tone: "neutral",
    icon: FileQuestion,
    primaryAction: { label: "Return to dashboard" }
  },
  {
    path: "/edge-cases/admin/permission-denied",
    role: "admin",
    kind: "permission",
    title: "Admin permission denied",
    description: "This action requires a higher admin role and an audit reason.",
    status: "Permission Denied",
    tone: "danger",
    icon: UserX,
    primaryAction: { label: "Request access", variant: "outline" },
    secondaryAction: { label: "Go back", variant: "ghost" }
  },
  {
    path: "/edge-cases/admin/manual-override-warning",
    role: "admin",
    kind: "action",
    title: "Manual override is restricted",
    description: "Manual overrides affect money, stock, or account status. A reason and audit log are required.",
    status: "Override Disabled",
    tone: "danger",
    icon: Wrench,
    primaryAction: { label: "Enter reason", variant: "danger" },
    secondaryAction: { label: "View audit log", variant: "outline" },
    panelTitle: "A reason and audit log are required.",
    panelItems: ["Money, stock, and account status changes must be reviewed.", "This is a mock-only warning. No real override is connected."]
  },
  {
    path: "/edge-cases/admin/commission-release-blocked",
    role: "admin",
    kind: "financial",
    title: "Commission release blocked",
    description: "Release is blocked until supplier settlement verification is complete.",
    status: "Blocked",
    tone: "danger",
    icon: Wallet,
    primaryAction: { label: "View settlement queue", variant: "danger" },
    secondaryAction: { label: "View commission", variant: "outline" },
    metrics: [
      { label: "Commission", value: "GH₵30", status: "Commission Pending" },
      { label: "Settlement due", value: "GH₵40", status: "Proof Submitted" }
    ]
  },
  {
    path: "/edge-cases/admin/record-not-found",
    role: "admin",
    kind: "not-found",
    title: "Record not found",
    description: "This admin record may have been removed from the mock queue or opened with an old link.",
    status: "Not Found",
    tone: "neutral",
    icon: FileQuestion,
    primaryAction: { label: "Return to dashboard" },
    secondaryAction: { label: "View queue", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/delivery-quote-rejected",
    role: "customer",
    kind: "delivery",
    title: "Delivery quote rejected",
    description: "You declined the delivery fee. You can request a new quote or cancel the order.",
    status: "Quote Rejected",
    tone: "warning",
    icon: Truck,
    primaryAction: { label: "Request new quote", variant: "soft-warning" },
    secondaryAction: { label: "Cancel order", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/customer-refused-delivery",
    role: "customer",
    kind: "delivery",
    title: "Delivery refused",
    description: "This order was refused at delivery. Support may review return and refund steps.",
    status: "Customer Refused",
    tone: "danger",
    icon: PackageX,
    primaryAction: { label: "View order", variant: "danger" },
    secondaryAction: { label: "Contact support", variant: "outline" }
  },
  {
    path: "/edge-cases/customer/pay-online-unavailable",
    role: "customer",
    kind: "pending",
    title: "Pay Online unavailable",
    description: "Pay Online is not available yet. Use Pay on Delivery to complete this order.",
    status: "Unavailable",
    tone: "warning",
    icon: CreditCard,
    primaryAction: { label: "Use Pay on Delivery", variant: "soft-warning" }
  },
  {
    path: "/edge-cases/customer/return-submitted",
    role: "customer",
    kind: "success",
    title: "Return request submitted",
    description: "Support will review your return request and share the next step.",
    status: "Submitted",
    tone: "success",
    icon: CheckCircle2,
    primaryAction: { label: "View return" }
  },
  {
    path: "/edge-cases/customer/refund-pending",
    role: "customer",
    kind: "financial",
    title: "Refund pending",
    description: "Pay on Delivery refunds may be manual or off-platform.",
    status: "Refund Pending",
    tone: "warning",
    icon: Wallet,
    primaryAction: { label: "View refund status" }
  },
  {
    path: "/edge-cases/customer/shop-unavailable",
    role: "customer",
    kind: "restricted",
    title: "Shop unavailable",
    description: "This reseller shop is not accepting new orders right now.",
    status: "Shop Unavailable",
    tone: "danger",
    icon: Store,
    primaryAction: { label: "Browse other shops" }
  },
  {
    path: "/edge-cases/reseller/withdrawal-below-minimum",
    role: "reseller",
    kind: "financial",
    title: "Withdrawal below minimum",
    description: "Your available commission is below the minimum withdrawal amount.",
    status: "Below Minimum",
    tone: "warning",
    icon: Wallet,
    primaryAction: { label: "View wallet", variant: "soft-warning" },
    metrics: [
      { label: "Available", value: "GH₵15" },
      { label: "Minimum", value: "GH₵20" }
    ]
  },
  {
    path: "/edge-cases/reseller/shop-suspended",
    role: "reseller",
    kind: "suspended",
    title: "Shop suspended",
    description: "Your shop cannot receive orders while this review is active.",
    status: "Suspended",
    tone: "danger",
    icon: Ban,
    primaryAction: { label: "Contact support", variant: "danger" }
  },
  {
    path: "/edge-cases/reseller/no-trending-data",
    role: "reseller",
    kind: "empty",
    title: "No trending data yet",
    description: "Trend insights will appear after more products and orders are tracked.",
    status: "No Data",
    tone: "neutral",
    icon: Signal,
    primaryAction: { label: "Explore products" }
  },
  {
    path: "/edge-cases/reseller/missing-commission-submitted",
    role: "reseller",
    kind: "success",
    title: "Missing commission dispute submitted",
    description: "Support will check the order, settlement status, and commission snapshot.",
    status: "Submitted",
    tone: "success",
    icon: CheckCircle2,
    primaryAction: { label: "View dispute" }
  },
  {
    path: "/edge-cases/supplier/stock-mismatch",
    role: "supplier",
    kind: "stock",
    title: "Stock mismatch",
    description: "Reserved, sold, and available stock do not match. Review movement history.",
    status: "Needs Review",
    tone: "warning",
    icon: AlertTriangle,
    primaryAction: { label: "View stock history", variant: "soft-warning" }
  },
  {
    path: "/edge-cases/supplier/settlement-due",
    role: "supplier",
    kind: "settlement",
    title: "Settlement due",
    description: "Settle Risellar's margin and reseller commission after customer payment.",
    status: "Settlement Due",
    tone: "warning",
    icon: Wallet,
    primaryAction: { label: "Settle now", variant: "soft-warning" },
    metrics: [{ label: "Amount due", value: "GH₵40" }]
  },
  {
    path: "/edge-cases/supplier/partial-settlement",
    role: "supplier",
    kind: "settlement",
    title: "Partial settlement",
    description: "Some settlement amount remains unpaid. Clear the balance to avoid restrictions.",
    status: "Partially Settled",
    tone: "warning",
    icon: Wallet,
    primaryAction: { label: "Settle balance", variant: "soft-warning" }
  },
  {
    path: "/edge-cases/supplier/suspended",
    role: "supplier",
    kind: "suspended",
    title: "Supplier account suspended",
    description: "Products and new orders are paused due to repeated policy or settlement issues.",
    status: "Suspended",
    tone: "danger",
    icon: Ban,
    primaryAction: { label: "Contact support", variant: "danger" }
  },
  {
    path: "/edge-cases/supplier/no-team-members",
    role: "supplier",
    kind: "empty",
    title: "No team members yet",
    description: "Invite inventory or finance staff when your supplier operation grows.",
    status: "No Team",
    tone: "neutral",
    icon: UserX,
    primaryAction: { label: "Invite team member" }
  },
  {
    path: "/edge-cases/admin/no-product-approvals",
    role: "admin",
    kind: "empty",
    title: "No product approvals",
    description: "Product approval requests will appear here when suppliers submit new products.",
    status: "No Approvals",
    tone: "neutral",
    icon: Boxes,
    primaryAction: { label: "View products" }
  },
  {
    path: "/edge-cases/admin/no-supplier-approvals",
    role: "admin",
    kind: "empty",
    title: "No supplier approvals",
    description: "Supplier verification requests will appear here.",
    status: "No Approvals",
    tone: "neutral",
    icon: ShieldCheck,
    primaryAction: { label: "View suppliers" }
  },
  {
    path: "/edge-cases/admin/no-support-tickets",
    role: "admin",
    kind: "empty",
    title: "No support tickets",
    description: "Customer, reseller, and supplier support tickets will appear here.",
    status: "No Tickets",
    tone: "neutral",
    icon: BellOff,
    primaryAction: { label: "View support" }
  },
  {
    path: "/edge-cases/admin/empty-risk-queue",
    role: "admin",
    kind: "empty",
    title: "Risk queue is clear",
    description: "Flagged accounts, settlement risks, and failed delivery risks will appear here.",
    status: "Empty Risk Queue",
    tone: "success",
    icon: ShieldCheck,
    primaryAction: { label: "View risk dashboard" }
  },
  {
    path: "/edge-cases/admin/proof-pending-review",
    role: "admin",
    kind: "settlement",
    title: "Settlement proof pending review",
    description: "Finance must verify the proof before commission release.",
    status: "Proof Submitted",
    tone: "info",
    icon: FileQuestion,
    primaryAction: { label: "Review proof" }
  },
  {
    path: "/edge-cases/admin/promotion-approval-empty",
    role: "admin",
    kind: "empty",
    title: "No promotion approvals",
    description: "Promotion approvals will appear here after suppliers or resellers submit them.",
    status: "No Approvals",
    tone: "neutral",
    icon: MegaphoneOff,
    primaryAction: { label: "View promotions" }
  },
  {
    path: "/edge-cases/admin/failed-delivery-empty",
    role: "admin",
    kind: "empty",
    title: "Failed delivery queue is empty",
    description: "Failed delivery cases will appear here when rider or customer follow-up is needed.",
    status: "Empty Queue",
    tone: "success",
    icon: Truck,
    primaryAction: { label: "View queue" }
  }
];

export function getEdgeCaseDefinition(path: string) {
  return edgeCaseDefinitions.find((state) => state.path === path);
}

export function formatEdgeCasePath(slug?: string[]) {
  return slug?.length ? `/edge-cases/${slug.join("/")}` : "/edge-cases";
}

export function getEdgeCasesByRole(role: EdgeCaseRole) {
  return edgeCaseDefinitions.filter((state) => state.role === role);
}
