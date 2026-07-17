import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isProtectedRoute = createRouteMatcher([
  "/checkout/account(.*)",
  "/checkout/delivery(.*)",
  "/checkout/payment(.*)",
  "/checkout/review(.*)",
  "/checkout/success(.*)",
  "/customer(.*)",
  "/reseller(.*)",
  "/supplier(.*)",
  "/admin(.*)"
]);

export default clerkMiddleware(async (auth, request) => {
  if (isProtectedRoute(request)) {
    await auth.protect();
  }
});

export const config = {
  matcher: ["/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|png|gif|svg|webp|ico|woff2?|ttf|map)).*)"]
};
