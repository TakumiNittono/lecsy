import Link from "next/link";
import SEOFooter from "./SEOFooter";
import CTASection from "./CTASection";
import BreadcrumbJsonLd from "./BreadcrumbJsonLd";
import { APP_STORE_URL } from "@/lib/constants";

interface SEOPageLayoutProps {
  children: React.ReactNode;
  breadcrumbs: Array<{ name: string; url: string }>;
}

export default function SEOPageLayout({ children, breadcrumbs }: SEOPageLayoutProps) {
  return (
    <main className="min-h-screen bg-white">
      {/* Breadcrumb JSON-LD */}
      <BreadcrumbJsonLd items={breadcrumbs} />

      {/* Header */}
      <header className="border-b border-gray-200 sticky top-0 bg-white/80 backdrop-blur-sm z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <Link href="/" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
            lecsy
          </Link>
          <div className="flex gap-4">
            {/*
              Web B2C 動線は 2026-04-21 時点で全て非表示。SEO ランディング
              からの Login / Get Started も iOS ダウンロードに置き換え。
              B2C 再開時にこのブロックを戻す。
            */}
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="px-6 py-2 bg-gradient-to-r from-blue-600 to-blue-500 text-white rounded-lg hover:from-blue-700 hover:to-blue-600 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
            >
              Download for iPhone
            </a>
          </div>
        </div>
      </header>

      {/* Content */}
      {children}

      {/* CTA Section */}
      <CTASection />

      {/* Footer */}
      <SEOFooter />
    </main>
  );
}
