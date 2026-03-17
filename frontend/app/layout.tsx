import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Token Bank",
  description: "Token Bank frontend built with Next.js and Viem",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
