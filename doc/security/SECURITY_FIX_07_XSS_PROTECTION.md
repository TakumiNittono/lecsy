# セキュリティ修正 #7: XSS対策の強化

**重要度**: 高  
**対象ファイル**: 
- `web/app/app/t/[id]/page.tsx`
- `web/components/TranscriptList.tsx`

**推定作業時間**: 20分

---

## 現状の問題

ユーザー入力（transcript.content）が直接レンダリングされており、XSS攻撃のリスクがあります。

### page.tsx (212行目)
```tsx
<div className="...">
  {transcript.content}
</div>
```

Reactは自動的にエスケープしますが、追加の保護層があると安全です。

---

## 修正手順

### Step 1: DOMPurify のインストール

```bash
cd web
npm install dompurify
npm install --save-dev @types/dompurify
```

---

### Step 2: サニタイズユーティリティの作成

新規ファイル: `web/utils/sanitize.ts`

```typescript
import DOMPurify from 'dompurify';

// サーバーサイドでのDOMPurify使用のためのポリフィル
let purify: typeof DOMPurify;

if (typeof window === 'undefined') {
  // サーバーサイド: jsdomを使用
  const { JSDOM } = require('jsdom');
  const window = new JSDOM('').window;
  purify = DOMPurify(window);
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
```

---

### Step 3: jsdom のインストール（SSR用）

```bash
npm install jsdom
npm install --save-dev @types/jsdom
```

---

### Step 4: page.tsx の修正

**変更前** (185-227行目):
```tsx
{transcript.content ? (
  <div className="relative">
    <div 
      className="prose prose-lg max-w-none ..."
      style={{...}}
    >
      {transcript.content}
    </div>
    ...
  </div>
) : (...)}
```

**変更後**:
```tsx
import { sanitizeText } from '@/utils/sanitize';

// ... コンポーネント内

{transcript.content ? (
  <div className="relative">
    <div 
      className="prose prose-lg max-w-none 
        text-gray-900 
        leading-7 
        font-normal
        whitespace-pre-wrap 
        break-words
        selection:bg-blue-200
        selection:text-gray-900
        focus:outline-none
        p-4
        bg-gray-50
        rounded-lg
        border border-gray-200
        min-h-[200px]
        max-h-[70vh]
        overflow-y-auto
        scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100"
      style={{
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        fontSize: '16px',
        lineHeight: '1.75',
      }}
    >
      {/* サニタイズしたテキストを表示 */}
      {sanitizeText(transcript.content)}
    </div>
    
    {/* スクロールインジケーター */}
    <div className="mt-2 text-xs text-gray-400 text-center">
      Scroll to read full transcript
    </div>
  </div>
) : (
  <div className="text-center py-12 text-gray-500">
    ...
  </div>
)}
```

---

### Step 5: TranscriptList.tsx の修正

**変更前** (46-65行目):
```tsx
const highlightMatch = (text: string) => {
  if (!searchQuery) return text;
  const escapedQuery = searchQuery.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`(${escapedQuery})`, 'gi');
  const parts = text.split(regex);
  return parts.map((part, i) =>
    part.toLowerCase() === searchQuery.toLowerCase() ? (
      <mark key={i} className="bg-yellow-200 rounded px-0.5">{part}</mark>
    ) : (
      part
    )
  );
};
```

**変更後**:
```tsx
import { sanitizeText, escapeRegExp } from '@/utils/sanitize';

const highlightMatch = (text: string) => {
  // 入力をサニタイズ
  const sanitizedText = sanitizeText(text);
  
  if (!searchQuery) return sanitizedText;
  
  // 検索クエリをサニタイズしてエスケープ
  const sanitizedQuery = sanitizeText(searchQuery);
  const escapedQuery = escapeRegExp(sanitizedQuery);
  
  if (!escapedQuery) return sanitizedText;
  
  try {
    const regex = new RegExp(`(${escapedQuery})`, 'gi');
    const parts = sanitizedText.split(regex);
    
    return parts.map((part, i) =>
      part.toLowerCase() === sanitizedQuery.toLowerCase() ? (
        <mark key={i} className="bg-yellow-200 rounded px-0.5">{part}</mark>
      ) : (
        part
      )
    );
  } catch {
    // 正規表現エラーの場合はそのまま返す
    return sanitizedText;
  }
};
```

---

### Step 6: タイトル編集フォームの入力検証

**ファイル**: `web/components/EditTitleForm.tsx`

```typescript
import { sanitizeText } from '@/utils/sanitize';

// フォーム送信時
const handleSubmit = async (formData: FormData) => {
  const rawTitle = formData.get('title') as string;
  
  // サニタイズ
  const title = sanitizeText(rawTitle);
  
  // 長さチェック
  if (title.length === 0) {
    setError('Title cannot be empty');
    return;
  }
  
  if (title.length > 200) {
    setError('Title cannot exceed 200 characters');
    return;
  }
  
  // ... API呼び出し
};
```

---

## Content Security Policy (CSP) の設定

### next.config.js に追加

```javascript
// next.config.js

const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",  // Next.jsに必要
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self'",
      "connect-src 'self' https://*.supabase.co https://api.stripe.com",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
    ].join('; ')
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff'
  },
  {
    key: 'X-Frame-Options',
    value: 'DENY'
  },
  {
    key: 'X-XSS-Protection',
    value: '1; mode=block'
  },
  {
    key: 'Referrer-Policy',
    value: 'strict-origin-when-cross-origin'
  }
];

module.exports = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders,
      },
    ];
  },
  // ... 他の設定
};
```

---

## 確認チェックリスト

- [ ] DOMPurify をインストール
- [ ] jsdom をインストール
- [ ] `utils/sanitize.ts` を作成
- [ ] `page.tsx` でサニタイズを適用
- [ ] `TranscriptList.tsx` でサニタイズを適用
- [ ] `EditTitleForm.tsx` で入力検証を追加
- [ ] CSP ヘッダーを設定
- [ ] XSS攻撃のテストを実施

---

## テスト方法

### XSS攻撃のテスト

1. データベースに直接テスト用の悪意あるコンテンツを挿入:

```sql
-- テスト用（本番では実行しない）
INSERT INTO transcripts (user_id, title, content)
VALUES (
  'your-user-id',
  '<script>alert("XSS")</script>',
  '<img src=x onerror=alert("XSS")>'
);
```

2. アプリでこのデータを表示し、スクリプトが実行されないことを確認

期待される結果:
- `<script>` タグは除去される
- `onerror` ハンドラは除去される
- テキストのみが表示される

---

## 関連ドキュメント

- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [DOMPurify](https://github.com/cure53/DOMPurify)
- [Next.js Security Headers](https://nextjs.org/docs/app/building-your-application/configuring/content-security-policy)
