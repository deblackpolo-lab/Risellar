export type RisellarRole = "customer" | "reseller" | "supplier_owner" | "supplier_inventory_manager" | "admin";

export type OnboardingStatus = "not_started" | "in_progress" | "pending_review" | "complete";

export type AuthRoutePolicy = {
  pattern: string;
  roles: RisellarRole[];
  onboarding?: OnboardingStatus[];
  note: string;
};

export type PublicRoutePolicy = {
  pattern: string;
  note: string;
};

export type RoleRedirectRule = {
  role: RisellarRole;
  onboardingStatus: OnboardingStatus;
  redirectTo: string;
};

export type ProfileOnboardingField =
  | "full_name"
  | "email"
  | "phone"
  | "whatsapp_number"
  | "role"
  | "city_area"
  | "delivery_address"
  | "reseller_type"
  | "reseller_shop_name"
  | "mobile_money_name"
  | "mobile_money_number"
  | "supplier_business_name"
  | "supplier_business_type"
  | "supplier_primary_category"
  | "supplier_location"
  | "supplier_verification_documents"
  | "supplier_payout_account"
  | "accepted_reseller_rules"
  | "accepted_supplier_agreement";

export const risellarRoles: RisellarRole[] = [
  "customer",
  "reseller",
  "supplier_owner",
  "supplier_inventory_manager",
  "admin"
];

export const profileOnboardingFields: Record<RisellarRole, ProfileOnboardingField[]> = {
  customer: ["full_name", "email", "phone", "whatsapp_number", "city_area", "delivery_address"],
  reseller: [
    "full_name",
    "email",
    "phone",
    "whatsapp_number",
    "reseller_type",
    "reseller_shop_name",
    "city_area",
    "mobile_money_name",
    "mobile_money_number",
    "accepted_reseller_rules"
  ],
  supplier_owner: [
    "full_name",
    "email",
    "phone",
    "whatsapp_number",
    "supplier_business_name",
    "supplier_business_type",
    "supplier_primary_category",
    "supplier_location",
    "supplier_verification_documents",
    "supplier_payout_account",
    "accepted_supplier_agreement"
  ],
  supplier_inventory_manager: ["full_name", "email", "phone", "whatsapp_number", "supplier_business_name"],
  admin: ["full_name", "email", "role"]
};

export const publicRoutePolicies: PublicRoutePolicy[] = [
  { pattern: "/", note: "Current frontend shell / reviewer entry point." },
  { pattern: "/preview", note: "Internal frontend QA launcher; keep available while mock frontend is reviewed." },
  { pattern: "/design-system", note: "Design system gallery." },
  { pattern: "/shop/:shopSlug", note: "Public reseller shop landing page." },
  { pattern: "/shop/:shopSlug/product/:productId", note: "Public reseller product page." },
  { pattern: "/checkout/cart", note: "Cart can remain public until account step; checkout creation requires auth later." },
  { pattern: "/edge-cases/:slug*", note: "Mock edge-state gallery for QA." }
];

export const protectedRoutePolicies: AuthRoutePolicy[] = [
  {
    pattern: "/checkout/account",
    roles: ["customer"],
    onboarding: ["not_started", "in_progress", "complete"],
    note: "Customer Clerk account/profile collection begins before placing an order."
  },
  {
    pattern: "/checkout/delivery",
    roles: ["customer"],
    onboarding: ["in_progress", "complete"],
    note: "Delivery details require a signed-in customer profile."
  },
  {
    pattern: "/checkout/payment",
    roles: ["customer"],
    onboarding: ["in_progress", "complete"],
    note: "Pay on Delivery selection must be tied to the authenticated customer."
  },
  {
    pattern: "/checkout/review",
    roles: ["customer"],
    onboarding: ["in_progress", "complete"],
    note: "Final order review must use trusted account/profile data."
  },
  {
    pattern: "/checkout/success",
    roles: ["customer"],
    onboarding: ["in_progress", "complete"],
    note: "Success screen should resolve the customer's own order."
  },
  {
    pattern: "/onboarding/:slug*",
    roles: ["customer"],
    onboarding: ["not_started", "in_progress", "pending_review", "complete"],
    note: "Signed-in customers can request reseller or supplier access without changing their profile role."
  },
  {
    pattern: "/customer/:slug*",
    roles: ["customer"],
    onboarding: ["complete"],
    note: "Customer order, support, return, refund, and dispute history."
  },
  {
    pattern: "/reseller/onboarding/:slug*",
    roles: ["reseller"],
    onboarding: ["not_started", "in_progress"],
    note: "Reseller onboarding can be entered after Clerk sign-up and role choice."
  },
  {
    pattern: "/reseller/:slug*",
    roles: ["reseller"],
    onboarding: ["complete"],
    note: "Reseller dashboard, catalog, shop, orders, wallet, insights, promotions, and support."
  },
  {
    pattern: "/supplier/onboarding/:slug*",
    roles: ["supplier_owner"],
    onboarding: ["not_started", "in_progress", "pending_review"],
    note: "Supplier owner onboarding, KYC placeholders, payout setup, agreement, and approval states."
  },
  {
    pattern: "/supplier/inventory-manager/:slug*",
    roles: ["supplier_inventory_manager"],
    onboarding: ["complete"],
    note: "Supplier staff view limited to product, stock, and order preparation work."
  },
  {
    pattern: "/supplier/:slug*",
    roles: ["supplier_owner"],
    onboarding: ["complete"],
    note: "Supplier owner workspace including products, inventory, settlements, finance, promotions, team, support, and settings."
  },
  {
    pattern: "/admin/:slug*",
    roles: ["admin"],
    onboarding: ["complete"],
    note: "Admin operations, risk, finance review, support, audit, settings, and manual override surfaces."
  }
];

export const roleRedirectRules: RoleRedirectRule[] = [
  { role: "customer", onboardingStatus: "not_started", redirectTo: "/checkout/account" },
  { role: "customer", onboardingStatus: "in_progress", redirectTo: "/checkout/delivery" },
  { role: "customer", onboardingStatus: "pending_review", redirectTo: "/checkout/account" },
  { role: "customer", onboardingStatus: "complete", redirectTo: "/customer/orders" },
  { role: "reseller", onboardingStatus: "not_started", redirectTo: "/reseller/onboarding/welcome" },
  { role: "reseller", onboardingStatus: "in_progress", redirectTo: "/reseller/onboarding/profile" },
  { role: "reseller", onboardingStatus: "pending_review", redirectTo: "/reseller/onboarding/complete" },
  { role: "reseller", onboardingStatus: "complete", redirectTo: "/reseller/dashboard" },
  { role: "supplier_owner", onboardingStatus: "not_started", redirectTo: "/supplier/onboarding/welcome" },
  { role: "supplier_owner", onboardingStatus: "in_progress", redirectTo: "/supplier/onboarding/business" },
  { role: "supplier_owner", onboardingStatus: "pending_review", redirectTo: "/supplier/onboarding/pending" },
  { role: "supplier_owner", onboardingStatus: "complete", redirectTo: "/supplier/dashboard" },
  { role: "supplier_inventory_manager", onboardingStatus: "not_started", redirectTo: "/supplier/inventory-manager/settings" },
  { role: "supplier_inventory_manager", onboardingStatus: "in_progress", redirectTo: "/supplier/inventory-manager/settings" },
  { role: "supplier_inventory_manager", onboardingStatus: "pending_review", redirectTo: "/supplier/inventory-manager/settings" },
  { role: "supplier_inventory_manager", onboardingStatus: "complete", redirectTo: "/supplier/inventory-manager/dashboard" },
  { role: "admin", onboardingStatus: "not_started", redirectTo: "/admin/dashboard" },
  { role: "admin", onboardingStatus: "in_progress", redirectTo: "/admin/dashboard" },
  { role: "admin", onboardingStatus: "pending_review", redirectTo: "/admin/dashboard" },
  { role: "admin", onboardingStatus: "complete", redirectTo: "/admin/dashboard" }
];

export function getDefaultRedirect(role: RisellarRole, onboardingStatus: OnboardingStatus) {
  return roleRedirectRules.find((rule) => rule.role === role && rule.onboardingStatus === onboardingStatus)?.redirectTo ?? "/";
}
