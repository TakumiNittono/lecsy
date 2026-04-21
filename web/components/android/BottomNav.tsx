"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"

const items = [
  { href: "/android/app", label: "Home", icon: HomeIcon },
  { href: "/android/library", label: "Library", icon: LibraryIcon },
] as const

export function BottomNav() {
  const pathname = usePathname()
  return (
    <nav className="fixed bottom-0 inset-x-0 bg-white border-t border-gray-200 pb-[env(safe-area-inset-bottom)] z-30">
      <ul className="flex">
        {items.map(({ href, label, icon: Icon }) => {
          const active =
            pathname === href ||
            (href === "/android/library" && pathname.startsWith("/android/t/"))
          return (
            <li key={href} className="flex-1">
              <Link
                href={href}
                className={`flex flex-col items-center justify-center h-16 text-xs gap-1 ${
                  active ? "text-blue-600" : "text-gray-500"
                }`}
              >
                <Icon className="w-6 h-6" />
                {label}
              </Link>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}

function HomeIcon(props: { className?: string }) {
  return (
    <svg className={props.className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l9-9 9 9M5 10v10a1 1 0 001 1h3v-6h6v6h3a1 1 0 001-1V10" />
    </svg>
  )
}

function LibraryIcon(props: { className?: string }) {
  return (
    <svg className={props.className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h10" />
    </svg>
  )
}
