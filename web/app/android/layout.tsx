import { headers } from "next/headers"
import { ServiceWorkerRegister } from "@/components/android/ServiceWorkerRegister"
import { BottomNavWrapper } from "@/components/android/BottomNavWrapper"
import { MobileGate } from "@/components/android/MobileGate"
import { isMobile } from "@/lib/android/ua"

export const dynamic = "force-dynamic"

export default async function AndroidLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const h = headers()
  const ua = h.get("user-agent")

  // PWA は phone microphone 前提なので PC では使わせない。
  // LP の "Android (Invite)" ボタンを PC で押した人はここに着地して QR へ誘導。
  if (!isMobile(ua)) {
    return <MobileGate />
  }

  return (
    <div className="min-h-screen bg-white">
      <ServiceWorkerRegister />
      <div className="pb-20">{children}</div>
      <BottomNavWrapper />
    </div>
  )
}
