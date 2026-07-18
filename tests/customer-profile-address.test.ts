import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  archiveCustomerDeliveryAddressWithClient,
  buildCustomerAddressPayload,
  buildCustomerContactPayload,
  createCustomerDeliveryAddressWithClient,
  listCustomerDeliveryAddressesWithClient,
  mapCustomerProfileAddressRpcError,
  updateCustomerDeliveryAddressWithClient,
  upsertCustomerContactWithClient,
  type CustomerProfileAddressRpcClient
} from "@/lib/customer/profile-address";

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string; details?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: CustomerProfileAddressRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
      return {
        data: (response.data ?? null) as T,
        error: response.error ?? null
      };
    }
  };

  return { calls, client };
}

function readSourceTree(relativePath: string): string {
  const fullPath = join(process.cwd(), relativePath);
  const stat = statSync(fullPath);

  if (stat.isFile()) {
    return readFileSync(fullPath, "utf8");
  }

  return readdirSync(fullPath)
    .map((entry): string => readSourceTree(join(relativePath, entry)))
    .join("\n");
}

describe("Customer Phase A profile/address UI integration", () => {
  it("validates required customer contact values before calling RPC", () => {
    expect(() => buildCustomerContactPayload({ fullName: "", phone: "0200000000" })).toThrow("Full name is required");
    expect(() => buildCustomerContactPayload({ fullName: "Dev Customer", phone: " " })).toThrow("Phone is required");
  });

  it("calls upsert_customer_contact with safe contact fields only", async () => {
    const { calls, client } = createRpcSpyClient({ data: [{ profile_id: "profile-1", customer_id: "customer-1" }] });

    const result = await upsertCustomerContactWithClient(client, {
      fullName: " Dev Customer ",
      phone: " 0200000000 ",
      whatsapp: " 0200000001 ",
      email: " DEV@example.invalid "
    });

    expect(result).toMatchObject({ code: "OK" });
    expect(calls).toEqual([
      {
        name: "upsert_customer_contact",
        args: {
          p_full_name: "Dev Customer",
          p_phone: "0200000000",
          p_whatsapp: "0200000001",
          p_email: "dev@example.invalid"
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("primary_role");
    expect(calls[0].args).not.toHaveProperty("role");
  });

  it("validates required address values before calling RPC", () => {
    expect(() =>
      buildCustomerAddressPayload({
        label: "",
        recipientName: "Dev Customer",
        phone: "0200000000",
        region: "Greater Accra",
        city: "Accra",
        area: "Osu",
        streetAddress: "Fake street"
      })
    ).toThrow("Address label is required");
    expect(() =>
      buildCustomerAddressPayload({
        label: "Home",
        recipientName: "Dev Customer",
        phone: "0200000000",
        region: "Greater Accra",
        city: "",
        area: "Osu",
        streetAddress: "Fake street"
      })
    ).toThrow("City is required");
  });

  it("creates, updates, archives, and lists addresses through Customer Phase A RPCs", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [{ id: "address-1", label: "Home", is_default: true }]
    });

    await createCustomerDeliveryAddressWithClient(client, {
      label: "Home",
      recipientName: "Dev Customer",
      phone: "0200000000",
      region: "Greater Accra",
      city: "Accra",
      area: "Osu",
      streetAddress: "Fake street",
      landmark: "Fake landmark",
      isDefault: true
    });
    await updateCustomerDeliveryAddressWithClient(client, {
      addressId: "address-1",
      label: "Office",
      recipientName: "Dev Customer",
      phone: "0200000000",
      region: "Greater Accra",
      city: "Accra",
      area: "Airport",
      streetAddress: "Fake office street",
      isDefault: false
    });
    await archiveCustomerDeliveryAddressWithClient(client, "address-1");
    await listCustomerDeliveryAddressesWithClient(client);

    expect(calls.map((call) => call.name)).toEqual([
      "create_customer_delivery_address",
      "update_customer_delivery_address",
      "archive_customer_delivery_address",
      "get_customer_delivery_addresses"
    ]);
    expect(calls[0].args).toMatchObject({ p_is_default: true });
    expect(calls[1].args).toMatchObject({ p_address_id: "address-1", p_is_default: false });
    expect(calls[2].args).toEqual({ p_address_id: "address-1" });
  });

  it("maps auth, validation, and ownership errors safely", () => {
    expect(mapCustomerProfileAddressRpcError({ message: "AUTH_REQUIRED" })).toMatchObject({ code: "AUTH_REQUIRED" });
    expect(mapCustomerProfileAddressRpcError({ message: "PROFILE_SYNC_FAILED" })).toMatchObject({ code: "AUTH_REQUIRED" });
    expect(mapCustomerProfileAddressRpcError({ message: "phone is required" })).toMatchObject({ code: "VALIDATION_ERROR" });
    expect(mapCustomerProfileAddressRpcError({ message: "CUSTOMER_ADDRESS_NOT_FOUND" })).toMatchObject({ code: "ADDRESS_NOT_FOUND" });
  });

  it("keeps service role and live checkout/order/payment/delivery integration out of Customer Phase A UI", () => {
    const customerPhaseASources = [
      "app/customer/addresses",
      "components/customer/customer-profile-address-screens.tsx",
      "lib/customer/profile-address.ts"
    ].map(readSourceTree).join("\n");

    expect(customerPhaseASources).not.toContain("createSupabaseAdminClient");
    expect(customerPhaseASources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(customerPhaseASources).not.toContain(".from(\"customers\")");
    expect(customerPhaseASources).not.toContain(".from('customers')");
    expect(customerPhaseASources).toContain("upsert_customer_contact");
    expect(customerPhaseASources).toContain("create_customer_delivery_address");
    expect(customerPhaseASources).toContain("update_customer_delivery_address");
    expect(customerPhaseASources).toContain("archive_customer_delivery_address");

    const checkoutSources = readSourceTree("app/checkout");
    for (const rpcName of [
      "upsert_customer_contact",
      "create_customer_delivery_address",
      "update_customer_delivery_address",
      "archive_customer_delivery_address"
    ]) {
      expect(checkoutSources).not.toContain(rpcName);
    }

    expect(customerPhaseASources).not.toContain("create_order");
    expect(customerPhaseASources).not.toContain("reserve_stock");
    expect(customerPhaseASources).not.toContain("delivery_quote");
    expect(customerPhaseASources).not.toContain("payment");
    expect(customerPhaseASources).not.toContain("commission");
    expect(customerPhaseASources).not.toContain("settlement");
    expect(customerPhaseASources).not.toContain("withdrawal");
  });
});
