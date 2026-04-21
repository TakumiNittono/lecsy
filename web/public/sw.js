// Lecsy Android PWA service worker.
// Strategy:
//   - Network-first for navigations (so auth state is fresh)
//   - Stale-while-revalidate for /icons + manifest
//   - Never cache /api or supabase calls (auth + tokens)

const VERSION = "lecsy-android-v1"
const SHELL_CACHE = `${VERSION}-shell`

const SHELL_ASSETS = [
  "/manifest.webmanifest",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
  "/icons/icon-maskable-512.png",
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE).then((c) => c.addAll(SHELL_ASSETS)).then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => !k.startsWith(VERSION)).map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const req = event.request
  const url = new URL(req.url)

  if (req.method !== "GET") return
  if (url.origin !== self.location.origin) return
  if (url.pathname.startsWith("/api/")) return
  if (url.pathname.startsWith("/auth/")) return

  // Stale-while-revalidate for shell-ish assets
  if (
    url.pathname.startsWith("/icons/") ||
    url.pathname === "/manifest.webmanifest"
  ) {
    event.respondWith(
      caches.open(SHELL_CACHE).then(async (cache) => {
        const cached = await cache.match(req)
        const network = fetch(req)
          .then((res) => {
            if (res.ok) cache.put(req, res.clone())
            return res
          })
          .catch(() => cached)
        return cached || network
      })
    )
    return
  }

  // For /android navigations: network-first, fall back to cached shell
  if (req.mode === "navigate" && url.pathname.startsWith("/android")) {
    event.respondWith(
      fetch(req).catch(() => caches.match("/android"))
    )
  }
})
