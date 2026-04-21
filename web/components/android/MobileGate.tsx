import QRCode from "qrcode"

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://www.lecsy.app"

export async function MobileGate() {
  const targetUrl = `${SITE_URL}/android`
  const qrSvg = await QRCode.toString(targetUrl, {
    type: "svg",
    margin: 1,
    width: 240,
    color: { dark: "#111111", light: "#ffffff" },
  })

  return (
    <main className="min-h-screen bg-white flex flex-col items-center justify-center px-6 py-16">
      <div className="max-w-md w-full text-center">
        <p className="text-xs font-semibold tracking-[0.2em] uppercase text-gray-400 mb-4">
          Lecsy for Android · Pilot
        </p>
        <h1 className="text-3xl sm:text-4xl font-semibold tracking-tight text-gray-900 mb-3">
          Open this on your phone.
        </h1>
        <p className="text-gray-500 leading-relaxed mb-10">
          Lecsy&rsquo;s Android PWA is designed for in-class use and needs a
          phone microphone. Scan this code with your Android phone to continue.
        </p>

        <div className="inline-flex p-5 rounded-2xl border border-gray-200 bg-white shadow-sm">
          <div
            className="w-60 h-60"
            dangerouslySetInnerHTML={{ __html: qrSvg }}
          />
        </div>

        <p className="mt-6 text-xs text-gray-400 break-all">{targetUrl}</p>

        <div className="mt-12 pt-8 border-t border-gray-100 text-left">
          <p className="text-xs font-semibold tracking-wider uppercase text-gray-400 mb-3">
            How to join
          </p>
          <ol className="space-y-3 text-sm text-gray-700">
            <li className="flex gap-3">
              <span className="flex-none w-5 h-5 rounded-full bg-gray-900 text-white text-[11px] leading-5 text-center font-semibold">
                1
              </span>
              <span>Scan the code above with your Android phone&rsquo;s camera.</span>
            </li>
            <li className="flex gap-3">
              <span className="flex-none w-5 h-5 rounded-full bg-gray-900 text-white text-[11px] leading-5 text-center font-semibold">
                2
              </span>
              <span>Type the 6-character invite code your teacher gave you.</span>
            </li>
            <li className="flex gap-3">
              <span className="flex-none w-5 h-5 rounded-full bg-gray-900 text-white text-[11px] leading-5 text-center font-semibold">
                3
              </span>
              <span>
                Tap <span className="font-medium text-gray-900">Add to Home screen</span>{" "}
                when Chrome prompts &mdash; Lecsy behaves like an installed app.
              </span>
            </li>
          </ol>
        </div>

        <p className="mt-10 text-xs text-gray-400">
          Personal users on iPhone &mdash;{" "}
          <a
            href="/"
            className="text-gray-600 underline underline-offset-2 hover:text-gray-900"
          >
            get the iOS app
          </a>
          .
        </p>
      </div>
    </main>
  )
}
