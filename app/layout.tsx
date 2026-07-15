import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Risellar Design Foundation",
  description: "Phase 1 design tokens and component gallery shell for Risellar."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
