import { ServiceWorkerRegister } from "@/components/android/ServiceWorkerRegister"
import { BottomNavWrapper } from "@/components/android/BottomNavWrapper"

export const dynamic = "force-dynamic"

export default function AndroidLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="min-h-screen bg-white">
      <ServiceWorkerRegister />
      <div className="pb-20">{children}</div>
      <BottomNavWrapper />
    </div>
  )
}
