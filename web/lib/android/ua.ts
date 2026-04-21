export function isAndroid(userAgent: string | null | undefined): boolean {
  if (!userAgent) return false
  return /Android/i.test(userAgent) && !/Windows Phone/i.test(userAgent)
}

export function isIOS(userAgent: string | null | undefined): boolean {
  if (!userAgent) return false
  return /iPad|iPhone|iPod/i.test(userAgent) && !/Windows Phone/i.test(userAgent)
}

// "Mobile" for our purposes means a handheld the PWA can usefully run on.
// Tablets (iPadOS, Android tablets) qualify. Desktop Chrome's device-mode
// emulation also sets these UAs so testing still works.
export function isMobile(userAgent: string | null | undefined): boolean {
  return isAndroid(userAgent) || isIOS(userAgent)
}
