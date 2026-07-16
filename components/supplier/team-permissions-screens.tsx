"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { useState } from "react";
import { Button, Card, Input, StatusBadge } from "@/components/ui";
import { MobileShell } from "@/components/layout";
import {
  getTeamMember,
  supplierTeamMock,
  type Permission,
  type PermissionGroup,
  type TeamActivity,
  type TeamMember
} from "@/lib/mock/supplier-team";
import { cn } from "@/lib/utils/cn";

type TeamNavKey = "home" | "products" | "orders" | "team" | "account";

const teamNavItems: Array<{ key: TeamNavKey; label: string; href: string; icon: string }> = [
  { key: "home", label: "Home", href: "/supplier/dashboard", icon: "H" },
  { key: "products", label: "Products", href: "/supplier/products", icon: "P" },
  { key: "orders", label: "Orders", href: "/supplier/orders", icon: "O" },
  { key: "team", label: "Team", href: "/supplier/team", icon: "T" },
  { key: "account", label: "Account", href: "/supplier/settings", icon: "S" }
];

function TeamShell({ children, title }: { children: ReactNode; title?: string }) {
  return (
    <MobileShell title={title} footer={<TeamBottomNav active="team" />}>
      {children}
    </MobileShell>
  );
}

function InventoryManagerShell({ children, title }: { children: ReactNode; title?: string }) {
  return (
    <MobileShell title={title} footer={<TeamBottomNav active="products" />}>
      {children}
    </MobileShell>
  );
}

function TeamBottomNav({ active }: { active: TeamNavKey }) {
  return (
    <nav aria-label="Supplier team navigation" className="fixed inset-x-0 bottom-0 z-20 border-t border-[var(--color-border)] bg-white/95 px-3 py-2 backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-1">
        {teamNavItems.map((item) => (
          <Link
            key={item.key}
            href={item.href}
            className={cn(
              "flex min-h-12 flex-col items-center justify-center gap-1 rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]",
              active === item.key && "bg-[var(--color-primary-subtle)] text-[var(--color-primary)]"
            )}
          >
            <span
              aria-hidden="true"
              className={cn(
                "grid h-5 w-5 place-items-center rounded-full border border-[var(--color-border)] text-[10px]",
                active === item.key && "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
              )}
            >
              {item.icon}
            </span>
            {item.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}

function TeamHeader({ eyebrow = "Supplier team", title, description }: { eyebrow?: string; title: string; description?: string }) {
  return (
    <header className="mb-5 space-y-2">
      <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{eyebrow}</p>
      <h1 className="text-2xl font-extrabold text-[var(--color-charcoal)]">{title}</h1>
      {description ? <p className="text-sm leading-6 text-[var(--color-muted)]">{description}</p> : null}
    </header>
  );
}

function RoleBadge({ role }: { role: string }) {
  const tone = role === "Supplier Owner" ? "success" : role === "Inventory Manager" ? "info" : role === "Finance Staff" ? "warning" : "neutral";
  return <StatusBadge tone={tone}>{role}</StatusBadge>;
}

function MemberStatusBadge({ status }: { status: string }) {
  const tone = status === "Active" ? "success" : status === "Pending Invite" ? "warning" : "danger";
  return <StatusBadge tone={tone}>{status}</StatusBadge>;
}

function Avatar({ member }: { member: Pick<TeamMember, "avatar" | "name"> }) {
  return (
    <div aria-label={`${member.name} avatar`} className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-[var(--color-primary-subtle)] text-sm font-extrabold text-[var(--color-primary)]">
      {member.avatar}
    </div>
  );
}

function TeamMemberCard({ member }: { member: TeamMember }) {
  return (
    <Card className="p-4">
      <div className="flex gap-3">
        <Avatar member={member} />
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <div>
              <h3 className="font-bold text-[var(--color-charcoal)]">{member.name}</h3>
              <p className="mt-1 text-xs text-[var(--color-muted)]">{member.email}</p>
            </div>
            <MemberStatusBadge status={member.status} />
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            <RoleBadge role={member.role} />
            {member.role === "Finance Staff" || member.role === "Viewer" ? <StatusBadge tone="warning">future/disabled</StatusBadge> : null}
          </div>
          <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">{member.summary}</p>
          <Link className="mt-3 inline-flex h-10 w-full items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]" href={`/supplier/team/${member.id}`}>
            View Member
          </Link>
        </div>
      </div>
    </Card>
  );
}

function MetricCard({ label, value, detail, tone = "neutral" }: { label: string; value: string; detail: string; tone?: "success" | "warning" | "danger" | "info" | "neutral" }) {
  const classes = {
    success: "border-[var(--color-success)]/20 bg-[var(--color-success-soft)]",
    warning: "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)]",
    danger: "border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)]",
    info: "border-[var(--color-info)]/20 bg-[var(--color-info-soft)]",
    neutral: "border-[var(--color-border)] bg-white"
  };

  return (
    <Card className={cn("p-4", classes[tone])}>
      <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-extrabold">{value}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{detail}</p>
    </Card>
  );
}

function SafetyNote({ children, tone = "warning" }: { children: ReactNode; tone?: "warning" | "danger" | "success" }) {
  const classes = {
    warning: "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)] text-[#7A5300]",
    danger: "border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)] text-[var(--color-danger)]",
    success: "border-[var(--color-success)]/25 bg-[var(--color-success-soft)] text-[var(--color-primary)]"
  };

  return <div className={cn("rounded-[var(--radius-md)] border p-3 text-sm font-semibold leading-6", classes[tone])}>{children}</div>;
}

export function SupplierTeamOverviewScreen() {
  const members = supplierTeamMock.members;
  const active = members.filter((member) => member.status === "Active").length;
  const pending = members.filter((member) => member.status === "Pending Invite").length;
  const suspended = members.filter((member) => member.status === "Suspended").length;
  const owner = members[0];

  return (
    <TeamShell title="Supplier team">
      <TeamHeader title="Team Members" description="Manage trusted staff access for products, stock, and order preparation." />
      <Card className="mb-4 bg-[var(--color-primary)] text-white">
        <p className="text-sm font-semibold text-white/80">Supplier business name</p>
        <p className="mt-1 text-2xl font-extrabold">{supplierTeamMock.supplier.businessName}</p>
        <p className="mt-2 text-sm leading-6 text-white/80">{supplierTeamMock.supplier.location}</p>
      </Card>
      <Card title="Owner profile card">
        <div className="flex gap-3">
          <Avatar member={owner} />
          <div>
            <h2 className="font-bold">{owner.name}</h2>
            <p className="mt-1 text-sm text-[var(--color-muted)]">{owner.email}</p>
            <div className="mt-2"><RoleBadge role={owner.role} /></div>
          </div>
        </div>
      </Card>
      <div className="mt-4 grid grid-cols-3 gap-3">
        <MetricCard label="Active" value={String(active)} detail="Can access" tone="success" />
        <MetricCard label="Pending" value={String(pending)} detail="Invite sent" tone="warning" />
        <MetricCard label="Suspended" value={String(suspended)} detail="Blocked" tone="danger" />
      </div>
      <Link className="mt-4 inline-flex h-11 w-full items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white" href="/supplier/team/invite">
        Invite Team Member
      </Link>
      <SafetyNote>Only invite people you trust to manage products and stock.</SafetyNote>
      <Card title="Role badges">
        <div className="flex flex-wrap gap-2">
          {["Supplier Owner", "Inventory Manager", "Finance Staff", "Viewer"].map((role) => <RoleBadge key={role} role={role} />)}
        </div>
      </Card>
      <Card title="Team member list">
        <div className="space-y-3">{members.map((member) => <TeamMemberCard key={member.id} member={member} />)}</div>
      </Card>
      <Card title="Recent activity">
        <div className="space-y-3">{supplierTeamMock.activity.slice(0, 3).map((activity) => <ActivityItem key={activity.id} activity={activity} />)}</div>
      </Card>
    </TeamShell>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block text-sm font-bold text-[var(--color-charcoal)]">
      <span>{label}</span>
      <div className="mt-2">{children}</div>
    </label>
  );
}

export function InviteTeamMemberScreen() {
  const [sent, setSent] = useState(false);

  return (
    <TeamShell title="Invite team member">
      <TeamHeader title="Invite Inventory Manager" description="Mock invite flow. No real email or Clerk invitation is sent." />
      <Card title="Invite by email">
        <div className="space-y-4">
          <Field label="Staff name"><Input aria-label="Staff name" defaultValue="Akua Boateng" /></Field>
          <Field label="Email"><Input aria-label="Email" defaultValue="akua@knustgadgets.com" /></Field>
          <Field label="Role">
            <select aria-label="Role" className="h-11 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-4 text-sm font-semibold">
              <option>Inventory Manager</option>
              <option disabled>Finance Staff, future/disabled</option>
              <option disabled>Viewer, future/disabled</option>
            </select>
          </Field>
          <SafetyNote tone="success">Inventory managers can add products, update stock, restock products, and prepare orders.</SafetyNote>
          <SafetyNote>They cannot change payout details, verify settlements, or remove the supplier owner.</SafetyNote>
          <Card title="Permission preview" className="p-4">
            <PermissionPreview />
          </Card>
          <label className="flex min-h-11 items-center justify-between rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm font-bold">
            Temporary password option disabled
            <input aria-label="Temporary password option disabled" disabled type="checkbox" />
          </label>
          {sent ? <div role="status" className="rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">Invite success state</div> : <p className="text-sm font-semibold text-[var(--color-primary)]">Invite success state</p>}
          <Button className="w-full" onClick={() => setSent(true)}>Send Invite Mock</Button>
        </div>
      </Card>
    </TeamShell>
  );
}

function PermissionPreview() {
  return (
    <div className="space-y-2">
      {["Add products", "Update stock", "Restock products", "Prepare orders"].map((item) => (
        <div className="flex items-center justify-between rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={item}>
          <span className="text-sm font-semibold">{item}</span>
          <StatusBadge tone="success">Allowed</StatusBadge>
        </div>
      ))}
    </div>
  );
}

export function SupplierTeamMemberDetailScreen({ memberId }: { memberId: string }) {
  const member = getTeamMember(memberId);

  return (
    <TeamShell title="Team member detail">
      <TeamHeader title={member.name} description="Member profile, role, activity, and mock-only access controls." />
      <Card>
        <div className="flex gap-3">
          <Avatar member={member} />
          <div>
            <RoleBadge role={member.role} />
            <div className="mt-2"><MemberStatusBadge status={member.status} /></div>
            <p className="mt-3 text-sm text-[var(--color-muted)]">{member.email}</p>
            <p className="mt-1 text-sm text-[var(--color-muted)]">{member.phone}</p>
          </div>
        </div>
        <InfoRows rows={[["Last active", member.lastActive], ["Products updated", String(member.productsUpdated)], ["Orders prepared", String(member.ordersPrepared)], ["Stock changes", String(member.stockChanges)]]} />
      </Card>
      <Card title="Permissions summary"><p className="text-sm leading-6 text-[var(--color-muted)]">{member.summary}</p></Card>
      <Card title="Activity summary"><div className="space-y-3">{supplierTeamMock.activity.filter((activity) => activity.actor === member.name).slice(0, 3).map((activity) => <ActivityItem key={activity.id} activity={activity} />)}</div></Card>
      <div className="grid gap-2">
        <Link className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white" href={`/supplier/team/${member.id}/permissions`}>Edit Permissions</Link>
        <Button type="button" variant="outline">Suspend Access</Button>
        <Button type="button" variant="outline">Resend Invite</Button>
        <Button disabled type="button" variant="danger">Remove Member</Button>
      </div>
    </TeamShell>
  );
}

function InfoRows({ rows }: { rows: Array<[string, string]> }) {
  return (
    <dl className="mt-4 space-y-3 text-sm">
      {rows.map(([label, value]) => (
        <div key={label} className="flex justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-0">
          <dt className="text-[var(--color-muted)]">{label}</dt>
          <dd className="text-right font-bold">{value}</dd>
        </div>
      ))}
    </dl>
  );
}

export function TeamMemberPermissionsScreen({ memberId }: { memberId: string }) {
  const member = getTeamMember(memberId);

  return (
    <TeamShell title="Edit permissions">
      <TeamHeader title="Edit Permissions" description={`${member.name} - ${member.role}. Permission toggles are mock-only previews.`} />
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="font-bold">{member.name}</h2>
            <p className="mt-1 text-sm text-[var(--color-muted)]">{member.email}</p>
          </div>
          <RoleBadge role={member.role} />
        </div>
      </Card>
      <PermissionMatrix />
      <Button className="w-full" type="button">Save Permission Preview</Button>
    </TeamShell>
  );
}

function PermissionMatrix() {
  return (
    <div className="space-y-4">
      {supplierTeamMock.permissionGroups.map((group) => <PermissionGroupCard group={group} key={group.name} />)}
    </div>
  );
}

function PermissionGroupCard({ group }: { group: PermissionGroup }) {
  return (
    <Card title={group.name}>
      <div className="space-y-3">
        {group.permissions.map((permission) => <PermissionToggleRow key={permission.label} permission={permission} />)}
      </div>
    </Card>
  );
}

function PermissionToggleRow({ permission }: { permission: Permission }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold text-[var(--color-charcoal)]">{permission.label}</p>
          {permission.lockedForInventoryManager ? <p className="mt-1 text-xs font-semibold text-[var(--color-danger)]">Locked for Inventory Manager</p> : null}
        </div>
        <StatusBadge tone={permission.inventoryManager ? "success" : "danger"}>{permission.inventoryManager ? "Allowed" : "Blocked"}</StatusBadge>
      </div>
      <div className="mt-3 flex items-center justify-between text-xs text-[var(--color-muted)]">
        <span>Supplier Owner: {permission.owner ? "Allowed" : "Blocked"}</span>
        <input aria-label={`${permission.label} preview`} type="checkbox" checked={permission.inventoryManager} readOnly disabled={permission.lockedForInventoryManager} />
      </div>
    </div>
  );
}

export function SupplierTeamRolesScreen() {
  return (
    <TeamShell title="Role permissions">
      <TeamHeader title="Role Permissions Matrix" description="Compare supplier owner and inventory manager access before backend enforcement exists." />
      <Card title="Supplier Owner">
        <p className="text-sm leading-6 text-[var(--color-muted)]">Supplier Owner has all supplier workspace permissions.</p>
        <p className="mt-2 font-bold">all supplier workspace permissions</p>
      </Card>
      <Card title="Inventory Manager default">
        <p className="text-sm leading-6 text-[var(--color-muted)]">Can view/add/edit products, update stock, restock products, prepare orders, and mark orders ready.</p>
        <div className="mt-3 space-y-2 text-sm font-semibold text-[var(--color-danger)]">
          <p>cannot edit payout details</p>
          <p>cannot verify settlements</p>
          <p>cannot invite/remove staff</p>
          <p>cannot approve money actions</p>
          <p>cannot change owner/business verification</p>
        </div>
      </Card>
      <PermissionMatrix />
    </TeamShell>
  );
}

export function AccessDeniedStateScreen() {
  const denied = supplierTeamMock.accessDenied;

  return (
    <TeamShell title="Access denied">
      <Card className="text-center">
        <div className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-[var(--color-danger-soft)] text-3xl font-extrabold text-[var(--color-danger)]" aria-hidden="true">!</div>
        <h1 className="mt-4 text-xl font-extrabold">You do not have access to this page</h1>
        <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">This supplier workspace section is restricted to the supplier owner.</p>
        <div className="mt-4 flex justify-center"><RoleBadge role={denied.role} /></div>
        <p className="mt-3 font-bold">Missing permission: {denied.missingPermission}</p>
        <SafetyNote tone="danger">{denied.example}</SafetyNote>
        <div className="mt-5 grid gap-2">
          <Button type="button">Request Access</Button>
          <Button type="button" variant="outline">Go Back</Button>
          <Button type="button" variant="outline">Contact Supplier Owner</Button>
        </div>
      </Card>
    </TeamShell>
  );
}

export function SupplierTeamActivityScreen() {
  const filters = ["Product", "Stock", "Order", "Team", "Price"];

  return (
    <TeamShell title="Team activity">
      <TeamHeader title="Team Activity Log" description="Audit-style activity for stock, order, product, role, and price changes." />
      <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
        {filters.map((filter, index) => <Button key={filter} size="compact" type="button" variant={index === 0 ? "primary" : "outline"}>{filter}</Button>)}
      </div>
      <div className="space-y-3">{supplierTeamMock.activity.map((activity) => <ActivityItem key={activity.id} activity={activity} />)}</div>
    </TeamShell>
  );
}

function ActivityItem({ activity }: { activity: TeamActivity }) {
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold">{activity.actor}</p>
          <p className="mt-1 text-xs text-[var(--color-muted)]">{activity.role} - {activity.timestamp}</p>
        </div>
        <StatusBadge status={activity.type}>{activity.type}</StatusBadge>
      </div>
      <p className="mt-3 text-sm font-semibold leading-6">{activity.action}</p>
      <p className="mt-1 text-xs font-bold text-[var(--color-primary)]">{activity.target}</p>
      <div className="mt-3 grid grid-cols-2 gap-2 text-sm">
        <div className="rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] p-3"><p className="text-xs text-[var(--color-muted)]">Old value</p><p className="font-bold">{activity.oldValue}</p></div>
        <div className="rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3"><p className="text-xs text-[var(--color-muted)]">New value</p><p className="font-bold">{activity.newValue}</p></div>
      </div>
    </Card>
  );
}

export function InventoryManagerDashboardScreen() {
  const summary = supplierTeamMock.inventoryManager;

  return (
    <InventoryManagerShell title="Inventory manager">
      <TeamHeader eyebrow="Inventory manager" title="Inventory Manager Dashboard" description="Limited supplier staff view for products, stock, and order preparation only." />
      <Card className="mb-4 bg-[var(--color-primary)] text-white">
        <p className="text-sm font-semibold text-white/80">{summary.greeting}</p>
        <p className="mt-1 text-2xl font-extrabold">Assigned supplier</p>
        <p className="mt-2 text-sm leading-6 text-white/80">{summary.assignedSupplier}</p>
      </Card>
      <div className="grid grid-cols-2 gap-3">
        <MetricCard label="Products needing stock updates" value={String(summary.productsNeedingStockUpdates)} detail="Needs attention" tone="warning" />
        <MetricCard label="Orders to prepare" value={String(summary.ordersToPrepare)} detail="Confirmed orders" tone="info" />
        <MetricCard label="Low stock alerts" value={String(summary.lowStockAlerts)} detail="Below threshold" tone="warning" />
        <MetricCard label="Recent activity" value="1" detail={summary.recentActivity} tone="success" />
      </div>
      <Card title="Quick actions">
        <div className="grid gap-2">
          <Button type="button">Add Product</Button>
          <Button type="button" variant="outline">Restock Product</Button>
          <Button type="button" variant="outline">Prepare Orders</Button>
        </div>
      </Card>
      <SafetyNote>No finance or payout controls are available for this role.</SafetyNote>
    </InventoryManagerShell>
  );
}

export function InventoryManagerProductsScreen() {
  return (
    <InventoryManagerShell title="Inventory manager products">
      <TeamHeader eyebrow="Inventory manager" title="Inventory Manager Products" description="Product and stock work only. Finance details stay hidden." />
      <SafetyNote>No payout or settlement info is shown.</SafetyNote>
      <div className="mt-4 space-y-3">{supplierTeamMock.products.map((product) => <InventoryManagerProductCard key={product.id} product={product} />)}</div>
    </InventoryManagerShell>
  );
}

function InventoryManagerProductCard({ product }: { product: (typeof supplierTeamMock.products)[number] }) {
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="font-bold">{product.name}</h3>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{product.category}</p>
        </div>
        <StatusBadge status={product.stockStatus}>{product.stockStatus}</StatusBadge>
      </div>
      <InfoRows rows={[["Stock status", product.stockStatus], ["Available stock", String(product.stock)]]} />
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Button type="button" size="compact">Edit Product Mock</Button>
        <Button type="button" size="compact" variant="outline">Restock Mock</Button>
      </div>
    </Card>
  );
}

export function InventoryManagerOrdersScreen() {
  return (
    <InventoryManagerShell title="Inventory manager orders">
      <TeamHeader eyebrow="Inventory manager" title="Inventory Manager Orders" description="Prepare confirmed orders without settlement verification." />
      <Card title="Order prep list">
        <div className="space-y-3">{supplierTeamMock.orders.map((order) => <InventoryManagerOrderCard key={order.id} order={order} />)}</div>
      </Card>
      <SafetyNote>No settlement verification controls are available.</SafetyNote>
    </InventoryManagerShell>
  );
}

function InventoryManagerOrderCard({ order }: { order: (typeof supplierTeamMock.orders)[number] }) {
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold">{order.id}</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{order.product} - Qty {order.quantity}</p>
        </div>
        <StatusBadge status={order.status}>{order.status}</StatusBadge>
      </div>
      <InfoRows rows={[["Customer delivery area", order.customerArea], ["Product/quantity", `${order.product} / ${order.quantity}`]]} />
      <Button className="mt-4 w-full" type="button">Mark Ready Mock</Button>
    </Card>
  );
}

export function InventoryManagerSettingsScreen() {
  const member = getTeamMember("akua-boateng");

  return (
    <InventoryManagerShell title="Inventory manager settings">
      <TeamHeader eyebrow="Inventory manager" title="Inventory Manager Settings" description="Staff profile and permission summary only." />
      <Card title="Profile info">
        <InfoRows rows={[["Name", member.name], ["Email", member.email], ["Phone", member.phone], ["Assigned supplier", supplierTeamMock.inventoryManager.assignedSupplier]]} />
      </Card>
      <Card title="Role summary">
        <RoleBadge role={member.role} />
        <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">Can manage products, stock, restock, and prepare confirmed orders.</p>
      </Card>
      <Card title="Permissions summary">
        <PermissionPreview />
      </Card>
      <SafetyNote>No supplier owner settings are available.</SafetyNote>
      <div className="grid gap-2">
        <Button type="button">Request Access</Button>
        <Button type="button" variant="outline">Sign Out Placeholder</Button>
      </div>
    </InventoryManagerShell>
  );
}
