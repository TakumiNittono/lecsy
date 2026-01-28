import DOMPurify from 'dompurify';

// サーバーサイドでのDOMPurify使用のためのポリフィル
let purify: typeof DOMPurify;

if (typeof window === 'undefined') {
  // サーバーサイド: jsdomを使用
  const { JSDOM } = require('jsdom');
  const window = new JSDOM('').window;
  purify = DOMPurify(window as unknown as Window & typeof globalThis);
} else {
  // クライアントサイド
  purify = DOMPurify;
}

/**
 * テキストをサニタイズ（HTMLタグを完全に除去）
 */
export function sanitizeText(input: string | null | undefined): string {
  if (!input) return '';
  
  // HTMLタグをすべて除去
  return purify.sanitize(input, {
    ALLOWED_TAGS: [], // すべてのタグを禁止
    ALLOWED_ATTR: [], // すべての属性を禁止
  });
}

/**
 * テキストをサニタイズ（安全なHTMLタグのみ許可）
 */
export function sanitizeHTML(input: string | null | undefined): string {
  if (!input) return '';
  
  // 安全なタグのみ許可
  return purify.sanitize(input, {
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
