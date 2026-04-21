"use client"

import { usePathname } from "next/navigation"
import { BottomNav } from "./BottomNav"

export function BottomNavWrapper() {
  const pathname = usePathname()
  // Hide nav on entry / record screens
  if (pathname === "/android" || pathname === "/android/" || pathname.startsWith("/android/record")) {
    return null
  }
  return <BottomNav />
}
