"use client"

import { useEffect } from "react"

export function ServiceWorkerRegister() {
  useEffect(() => {
    if (typeof window === "undefined") return
    if (!("serviceWorker" in navigator)) return
    if (process.env.NODE_ENV !== "production") return
    navigator.serviceWorker
      .register("/sw.js", { scope: "/android" })
      .catch((e) => console.warn("SW register failed", e))
  }, [])
  return null
}
