// supabase/functions/_shared/cors.ts
//
// 許可オリジンは ALLOWED_ORIGINS env (カンマ区切り) で全部設定する。
// (旧コードはハードコード + env のミックスだったが、ハードコードが drift する
//  ので env 1 本に統一。localhost 系だけは開発体験のためデフォルトで残す)
//
// 設定例:
//   supabase secrets set ALLOWED_ORIGINS='https://admin.lecsy.app,https://web-xxx.vercel.app'

const LOCAL_DEV_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:3020',
  'http://localhost:54323',  // Supabase Studio
];

const ENV_ORIGINS = Deno.env.get('ALLOWED_ORIGINS')?.split(',').map(s => s.trim()).filter(Boolean) ?? [];
const ALL_ALLOWED_ORIGINS = [...LOCAL_DEV_ORIGINS, ...ENV_ORIGINS];

/**
 * オリジンが許可されているかチェック
 */
export function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false;
  return ALL_ALLOWED_ORIGINS.includes(origin);
}

/**
 * CORSレスポンスを取得
 */
export function getCorsOrigin(request: Request): string {
  const origin = request.headers.get('origin');
  
  // 許可されたオリジンの場合はそのオリジンを返す
  if (origin && isAllowedOrigin(origin)) {
    return origin;
  }
  
  // 許可されていない場合はデフォルトを返す (これにより CORS エラー)
  return ALL_ALLOWED_ORIGINS[0] || 'http://localhost:3020';
}

/**
 * CORSヘッダーを取得
 */
export function getCorsHeaders(request: Request): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': getCorsOrigin(request),
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info',
    'Access-Control-Max-Age': '86400',  // 24時間キャッシュ
    'Access-Control-Allow-Credentials': 'true',
  };
}

/**
 * プリフライトリクエストのレスポンスを作成
 */
export function createPreflightResponse(request: Request): Response {
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(request),
  });
}

/**
 * CORSヘッダー付きのJSONレスポンスを作成
 */
export function createJsonResponse(
  request: Request,
  data: unknown,
  status: number = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...getCorsHeaders(request),
    },
  });
}

/**
 * CORSヘッダー付きのエラーレスポンスを作成
 */
export function createErrorResponse(
  request: Request,
  error: string,
  status: number = 400
): Response {
  return createJsonResponse(request, { error }, status);
}
