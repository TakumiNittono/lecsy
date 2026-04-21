/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async headers() {
    const baseSecurityHeaders = [
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'X-XSS-Protection', value: '1; mode=block' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
    ]
    return [
      // Marketing / dashboard surfaces: keep mic/camera/geo blocked.
      {
        source: '/((?!android).*)',
        headers: [
          ...baseSecurityHeaders,
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
      // Android PWA needs microphone for live recording.
      {
        source: '/android/:path*',
        headers: [
          ...baseSecurityHeaders,
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(self), geolocation=()' },
        ],
      },
      {
        source: '/android',
        headers: [
          ...baseSecurityHeaders,
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(self), geolocation=()' },
        ],
      },
      // Service worker must be served with a permissive Service-Worker-Allowed
      // header so it can claim the /android scope.
      {
        source: '/sw.js',
        headers: [
          { key: 'Service-Worker-Allowed', value: '/android' },
          { key: 'Cache-Control', value: 'no-cache' },
        ],
      },
    ]
  },
}

module.exports = nextConfig
