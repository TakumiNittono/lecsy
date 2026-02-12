/**
 * リダイレクトパス検証（オープンリダイレクト対策）
 * サーバー・クライアント両方で使用可能（依存関係なし）
 */

/**
 * リダイレクトパスを検証
 * 相対パスのみ許可し、外部URLへのリダイレクトを防止
 */
export function isValidRedirectPath(path: string | null | undefined): boolean {
  if (!path || typeof path !== 'string') return false
  const trimmed = path.trim()
  if (!trimmed.startsWith('/')) return false
  if (trimmed.includes('//')) return false
  if (trimmed.includes(':')) return false
  return true
}

/**
 * 安全なリダイレクトパスを取得
 */
export function getSafeRedirectPath(path: string | null | undefined, defaultPath = '/app'): string {
  return isValidRedirectPath(path) ? path!.trim() : defaultPath
}
