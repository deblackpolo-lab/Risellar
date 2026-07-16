export type TeamMemberStatus = "Active" | "Pending Invite" | "Suspended";
export type SupplierTeamRole = "Supplier Owner" | "Inventory Manager" | "Finance Staff" | "Viewer";

export type TeamMember = {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: SupplierTeamRole;
  status: TeamMemberStatus;
  lastActive: string;
  avatar: string;
  productsUpdated: number;
  ordersPrepared: number;
  stockChanges: number;
  summary: string;
};

export type Permission = {
  label: string;
  owner: boolean;
  inventoryManager: boolean;
  lockedForInventoryManager?: boolean;
};

export type PermissionGroup = {
  name: string;
  permissions: Permission[];
};

export type TeamActivity = {
  id: string;
  actor: string;
  role: string;
  action: string;
  target: string;
  oldValue: string;
  newValue: string;
  timestamp: string;
  type: "Product" | "Stock" | "Order" | "Team" | "Price";
};

export const supplierTeamMock = {
  supplier: {
    businessName: "KNUST Gadgets",
    secondaryBusinessName: "Palace Beauty Supplies",
    ownerName: "Kofi Mensah",
    location: "Kumasi, Ashanti Region"
  },
  members: [
    {
      id: "kofi-mensah",
      name: "Kofi Mensah",
      email: "kofi@knustgadgets.com",
      phone: "+233 24 555 0120",
      role: "Supplier Owner",
      status: "Active",
      lastActive: "Today, 9:42 AM",
      avatar: "KM",
      productsUpdated: 18,
      ordersPrepared: 6,
      stockChanges: 22,
      summary: "Owner can manage products, finance, team, settlement, payout, and business verification."
    },
    {
      id: "akua-boateng",
      name: "Akua Boateng",
      email: "akua@knustgadgets.com",
      phone: "+233 24 987 6543",
      role: "Inventory Manager",
      status: "Active",
      lastActive: "Today, 10:24 AM",
      avatar: "AB",
      productsUpdated: 12,
      ordersPrepared: 9,
      stockChanges: 31,
      summary: "Can manage products, stock, restock, and prepare confirmed orders."
    },
    {
      id: "efua-darko",
      name: "Efua Darko",
      email: "efua@knustgadgets.com",
      phone: "+233 20 444 1122",
      role: "Finance Staff",
      status: "Pending Invite",
      lastActive: "Invite sent 2 days ago",
      avatar: "ED",
      productsUpdated: 0,
      ordersPrepared: 0,
      stockChanges: 0,
      summary: "Future finance role example. Disabled until backend permissions are designed."
    },
    {
      id: "kwame-osei",
      name: "Kwame Osei",
      email: "kwame@knustgadgets.com",
      phone: "+233 55 120 3322",
      role: "Viewer",
      status: "Suspended",
      lastActive: "10 Jul 2026, 4:10 PM",
      avatar: "KO",
      productsUpdated: 1,
      ordersPrepared: 0,
      stockChanges: 1,
      summary: "Future viewer role example with limited access."
    }
  ] satisfies TeamMember[],
  permissionGroups: [
    {
      name: "Product permissions",
      permissions: [
        { label: "View products", owner: true, inventoryManager: true },
        { label: "Add products", owner: true, inventoryManager: true },
        { label: "Edit products", owner: true, inventoryManager: true },
        { label: "Upload product images placeholder", owner: true, inventoryManager: true },
        { label: "Request price change", owner: true, inventoryManager: true },
        { label: "Mark product out of stock", owner: true, inventoryManager: true }
      ]
    },
    {
      name: "Inventory permissions",
      permissions: [
        { label: "View stock", owner: true, inventoryManager: true },
        { label: "Restock", owner: true, inventoryManager: true },
        { label: "Adjust stock", owner: true, inventoryManager: true },
        { label: "View stock movements", owner: true, inventoryManager: true },
        { label: "Set low stock threshold", owner: true, inventoryManager: true }
      ]
    },
    {
      name: "Order permissions",
      permissions: [
        { label: "View supplier orders", owner: true, inventoryManager: true },
        { label: "Prepare orders", owner: true, inventoryManager: true },
        { label: "Mark order ready", owner: true, inventoryManager: true },
        { label: "Add packing note/proof placeholder", owner: true, inventoryManager: true }
      ]
    },
    {
      name: "Finance permissions",
      permissions: [
        { label: "View settlement summary", owner: true, inventoryManager: false, lockedForInventoryManager: true },
        { label: "Upload settlement proof", owner: true, inventoryManager: false, lockedForInventoryManager: true },
        { label: "Edit payout details", owner: true, inventoryManager: false, lockedForInventoryManager: true },
        { label: "Verify settlement", owner: true, inventoryManager: false, lockedForInventoryManager: true }
      ]
    },
    {
      name: "Team permissions",
      permissions: [
        { label: "Invite members", owner: true, inventoryManager: false, lockedForInventoryManager: true },
        { label: "Edit member permissions", owner: true, inventoryManager: false, lockedForInventoryManager: true },
        { label: "Remove members", owner: true, inventoryManager: false, lockedForInventoryManager: true }
      ]
    }
  ] satisfies PermissionGroup[],
  activity: [
    {
      id: "activity-restock-af1",
      actor: "Akua Boateng",
      role: "Inventory Manager",
      action: "Akua Boateng restocked Nike Air Force 1 size 42 by +12",
      target: "Nike Air Force 1 '07 Green & White",
      oldValue: "8 units",
      newValue: "20 units",
      timestamp: "15 Jul 2026, 10:24 AM",
      type: "Stock"
    },
    {
      id: "activity-order-ready",
      actor: "Akua Boateng",
      role: "Inventory Manager",
      action: "Akua Boateng marked order RSR-20260713-00021 ready",
      target: "RSR-20260713-00021",
      oldValue: "Preparing",
      newValue: "Ready",
      timestamp: "15 Jul 2026, 9:58 AM",
      type: "Order"
    },
    {
      id: "activity-role-change",
      actor: "Kofi Mensah",
      role: "Supplier Owner",
      action: "Kofi Mensah changed Akua's role to Inventory Manager",
      target: "Akua Boateng",
      oldValue: "Viewer",
      newValue: "Inventory Manager",
      timestamp: "14 Jul 2026, 5:30 PM",
      type: "Team"
    },
    {
      id: "activity-reservation",
      actor: "System",
      role: "System",
      action: "System recorded stock reservation for order RSR-20260713-00021",
      target: "Samsung Galaxy A14",
      oldValue: "18 available",
      newValue: "17 available",
      timestamp: "13 Jul 2026, 10:26 AM",
      type: "Product"
    },
    {
      id: "activity-price",
      actor: "Akua Boateng",
      role: "Inventory Manager",
      action: "Akua Boateng requested price change for iPhone 14 Pro Max Case",
      target: "iPhone 14 Pro Max Case",
      oldValue: "GHC60",
      newValue: "GHC70",
      timestamp: "12 Jul 2026, 3:18 PM",
      type: "Price"
    }
  ] satisfies TeamActivity[],
  inventoryManager: {
    name: "Akua Boateng",
    greeting: "Hello, Akua",
    assignedSupplier: "KNUST Gadgets",
    productsNeedingStockUpdates: 3,
    ordersToPrepare: 5,
    lowStockAlerts: 2,
    recentActivity: "Restocked Nike Air Force 1 size 42 by +12"
  },
  products: [
    { id: "samsung-galaxy-a14", name: "Samsung Galaxy A14", category: "Mobile Phones", stockStatus: "In Stock", stock: 18 },
    { id: "nike-air-force-1-07-green-white", name: "Nike Air Force 1 '07 Green & White", category: "Sneakers", stockStatus: "Low Stock", stock: 3 },
    { id: "jean-paul-gaultier-le-male-edt", name: "Jean Paul Gaultier Le Male EDT", category: "Perfumes", stockStatus: "Needs Restock", stock: 2 },
    { id: "iphone-14-pro-max-case", name: "iPhone 14 Pro Max Case", category: "Phone Accessories", stockStatus: "Out of Stock", stock: 0 }
  ],
  orders: [
    { id: "RSR-20260713-00021", product: "Samsung Galaxy A14", quantity: 1, customerArea: "Legon, Accra", status: "Preparing" },
    { id: "RSR-20260713-00022", product: "Nike Air Force 1 '07 Green & White", quantity: 1, customerArea: "Madina, Accra", status: "Customer Confirmed" },
    { id: "RSR-20260712-00018", product: "Jean Paul Gaultier Le Male EDT", quantity: 1, customerArea: "KNUST Campus", status: "Preparing" }
  ],
  accessDenied: {
    role: "Inventory Manager",
    missingPermission: "Edit payout details",
    example: "Inventory Manager cannot edit payout details."
  }
} as const;

export function getTeamMember(memberId: string) {
  return supplierTeamMock.members.find((member) => member.id === memberId) ?? supplierTeamMock.members[1];
}
