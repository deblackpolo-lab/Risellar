import { CustomerProfileAddressScreen } from "@/components/customer/customer-profile-address-screens";
import { getCustomerAddressesForCurrentUser } from "./actions";

export default async function CustomerAddressesPage() {
  const result = await getCustomerAddressesForCurrentUser();

  return <CustomerProfileAddressScreen addresses={result.addresses} error={result.error} />;
}
