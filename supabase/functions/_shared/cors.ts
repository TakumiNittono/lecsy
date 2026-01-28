// supabase/functions/_shared/cors.ts

// 許可するオリジンのリスト
const ALLOWED_ORIGINS = [
  // 本番環境
  'https://lecsy.vercel.app',
  'https://www.lecsy.app',
  // 開発環境
  'http://localhost:3000',
  'http://localhost:54323',  // Supabase Studio
];

// 追加のオリジン（環境変数から取得）
const EXTRA_ORIGINS = Deno.env.get('ALLOWED_ORIGINS')?.split(',') || [];
const ALL_ALLOWED_ORIGINS = [...ALLOWED_ORIGINS, ...EXTRA_ORIGINS];

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
  
  // 許可されていない場合はデフォルトのオリジンを返す
  // （これによりCORSエラーが発生する）
  return ALL_ALLOWED_ORIGINS[0] || 'https://lecsy.vercel.app';
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
