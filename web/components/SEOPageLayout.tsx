import Link from "next/link";
import SEOFooter from "./SEOFooter";
import CTASection from "./CTASection";
import BreadcrumbJsonLd from "./BreadcrumbJsonLd";

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
            <Link
              href="/login"
              className="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors font-medium"
            >
              Login
            </Link>
            <Link
              href="/login"
              className="px-6 py-2 bg-gradient-to-r from-blue-600 to-blue-500 text-white rounded-lg hover:from-blue-700 hover:to-blue-600 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
            >
              Get Started
            </Link>
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
