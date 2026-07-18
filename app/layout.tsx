import { ClerkProvider } from "@clerk/nextjs";
import type { Metadata } from "next";
import { RouteAccessBoundary } from "@/lib/auth/route-access-boundary";
import "react-photo-view/dist/react-photo-view.css";
import "./globals.css";

export const metadata: Metadata = {
  title: "Risellar Design Foundation",
  description: "Phase 1 design tokens and component gallery shell for Risellar."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>
          <RouteAccessBoundary>{children}</RouteAccessBoundary>
        </body>
      </html>
    </ClerkProvider>
  );
}
