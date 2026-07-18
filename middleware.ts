import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";

const isProtectedRoute = createRouteMatcher([
  "/checkout/account(.*)",
  "/checkout/delivery(.*)",
  "/checkout/payment(.*)",
  "/checkout/review(.*)",
  "/checkout/success(.*)",
  "/customer(.*)",
  "/onboarding(.*)",
  "/reseller(.*)",
  "/supplier(.*)",
  "/admin(.*)",
  "/auth/qa-profile-sync(.*)"
]);

export default clerkMiddleware(async (auth, request) => {
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-risellar-pathname", request.nextUrl.pathname);

  if (isProtectedRoute(request)) {
    await auth.protect();
  }

  return NextResponse.next({
    request: {
      headers: requestHeaders
    }
  });
});

export const config = {
  matcher: ["/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|png|gif|svg|webp|ico|woff2?|ttf|map)).*)"]
};
