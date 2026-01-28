import DOMPurify from 'dompurify';

/**
 * サーバーサイドでHTMLタグを除去（シンプルな実装）
 */
function stripHTMLTagsServer(input: string): string {
  if (!input || typeof input !== 'string') return '';
  // HTMLタグを正規表現で除去
  return input.replace(/<[^>]*>/g, '');
}

/**
 * クライアントサイドでHTMLタグを除去（DOMPurify使用）
 */
function stripHTMLTagsClient(input: string): string {
  if (!input || typeof input !== 'string') return '';
  return DOMPurify.sanitize(input, {
    ALLOWED_TAGS: [], // すべてのタグを禁止
    ALLOWED_ATTR: [], // すべての属性を禁止
  });
}

/**
 * テキストをサニタイズ（HTMLタグを完全に除去）
 */
export function sanitizeText(input: string | null | undefined): string {
  if (!input) return '';
  
  // サーバーサイドとクライアントサイドで異なる実装を使用
  if (typeof window === 'undefined') {
    // サーバーサイド: シンプルな正規表現で除去
    return stripHTMLTagsServer(input);
  } else {
    // クライアントサイド: DOMPurifyを使用
    return stripHTMLTagsClient(input);
  }
}

/**
 * テキストをサニタイズ（安全なHTMLタグのみ許可）
 */
export function sanitizeHTML(input: string | null | undefined): string {
  if (!input) return '';
  
  // クライアントサイドのみで使用（サーバーサイドでは使用しない）
  if (typeof window === 'undefined') {
    // サーバーサイドではHTMLタグをすべて除去
    return stripHTMLTagsServer(input);
  }
  
  // クライアントサイド: DOMPurifyを使用
  return DOMPurify.sanitize(input, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: [],
  });
}

/**
 * URLをサニタイズ（危険なプロトコルを除去）
 */
export function sanitizeURL(url: string | null | undefined): string {
  if (!url) return '';
  
  // 許可するプロトコル
  const allowedProtocols = ['http:', 'https:', 'mailto:'];
  
  try {
    const parsed = new URL(url);
    if (!allowedProtocols.includes(parsed.protocol)) {
      return '';
    }
    return url;
  } catch {
    return '';
  }
}

/**
 * 検索クエリをエスケープ（正規表現用）
 */
export function escapeRegExp(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
