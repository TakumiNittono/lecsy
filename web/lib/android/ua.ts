export function isAndroid(userAgent: string | null | undefined): boolean {
  if (!userAgent) return false
  return /Android/i.test(userAgent) && !/Windows Phone/i.test(userAgent)
}

export function isIOS(userAgent: string | null | undefined): boolean {
  if (!userAgent) return false
  return /iPad|iPhone|iPod/i.test(userAgent) && !/Windows Phone/i.test(userAgent)
}
