export type PreviewSection =
  | "Design System"
  | "Public/Auth"
  | "Customer Checkout"
  | "Customer Account/Orders"
  | "Reseller PWA"
  | "Reseller Insights/Promotions"
  | "Supplier PWA"
  | "Supplier Inventory"
  | "Supplier Settlements/Finance"
  | "Supplier Promotions"
  | "Supplier Team/Inventory Manager"
  | "Admin Core"
  | "Admin Operations / Risk"
  | "Admin Promotions"
  | "Admin Support/Disputes/Returns/Refunds"
  | "Edge Cases";

type PreviewSourceSection = PreviewSection | "Public/Auth / General";

export type PreviewStatus = "Built" | "Mock" | "Frontend only";

export type PreviewRoute = {
  title: string;
  path: string;
  section: PreviewSourceSection;
  status: PreviewStatus;
  note?: string;
};

export const previewRoutes: PreviewRoute[] = [
  { section: "Design System", title: "Preview Launcher", path: "/preview", status: "Built", note: "Internal screen index for QA and review." },
  { section: "Design System", title: "Design System Gallery", path: "/design-system", status: "Built", note: "Approved tokens and component examples." },

  { section: "Public/Auth / General", title: "Home Redirect", path: "/", status: "Built", note: "Root landing currently points reviewers into the built frontend." },
  { section: "Public/Auth / General", title: "Reseller Onboarding Welcome", path: "/reseller/onboarding/welcome", status: "Mock" },
  { section: "Public/Auth / General", title: "Reseller Type Selection", path: "/reseller/onboarding/type", status: "Mock" },
  { section: "Public/Auth / General", title: "Reseller Profile Setup", path: "/reseller/onboarding/profile", status: "Mock" },
  { section: "Public/Auth / General", title: "Reseller Area Selection", path: "/reseller/onboarding/area", status: "Mock" },
  { section: "Public/Auth / General", title: "Reseller Payout Setup", path: "/reseller/onboarding/payout", status: "Mock" },
  { section: "Public/Auth / General", title: "Reseller Rules", path: "/reseller/onboarding/rules", status: "Mock" },
  { section: "Public/Auth / General", title: "Reseller Onboarding Complete", path: "/reseller/onboarding/complete", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier Onboarding Welcome", path: "/supplier/onboarding/welcome", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier Business Profile", path: "/supplier/onboarding/business", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier Category Setup", path: "/supplier/onboarding/category", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier Verification", path: "/supplier/onboarding/verification", status: "Mock", note: "Upload placeholder only." },
  { section: "Public/Auth / General", title: "Supplier Payout Setup", path: "/supplier/onboarding/payout", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier Agreement", path: "/supplier/onboarding/agreement", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier Pending Approval", path: "/supplier/onboarding/pending", status: "Mock" },
  { section: "Public/Auth / General", title: "Supplier More Info Required", path: "/supplier/onboarding/rejected", status: "Mock" },

  { section: "Reseller PWA", title: "Reseller Dashboard", path: "/reseller/dashboard", status: "Built" },
  { section: "Reseller PWA", title: "Product Catalog", path: "/reseller/products", status: "Built" },
  { section: "Reseller PWA", title: "Category Product List", path: "/reseller/products/category/beauty", status: "Mock" },
  { section: "Reseller PWA", title: "Product Detail", path: "/reseller/products/nike-air-force-1-07-green-white", status: "Built" },
  { section: "Reseller PWA", title: "Price Calculator", path: "/reseller/products/nike-air-force-1-07-green-white/price", status: "Built" },
  { section: "Reseller PWA", title: "Add To Shop Success", path: "/reseller/products/nike-air-force-1-07-green-white/added", status: "Mock" },
  { section: "Reseller PWA", title: "My Shop", path: "/reseller/shop", status: "Built" },
  { section: "Reseller PWA", title: "Edit Shop", path: "/reseller/shop/edit", status: "Mock" },
  { section: "Reseller PWA", title: "My Products", path: "/reseller/my-products", status: "Built" },
  { section: "Reseller PWA", title: "Share Product", path: "/reseller/share/nike-air-force-1-07-green-white", status: "Mock", note: "WhatsApp sharing is visual only." },
  { section: "Reseller PWA", title: "Orders", path: "/reseller/orders", status: "Built" },
  { section: "Reseller PWA", title: "Order Detail", path: "/reseller/orders/rsr-20260713-00021", status: "Mock" },
  { section: "Reseller PWA", title: "Wallet", path: "/reseller/wallet", status: "Built" },
  { section: "Reseller PWA", title: "Withdraw", path: "/reseller/withdraw", status: "Mock" },
  { section: "Reseller PWA", title: "Transactions", path: "/reseller/transactions", status: "Built" },
  { section: "Reseller PWA", title: "Notifications", path: "/reseller/notifications", status: "Built" },
  { section: "Reseller PWA", title: "Settings", path: "/reseller/settings", status: "Built" },
  { section: "Reseller PWA", title: "Support", path: "/reseller/support", status: "Built" },
  { section: "Reseller PWA", title: "Support Tickets", path: "/reseller/support/tickets", status: "Built" },
  { section: "Reseller PWA", title: "Support Ticket Detail", path: "/reseller/support/tickets/tkt-commission-rsr-20260713-00021", status: "Mock" },
  { section: "Reseller PWA", title: "Missing Commission", path: "/reseller/support/missing-commission", status: "Mock" },
  { section: "Reseller PWA", title: "Commission Dispute", path: "/reseller/support/commission-disputes/cmd-rsr-20260713-00021", status: "Mock" },
  { section: "Reseller PWA", title: "Trending Products", path: "/reseller/trending", status: "Built" },
  { section: "Reseller PWA", title: "Insights Overview", path: "/reseller/insights", status: "Built" },
  { section: "Reseller PWA", title: "Top-Selling Insights", path: "/reseller/insights/top-selling", status: "Mock" },
  { section: "Reseller PWA", title: "High-Profit Insights", path: "/reseller/insights/high-profit", status: "Mock" },
  { section: "Reseller PWA", title: "Low-Competition Insights", path: "/reseller/insights/low-competition", status: "Mock" },
  { section: "Reseller PWA", title: "Pro Insights Locked", path: "/reseller/insights/pro", status: "Frontend only" },
  { section: "Reseller PWA", title: "Caption Templates", path: "/reseller/insights/captions", status: "Mock" },
  { section: "Reseller PWA", title: "Promotions", path: "/reseller/promotions", status: "Built" },
  { section: "Reseller PWA", title: "Sponsored Products", path: "/reseller/promotions/sponsored-products", status: "Mock" },

  { section: "Customer Checkout", title: "Public Shop", path: "/shop/amas-beauty-plug", status: "Built" },
  { section: "Customer Checkout", title: "Shop Product Page", path: "/shop/amas-beauty-plug/product/nike-air-force-1-07-green-white", status: "Built" },
  { section: "Customer Checkout", title: "Cart", path: "/checkout/cart", status: "Built" },
  { section: "Customer Checkout", title: "Account Step", path: "/checkout/account", status: "Mock", note: "No real Clerk integration." },
  { section: "Customer Checkout", title: "Delivery Step", path: "/checkout/delivery", status: "Built" },
  { section: "Customer Checkout", title: "Payment Step", path: "/checkout/payment", status: "Built", note: "Pay on Delivery only; Pay Online disabled." },
  { section: "Customer Checkout", title: "Review Step", path: "/checkout/review", status: "Built" },
  { section: "Customer Checkout", title: "Success", path: "/checkout/success", status: "Built" },
  { section: "Customer Checkout", title: "Customer Orders", path: "/customer/orders", status: "Built" },
  { section: "Customer Checkout", title: "Customer Order Detail", path: "/customer/orders/rsr-20260713-00021", status: "Built" },
  { section: "Customer Checkout", title: "Confirm Order", path: "/customer/orders/rsr-20260713-00021/confirm", status: "Mock" },
  { section: "Customer Checkout", title: "Delivery Quote Approval", path: "/customer/orders/rsr-20260713-00021/delivery-quote", status: "Mock" },
  { section: "Customer Checkout", title: "Report Issue", path: "/customer/orders/rsr-20260713-00021/report-issue", status: "Mock" },
  { section: "Customer Checkout", title: "Return Request", path: "/customer/orders/rsr-20260713-00021/return-request", status: "Mock" },
  { section: "Customer Checkout", title: "Refund Status", path: "/customer/orders/rsr-20260713-00021/refund-status", status: "Mock" },
  { section: "Customer Checkout", title: "Customer Support", path: "/customer/support", status: "Built" },
  { section: "Customer Checkout", title: "Customer Support Tickets", path: "/customer/support/tickets", status: "Built" },
  { section: "Customer Checkout", title: "Customer Ticket Detail", path: "/customer/support/tickets/tkt-rsr-20260713-00021", status: "Mock" },
  { section: "Customer Checkout", title: "Customer Dispute Detail", path: "/customer/disputes/dsp-rsr-20260713-00021", status: "Mock" },

  { section: "Supplier PWA", title: "Supplier Dashboard", path: "/supplier/dashboard", status: "Built" },
  { section: "Supplier PWA", title: "Products", path: "/supplier/products", status: "Built" },
  { section: "Supplier PWA", title: "New Product", path: "/supplier/products/new", status: "Mock" },
  { section: "Supplier PWA", title: "Product Detail", path: "/supplier/products/nike-air-force-1-07-green-white", status: "Built" },
  { section: "Supplier PWA", title: "Edit Product", path: "/supplier/products/nike-air-force-1-07-green-white/edit", status: "Mock" },
  { section: "Supplier PWA", title: "Orders", path: "/supplier/orders", status: "Built" },
  { section: "Supplier PWA", title: "Order Detail", path: "/supplier/orders/rsr-20260713-00021", status: "Built" },
  { section: "Supplier PWA", title: "Prepare Order", path: "/supplier/orders/rsr-20260713-00021/prepare", status: "Mock" },
  { section: "Supplier PWA", title: "Inventory Dashboard", path: "/supplier/inventory", status: "Built" },
  { section: "Supplier PWA", title: "Inventory Product Detail", path: "/supplier/inventory/nike-air-force-1-07-green-white", status: "Built" },
  { section: "Supplier PWA", title: "Variant Stock", path: "/supplier/inventory/nike-air-force-1-07-green-white/variants", status: "Built" },
  { section: "Supplier PWA", title: "Restock Product", path: "/supplier/inventory/nike-air-force-1-07-green-white/restock", status: "Mock" },
  { section: "Supplier PWA", title: "Stock Movements", path: "/supplier/inventory/nike-air-force-1-07-green-white/movements", status: "Built" },
  { section: "Supplier PWA", title: "Price Change Request", path: "/supplier/inventory/nike-air-force-1-07-green-white/price-change", status: "Mock" },
  { section: "Supplier PWA", title: "Low Stock", path: "/supplier/inventory/low-stock", status: "Built" },
  { section: "Supplier PWA", title: "Out Of Stock", path: "/supplier/inventory/out-of-stock", status: "Built" },
  { section: "Supplier PWA", title: "Inventory Activity", path: "/supplier/inventory/activity", status: "Built" },
  { section: "Supplier PWA", title: "Settlements", path: "/supplier/settlements", status: "Built" },
  { section: "Supplier PWA", title: "Settlement Detail", path: "/supplier/settlements/stl-rsr-20260713-00021", status: "Built" },
  { section: "Supplier PWA", title: "Settle Now", path: "/supplier/settlements/stl-rsr-20260713-00021/settle", status: "Mock", note: "Proof upload placeholder only." },
  { section: "Supplier PWA", title: "Settlement History", path: "/supplier/settlements/history", status: "Built" },
  { section: "Supplier PWA", title: "Overdue Settlements", path: "/supplier/settlements/overdue", status: "Built" },
  { section: "Supplier PWA", title: "Partial Settlement", path: "/supplier/settlements/partial", status: "Mock" },
  { section: "Supplier PWA", title: "Settlement Rules", path: "/supplier/settlements/rules", status: "Built" },
  { section: "Supplier PWA", title: "Finance", path: "/supplier/finance", status: "Built" },
  { section: "Supplier PWA", title: "Payout Details", path: "/supplier/finance/payout-details", status: "Mock" },
  { section: "Supplier PWA", title: "Trust Score", path: "/supplier/finance/trust-score", status: "Built" },
  { section: "Supplier PWA", title: "Promotions", path: "/supplier/promotions", status: "Built" },
  { section: "Supplier PWA", title: "New Promotion", path: "/supplier/promotions/new", status: "Mock" },
  { section: "Supplier PWA", title: "Promotion Packages", path: "/supplier/promotions/packages", status: "Built" },
  { section: "Supplier PWA", title: "Promotion Detail", path: "/supplier/promotions/boost-jpg-le-male-legon", status: "Built" },
  { section: "Supplier PWA", title: "Promotion Performance", path: "/supplier/promotions/boost-jpg-le-male-legon/performance", status: "Mock" },
  { section: "Supplier PWA", title: "Promotion History", path: "/supplier/promotions/history", status: "Built" },
  { section: "Supplier PWA", title: "Promotion Eligibility", path: "/supplier/promotions/eligibility", status: "Built" },
  { section: "Supplier PWA", title: "Promotion Payment Proof", path: "/supplier/promotions/payment-proof", status: "Mock" },
  { section: "Supplier PWA", title: "Team", path: "/supplier/team", status: "Built" },
  { section: "Supplier PWA", title: "Invite Team Member", path: "/supplier/team/invite", status: "Mock" },
  { section: "Supplier PWA", title: "Team Member Detail", path: "/supplier/team/akua-boateng", status: "Built" },
  { section: "Supplier PWA", title: "Team Member Permissions", path: "/supplier/team/akua-boateng/permissions", status: "Mock" },
  { section: "Supplier PWA", title: "Team Activity", path: "/supplier/team/activity", status: "Built" },
  { section: "Supplier PWA", title: "Role Rules", path: "/supplier/team/roles", status: "Built" },
  { section: "Supplier PWA", title: "Access Denied", path: "/supplier/team/access-denied", status: "Mock" },
  { section: "Supplier PWA", title: "Inventory Manager Dashboard", path: "/supplier/inventory-manager/dashboard", status: "Built" },
  { section: "Supplier PWA", title: "Inventory Manager Products", path: "/supplier/inventory-manager/products", status: "Built" },
  { section: "Supplier PWA", title: "Inventory Manager Orders", path: "/supplier/inventory-manager/orders", status: "Built" },
  { section: "Supplier PWA", title: "Inventory Manager Settings", path: "/supplier/inventory-manager/settings", status: "Mock" },
  { section: "Supplier PWA", title: "Supplier Support", path: "/supplier/support", status: "Built" },
  { section: "Supplier PWA", title: "Supplier Support Tickets", path: "/supplier/support/tickets", status: "Built" },
  { section: "Supplier PWA", title: "Supplier Ticket Detail", path: "/supplier/support/tickets/tkt-settlement-rsr-20260713-00021", status: "Mock" },
  { section: "Supplier PWA", title: "Settlement Dispute", path: "/supplier/support/settlement-dispute", status: "Mock" },
  { section: "Supplier PWA", title: "Settlement Dispute Detail", path: "/supplier/support/settlement-disputes/sdp-rsr-20260713-00021", status: "Mock" },
  { section: "Supplier PWA", title: "Supplier Returns", path: "/supplier/support/returns", status: "Built" },
  { section: "Supplier PWA", title: "Settings", path: "/supplier/settings", status: "Built" },
  { section: "Supplier PWA", title: "Notifications", path: "/supplier/notifications", status: "Built" },

  { section: "Admin Core", title: "Dashboard", path: "/admin/dashboard", status: "Built" },
  { section: "Admin Core", title: "Orders", path: "/admin/orders", status: "Built" },
  { section: "Admin Core", title: "Order Detail", path: "/admin/orders/rsr-20260713-00021", status: "Built" },
  { section: "Admin Core", title: "Products", path: "/admin/products", status: "Built" },
  { section: "Admin Core", title: "Product Detail", path: "/admin/products/nike-air-force-1-07-green-white", status: "Built" },
  { section: "Admin Core", title: "Suppliers", path: "/admin/suppliers", status: "Built" },
  { section: "Admin Core", title: "Supplier Detail", path: "/admin/suppliers/knust-gadgets", status: "Built" },
  { section: "Admin Core", title: "Resellers", path: "/admin/resellers", status: "Built" },
  { section: "Admin Core", title: "Reseller Detail", path: "/admin/resellers/amas-beauty-plug", status: "Built" },
  { section: "Admin Core", title: "Customers", path: "/admin/customers", status: "Built" },
  { section: "Admin Core", title: "Customer Detail", path: "/admin/customers/nana-yaw", status: "Built" },
  { section: "Admin Core", title: "Settlements", path: "/admin/settlements", status: "Built" },
  { section: "Admin Core", title: "Commissions", path: "/admin/commissions", status: "Built" },
  { section: "Admin Core", title: "Withdrawals", path: "/admin/withdrawals", status: "Built" },
  { section: "Admin Core", title: "Support", path: "/admin/support", status: "Built" },
  { section: "Admin Core", title: "Settings", path: "/admin/settings", status: "Built" },

  { section: "Admin Operations / Risk", title: "Operations Hub", path: "/admin/operations", status: "Built" },
  { section: "Admin Operations / Risk", title: "Customer Confirmation Queue", path: "/admin/operations/customer-confirmations", status: "Built" },
  { section: "Admin Operations / Risk", title: "Customer Confirmation Detail", path: "/admin/operations/customer-confirmations/rsr-20260713-00021", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Supplier Availability Queue", path: "/admin/operations/supplier-availability", status: "Built" },
  { section: "Admin Operations / Risk", title: "Supplier Preparation Queue", path: "/admin/operations/supplier-preparation", status: "Built" },
  { section: "Admin Operations / Risk", title: "Delivery Quote Queue", path: "/admin/operations/delivery-quotes", status: "Built" },
  { section: "Admin Operations / Risk", title: "Settlement Due Queue", path: "/admin/operations/settlement-due", status: "Built" },
  { section: "Admin Operations / Risk", title: "Overdue Settlement Queue", path: "/admin/operations/overdue-settlements", status: "Built" },
  { section: "Admin Operations / Risk", title: "Overdue Settlement Detail", path: "/admin/operations/overdue-settlements/stl-rsr-20260713-00021", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Commission Release Queue", path: "/admin/operations/commission-release", status: "Built" },
  { section: "Admin Operations / Risk", title: "Product Approval Queue", path: "/admin/operations/product-approvals", status: "Built" },
  { section: "Admin Operations / Risk", title: "Supplier Approval Queue", path: "/admin/operations/supplier-approvals", status: "Built" },
  { section: "Admin Operations / Risk", title: "Withdrawal Request Queue", path: "/admin/operations/withdrawal-requests", status: "Built" },
  { section: "Admin Operations / Risk", title: "Dispute Queue", path: "/admin/operations/disputes", status: "Built" },
  { section: "Admin Operations / Risk", title: "Dispute Queue Detail", path: "/admin/operations/disputes/dsp-rsr-20260713-00021", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Failed Delivery Queue", path: "/admin/operations/failed-deliveries", status: "Built" },
  { section: "Admin Operations / Risk", title: "Stock Issue Queue", path: "/admin/operations/stock-issues", status: "Built" },
  { section: "Admin Operations / Risk", title: "Promotion Approval Queue", path: "/admin/operations/promotion-approvals", status: "Built" },
  { section: "Admin Operations / Risk", title: "Risk Dashboard", path: "/admin/risk", status: "Built" },
  { section: "Admin Operations / Risk", title: "Supplier Risk List", path: "/admin/risk/suppliers", status: "Built" },
  { section: "Admin Operations / Risk", title: "Reseller Risk List", path: "/admin/risk/resellers", status: "Built" },
  { section: "Admin Operations / Risk", title: "Customer Risk List", path: "/admin/risk/customers", status: "Built" },
  { section: "Admin Operations / Risk", title: "Product Risk List", path: "/admin/risk/products", status: "Built" },
  { section: "Admin Operations / Risk", title: "Supplier Risk Detail", path: "/admin/risk/suppliers/knust-gadgets", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Audit Logs", path: "/admin/audit-logs", status: "Built" },
  { section: "Admin Operations / Risk", title: "Manual Overrides", path: "/admin/manual-overrides", status: "Frontend only", note: "Controls are intentionally disabled." },
  { section: "Admin Operations / Risk", title: "Admin Promotions", path: "/admin/promotions", status: "Built" },
  { section: "Admin Operations / Risk", title: "Admin Promotion Detail", path: "/admin/promotions/boost-jpg-le-male-legon", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Promotion Packages", path: "/admin/promotions/packages", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Admin Disputes", path: "/admin/disputes", status: "Built" },
  { section: "Admin Operations / Risk", title: "Admin Dispute Detail", path: "/admin/disputes/dsp-rsr-20260713-00021", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Admin Returns", path: "/admin/returns", status: "Built" },
  { section: "Admin Operations / Risk", title: "Admin Return Detail", path: "/admin/returns/rtn-rsr-20260713-00021", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Admin Refunds", path: "/admin/refunds", status: "Built" },
  { section: "Admin Operations / Risk", title: "Admin Refund Detail", path: "/admin/refunds/rfd-rsr-20260713-00021", status: "Mock" },
  { section: "Admin Operations / Risk", title: "Admin Support Tickets", path: "/admin/support/tickets", status: "Built" },
  { section: "Admin Operations / Risk", title: "Admin Ticket Detail", path: "/admin/support/tickets/tkt-rsr-20260713-00021", status: "Mock" },

  { section: "Edge Cases", title: "Edge Case Gallery", path: "/edge-cases", status: "Built" },
  { section: "Edge Cases", title: "Loading", path: "/edge-cases/loading", status: "Built" },
  { section: "Edge Cases", title: "Offline", path: "/edge-cases/offline", status: "Built" },
  { section: "Edge Cases", title: "Permission Denied", path: "/edge-cases/permission-denied", status: "Built" },
  { section: "Edge Cases", title: "Account Restricted", path: "/edge-cases/account-restricted", status: "Mock" },
  { section: "Edge Cases", title: "Customer Awaiting Confirmation", path: "/edge-cases/customer/awaiting-confirmation", status: "Built" },
  { section: "Edge Cases", title: "Customer Product Out Of Stock", path: "/edge-cases/customer/product-out-of-stock", status: "Built" },
  { section: "Edge Cases", title: "Reseller Commission Pending", path: "/edge-cases/reseller/commission-pending", status: "Built" },
  { section: "Edge Cases", title: "Reseller Withdrawal Failed", path: "/edge-cases/reseller/withdrawal-failed", status: "Built" },
  { section: "Edge Cases", title: "Supplier Settlement Overdue", path: "/edge-cases/supplier/settlement-overdue", status: "Built" },
  { section: "Edge Cases", title: "Supplier Verification Pending", path: "/edge-cases/supplier/verification-pending", status: "Built" },
  { section: "Edge Cases", title: "Admin Manual Override Warning", path: "/edge-cases/admin/manual-override-warning", status: "Built" },
  { section: "Edge Cases", title: "Admin Commission Release Blocked", path: "/edge-cases/admin/commission-release-blocked", status: "Mock" }
];

export const previewSections: PreviewSection[] = [
  "Design System",
  "Public/Auth",
  "Customer Checkout",
  "Customer Account/Orders",
  "Reseller PWA",
  "Reseller Insights/Promotions",
  "Supplier PWA",
  "Supplier Inventory",
  "Supplier Settlements/Finance",
  "Supplier Promotions",
  "Supplier Team/Inventory Manager",
  "Admin Core",
  "Admin Operations / Risk",
  "Admin Promotions",
  "Admin Support/Disputes/Returns/Refunds",
  "Edge Cases"
];

export function getPreviewRoutesBySection(section: PreviewSection) {
  return previewRoutes.filter((route) => getPreviewDisplaySection(route) === section);
}

export function getPreviewDisplaySection(route: PreviewRoute): PreviewSection {
  if (route.section === "Public/Auth / General") return "Public/Auth";

  if (
    route.path.startsWith("/customer") ||
    route.title.includes("Customer Orders") ||
    route.title.includes("Customer Order") ||
    route.title.includes("Confirm Order") ||
    route.title.includes("Delivery Quote") ||
    route.title.includes("Report Issue") ||
    route.title.includes("Return Request") ||
    route.title.includes("Refund Status")
  ) {
    return "Customer Account/Orders";
  }

  if (
    route.path.startsWith("/reseller/insights") ||
    route.path.startsWith("/reseller/promotions") ||
    route.path === "/reseller/trending"
  ) {
    return "Reseller Insights/Promotions";
  }

  if (route.path.startsWith("/supplier/inventory") && !route.path.startsWith("/supplier/inventory-manager")) {
    return "Supplier Inventory";
  }

  if (route.path.startsWith("/supplier/settlements") || route.path.startsWith("/supplier/finance")) {
    return "Supplier Settlements/Finance";
  }

  if (route.path.startsWith("/supplier/promotions")) {
    return "Supplier Promotions";
  }

  if (route.path.startsWith("/supplier/team") || route.path.startsWith("/supplier/inventory-manager")) {
    return "Supplier Team/Inventory Manager";
  }

  if (route.path.startsWith("/admin/promotions")) {
    return "Admin Promotions";
  }

  if (
    route.path.startsWith("/admin/support") ||
    route.path.startsWith("/admin/disputes") ||
    route.path.startsWith("/admin/returns") ||
    route.path.startsWith("/admin/refunds")
  ) {
    return "Admin Support/Disputes/Returns/Refunds";
  }

  if (route.section === "Public/Auth") return "Public/Auth";
  return route.section;
}

export const requiredPhase15RouteChecks = [
  "/preview",
  "/design-system",
  "/reseller/dashboard",
  "/reseller/products",
  "/reseller/products/nike-air-force-1-07-green-white",
  "/reseller/shop",
  "/reseller/orders",
  "/reseller/wallet",
  "/reseller/trending",
  "/reseller/insights",
  "/reseller/support",
  "/shop/amas-beauty-plug",
  "/shop/amas-beauty-plug/product/nike-air-force-1-07-green-white",
  "/checkout/cart",
  "/checkout/account",
  "/checkout/delivery",
  "/checkout/payment",
  "/checkout/review",
  "/checkout/success",
  "/customer/orders/rsr-20260713-00021",
  "/customer/orders/rsr-20260713-00021/confirm",
  "/customer/orders/rsr-20260713-00021/delivery-quote",
  "/customer/support",
  "/customer/disputes/dsp-rsr-20260713-00021",
  "/supplier/dashboard",
  "/supplier/products",
  "/supplier/orders",
  "/supplier/inventory",
  "/supplier/settlements",
  "/supplier/finance",
  "/supplier/promotions",
  "/supplier/team",
  "/supplier/inventory-manager/dashboard",
  "/supplier/support",
  "/admin/dashboard",
  "/admin/orders",
  "/admin/orders/rsr-20260713-00021",
  "/admin/products",
  "/admin/suppliers",
  "/admin/resellers",
  "/admin/customers",
  "/admin/settlements",
  "/admin/commissions",
  "/admin/withdrawals",
  "/admin/operations",
  "/admin/risk",
  "/admin/audit-logs",
  "/admin/manual-overrides",
  "/admin/promotions",
  "/admin/disputes",
  "/admin/returns",
  "/admin/refunds",
  "/edge-cases"
] as const;
