# Lecsy SEO 実装計画書（完全版）

> **注意：このドキュメントは実装指示書です。まだコードの変更は行いません。**
> 作成日: 2026-02-09

---

## 📊 現状分析

### 現在のサイト構成

| ページ | パス | 役割 |
|--------|------|------|
| ランディングページ | `/` | ブランド＋CV（売る用） |
| ログイン | `/login` | 認証 |
| プライバシーポリシー | `/privacy` | 法的ページ |
| 利用規約 | `/terms` | 法的ページ |
| ダッシュボード | `/app` | ログイン後（保護） |
| トランスクリプト詳細 | `/app/t/[id]` | ログイン後（保護） |

### App Store情報

- **App Store URL（日本ストア）:** https://apps.apple.com/jp/app/lecsy/id6758414856?l=en-US
- **App Store URL（USストア・推奨）:** https://apps.apple.com/us/app/lecsy/id6758414856
- **App ID:** `id6758414856`
- **カテゴリ:** Education
- **開発者:** Takumi Nittono
- **対応:** iOS 17.6+, iPadOS 17.6+, macOS 14.6+ (Apple Silicon)
- **価格:** 無料（Pro: $2.99/月）

> **注意:** LP・SEOページでは**USストアURL**（`/us/`）を使用すること。メインターゲットがUS在住の大学生・留学生のため。

### 現在のSEO状態（問題点）

| 項目 | 状態 | 問題 |
|------|------|------|
| メタデータ | `layout.tsx` にルートのみ | 各ページ個別のメタデータなし |
| sitemap.xml | **なし** | Googleがページを発見できない |
| robots.txt | **なし** | クロール制御がない |
| Open Graph | **なし** | SNSシェア時にプレビューが出ない |
| Twitter Card | **なし** | Xでのシェア効果ゼロ |
| JSON-LD構造化データ | **なし** | リッチスニペット非対応 |
| SEO専用ページ | **0本** | 非ブランド検索の流入経路がない |
| canonical URL | ルートのみ | 各ページにcanonicalがない |
| 内部リンク設計 | フッターのみ（privacy/terms） | SEOジュースが流れない |
| H1タグ最適化 | 部分的 | KW最適化されていない |
| FAQ構造化データ | **なし** | FAQ がリッチスニペットに出ない |
| App Storeリンク | **なし** | LPにDL導線がない。CTAが全て`/login`に向いている |

---

## 🏗️ 実装が必要な変更一覧

---

### Phase 1: テクニカルSEO基盤（最優先）

#### 1-1. `app/sitemap.ts` を新規作成

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://www.lecsy.app'
  
  return [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1,
    },
    {
      url: `${baseUrl}/ai-transcription-for-students`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.9,
    },
    {
      url: `${baseUrl}/lecture-recording-app-college`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.9,
    },
    {
      url: `${baseUrl}/ai-note-taking-for-international-students`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.9,
    },
    {
      url: `${baseUrl}/otter-alternative-for-lectures`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    {
      url: `${baseUrl}/how-to-record-lectures-legally`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.7,
    },
    {
      url: `${baseUrl}/privacy`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.3,
    },
    {
      url: `${baseUrl}/terms`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.3,
    },
  ]
}
```

#### 1-2. `app/robots.ts` を新規作成

```typescript
// app/robots.ts
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/app/', '/api/', '/login', '/auth/'],
      },
    ],
    sitemap: 'https://www.lecsy.app/sitemap.xml',
  }
}
```

#### 1-3. `app/layout.tsx` メタデータの大幅強化

**現状：**
```typescript
export const metadata: Metadata = {
  title: "Lecsy | Lecture Recording & AI Transcription App for Students",
  description: "Lecsy is a lecture recording and AI transcription app designed for college and international students to better understand lectures.",
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
  icons: { ... },
};
```

**変更後：**
```typescript
export const metadata: Metadata = {
  metadataBase: new URL('https://www.lecsy.app'),
  title: {
    default: "Lecsy | Lecture Recording & AI Transcription App for Students",
    template: "%s | Lecsy",
  },
  description: "Record college lectures on your iPhone, transcribe with AI offline, and review anytime. Built for international and college students who want to truly understand every lecture.",
  keywords: [
    "lecture recording app",
    "ai transcription for students",
    "college lecture recorder",
    "international students lecture app",
    "ai note taking",
    "lecture transcription",
    "offline transcription app",
  ],
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://www.lecsy.app/',
    siteName: 'Lecsy',
    title: 'Lecsy – Lecture Recording & AI Transcription for Students',
    description: 'Record college lectures, transcribe with AI, and review anytime. Free for students.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Lecsy - Lecture Recording & AI Transcription App',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Lecsy – Lecture Recording & AI Transcription for Students',
    description: 'Record college lectures, transcribe with AI, and review anytime. Free for students.',
    images: ['/og-image.png'],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: [{ url: "/icon.png", type: "image/png" }],
    apple: [{ url: "/apple-icon.png", type: "image/png" }],
  },
};
```

#### 1-4. OGP画像の作成

- **ファイル:** `app/opengraph-image.png` または `app/opengraph-image.tsx`（動的生成）
- **サイズ:** 1200x630px
- **内容:** Lecsyロゴ + "Lecture Recording & AI Transcription for Students" + ブランドカラー

---

### Phase 2: トップページ（LP）のSEO改善

#### 2-1. `app/page.tsx` の変更点

**変更箇所一覧：**

| # | 変更箇所 | 現状 | 変更後 | 理由 |
|---|----------|------|--------|------|
| A | ページ個別メタデータ | なし | `export const metadata` 追加 | ページ固有のSEO最適化 |
| B | H1タグ | `Lecture Recording & AI Transcription App for Students` | 維持（十分良い） | メインKWが入っている |
| C | FAQ に構造化データ | なし | JSON-LD追加 | リッチスニペット獲得 |
| D | フッター内部リンク | privacy/termsのみ | SEOページへのリンク追加 | 内部リンク強化 |
| E | ヘッダーナビ | Login/Get Startedのみ | SEOページへのリンク追加（任意） | クロール導線 |
| F | App Storeリンク＋バッジ | **なし**（全CTAが`/login`） | App Storeバッジ追加 | DL導線＋信頼性＋CVR改善 |
| G | Hero CTAボタン | `Get the app — it's free` → `/login` | App Storeボタン併設 | 直接DL導線 |
| H | Final CTAセクション | `Download Lecsy — Free` → `/login` | App Storeボタン併設 | 直接DL導線 |

##### 2-1-F/G/H. App Store リンク埋め込み（3箇所）

**App Store URL:**
```
https://apps.apple.com/us/app/lecsy/id6758414856
```

**変更箇所 1: Hero セクション（L63-79付近）**

現状：
```tsx
<div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
  <Link href="/login" className="...">
    Get the app — it's free
  </Link>
  <Link href="#how-it-works" className="...">
    Learn more →
  </Link>
</div>
```

変更後：
```tsx
<div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
  <Link href="/login" className="...">
    Get Started Free
  </Link>
  <a
    href="https://apps.apple.com/us/app/lecsy/id6758414856"
    target="_blank"
    rel="noopener noreferrer"
    className="inline-flex items-center gap-3 px-6 py-3 bg-black text-white rounded-xl hover:bg-gray-800 transition-all shadow-lg"
  >
    <svg className="w-8 h-8" viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 22 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.09997 22C7.78997 22.05 6.79997 20.68 5.95997 19.47C4.24997 17 2.93997 12.45 4.69997 9.39C5.56997 7.87 7.12997 6.91 8.81997 6.88C10.1 6.86 11.32 7.75 12.11 7.75C12.89 7.75 14.37 6.68 15.92 6.84C16.57 6.87 18.39 7.1 19.56 8.82C19.47 8.88 17.39 10.1 17.41 12.63C17.44 15.65 20.06 16.66 20.09 16.67C20.06 16.74 19.67 18.11 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z"/>
    </svg>
    <div className="text-left">
      <div className="text-[10px] leading-tight">Download on the</div>
      <div className="text-lg font-semibold leading-tight">App Store</div>
    </div>
  </a>
</div>
```

**変更箇所 2: Final CTAセクション（L500-525付近）**

現状：
```tsx
<Link href="/login" className="...">
  Download Lecsy — Free
</Link>
```

変更後：
```tsx
<div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
  <Link href="/login" className="...">
    Get Started on Web
  </Link>
  <a
    href="https://apps.apple.com/us/app/lecsy/id6758414856"
    target="_blank"
    rel="noopener noreferrer"
    className="inline-flex items-center gap-3 px-6 py-3 bg-white/10 border-2 border-white text-white rounded-xl hover:bg-white/20 transition-all"
  >
    {/* Apple logo SVG */}
    <div className="text-left">
      <div className="text-[10px] leading-tight">Download on the</div>
      <div className="text-lg font-semibold leading-tight">App Store</div>
    </div>
  </a>
</div>
```

**変更箇所 3: Pricing セクションのFreeプランCTA（L416-421付近）**

現状：
```tsx
<Link href="/login" className="...">Get Started Free</Link>
```

変更後（App Storeリンクを小さく追加）：
```tsx
<Link href="/login" className="...">Get Started Free</Link>
<a
  href="https://apps.apple.com/us/app/lecsy/id6758414856"
  target="_blank"
  rel="noopener noreferrer"
  className="block w-full text-center mt-3 text-sm text-gray-500 hover:text-gray-700 underline"
>
  or download from App Store →
</a>
```

**SEOページ共通CTA（全5ページ）にもApp Storeリンクを設置：**
```tsx
// components/CTASection.tsx に App Store ボタンを含める
const APP_STORE_URL = "https://apps.apple.com/us/app/lecsy/id6758414856"
```

##### 2-1-A. ページ個別メタデータの追加

```typescript
// app/page.tsx の先頭に追加
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: "Lecsy | Lecture Recording & AI Transcription App for Students",
  description: "Record college lectures on your iPhone, transcribe with AI completely offline, and review anytime. The best lecture recording app for college and international students. Free to start.",
  alternates: {
    canonical: "https://www.lecsy.app/",
  },
}
```

##### 2-1-C. FAQ JSON-LD 構造化データの追加

```typescript
// app/page.tsx の return 直下、<main> の中に追加
<script
  type="application/ld+json"
  dangerouslySetInnerHTML={{
    __html: JSON.stringify({
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": [
        {
          "@type": "Question",
          "name": "Is my data safe?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "Yes. Audio never leaves your device. Only text is saved to the cloud — and only when you choose to."
          }
        },
        {
          "@type": "Question",
          "name": "Do I need internet to record?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "No. Recording and transcription work completely offline."
          }
        },
        {
          "@type": "Question",
          "name": "What languages are supported?",
          "acceptedAnswer": {
            "@type": "Answer",
            "text": "Japanese and English. Auto-detection is available."
          }
        },
        // ... 他のFAQも追加
      ]
    })
  }}
/>
```

##### 2-1-C (追加). SoftwareApplication 構造化データ（App Storeリンク含む）

```typescript
<script
  type="application/ld+json"
  dangerouslySetInnerHTML={{
    __html: JSON.stringify({
      "@context": "https://schema.org",
      "@type": "SoftwareApplication",
      "name": "Lecsy",
      "operatingSystem": "iOS 17.6+",
      "applicationCategory": "EducationApplication",
      "offers": {
        "@type": "Offer",
        "price": "0",
        "priceCurrency": "USD"
      },
      "description": "Lecture recording and AI transcription app for college and international students",
      "url": "https://www.lecsy.app/",
      "downloadUrl": "https://apps.apple.com/us/app/lecsy/id6758414856",
      "installUrl": "https://apps.apple.com/us/app/lecsy/id6758414856",
      "author": {
        "@type": "Person",
        "name": "Takumi Nittono"
      },
      "aggregateRating": {
        "@type": "AggregateRating",
        "ratingValue": "4.8",
        "ratingCount": "XX" // レビュー数が溜まったら実際の数値に置き換え
      }
    })
  }}
/>
```

##### 2-1-D. フッターの内部リンク強化

**現状のフッター（2リンクのみ）：**
```tsx
<div className="flex gap-6">
  <Link href="/privacy">Privacy Policy</Link>
  <Link href="/terms">Terms of Service</Link>
</div>
```

**変更後のフッター（SEOページリンク追加）：**
```tsx
<footer className="border-t border-gray-200 py-12 bg-white">
  <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div className="grid md:grid-cols-4 gap-8 mb-8">
      {/* ブランド */}
      <div>
        <div className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent mb-4">
          lecsy
        </div>
        <p className="text-gray-600 text-sm">
          Lecture recording & AI transcription app built for college and international students.
        </p>
      </div>
      {/* 機能ページ */}
      <div>
        <h4 className="font-semibold text-gray-900 mb-4">Features</h4>
        <ul className="space-y-2 text-sm text-gray-600">
          <li><Link href="/ai-transcription-for-students">AI Transcription for Students</Link></li>
          <li><Link href="/lecture-recording-app-college">Lecture Recording App</Link></li>
          <li><Link href="/ai-note-taking-for-international-students">AI Note Taking for International Students</Link></li>
        </ul>
      </div>
      {/* リソース */}
      <div>
        <h4 className="font-semibold text-gray-900 mb-4">Resources</h4>
        <ul className="space-y-2 text-sm text-gray-600">
          <li><Link href="/otter-alternative-for-lectures">Otter Alternative for Lectures</Link></li>
          <li><Link href="/how-to-record-lectures-legally">How to Record Lectures Legally</Link></li>
        </ul>
      </div>
      {/* 法的ページ */}
      <div>
        <h4 className="font-semibold text-gray-900 mb-4">Legal</h4>
        <ul className="space-y-2 text-sm text-gray-600">
          <li><Link href="/privacy">Privacy Policy</Link></li>
          <li><Link href="/terms">Terms of Service</Link></li>
        </ul>
      </div>
    </div>
    <div className="border-t border-gray-200 pt-8 text-center text-gray-600 text-sm">
      © 2026 lecsy. All rights reserved.
    </div>
  </div>
</footer>
```

---

### Phase 3: SEO専用ページ（5本）の新規作成

#### 共通構成テンプレート

全SEOページは以下の構成に従う：

```
app/
  [slug]/
    page.tsx        ← ページ本体
```

**共通レイアウト要素：**
- 共通ヘッダー（LecsyロゴとLogin/Get Startedボタン）
- 共通フッター（上記の拡張版）
- パンくずリスト（構造化データ付き）
- ページ末尾に CTA セクション
- 各ページ間の相互内部リンク

**共通コンポーネントとして抽出推奨：**
- `components/SEOHeader.tsx` — SEOページ共通ヘッダー
- `components/SEOFooter.tsx` — 拡張フッター
- `components/CTASection.tsx` — 共通CTA
- `components/ComparisonTable.tsx` — 比較表コンポーネント
- `components/FAQSection.tsx` — FAQ（JSON-LD付き）

---

#### ① `/ai-transcription-for-students`

**ファイル:** `app/ai-transcription-for-students/page.tsx`

**メタデータ：**
```typescript
export const metadata: Metadata = {
  title: "AI Transcription for Students – Understand College Lectures Better",
  description: "Struggling to keep up with fast-paced college lectures? Lecsy's AI transcription app records and transcribes lectures offline on your iPhone. Built for college and international students.",
  alternates: {
    canonical: "https://www.lecsy.app/ai-transcription-for-students",
  },
  openGraph: {
    title: "AI Transcription for Students – Understand College Lectures Better | Lecsy",
    description: "Record and transcribe college lectures with AI. Offline, private, and built for students.",
    url: "https://www.lecsy.app/ai-transcription-for-students",
  },
}
```

**見出し構成：**
```
H1: AI Transcription App for College Students

H2: Why College Students Struggle With Lectures
  - 90分講義の情報量
  - 早口の教授
  - 英語が母語じゃない留学生の課題（ESL angle）
  - 手書きノートの限界

H2: How AI Transcription Solves This
  - 録音 → 文字起こし → 復習フロー
  - オフラインで動く
  - 授業中はリラックスして聴ける

H2: Why Lecsy Is Built for College Students
  - iPhoneだけで完結
  - 100%ローカル（プライバシー）
  - 大学講義に特化した設計
  - 無料で始められる

H2: Lecsy vs Other AI Transcription Apps
  - 比較表（Otter / Notta / Lecsy）
  - インターネット不要 = Lecsyの強み
  - 価格比較

H2: How to Use Lecsy in Real Classes
  - Step 1: アプリを開く
  - Step 2: 録音ボタン
  - Step 3: ウェブで復習
  - 具体例（history lecture / fast professor）

H2: FAQs
  - Is AI transcription accurate?
  - Does it work without internet?
  - Can I use it for study groups?
  - What about professors who speak fast?
```

**必須コンテンツ要素：**
- 実体験風テキスト: "Many international students face the challenge of..."
- 具体的な授業シーン: "In a 300-person history lecture hall..."
- 比較: Otter / Zoom transcription との違い
- CTA: "Try Lecsy Free" ボタン → `/login`

**内部リンク：**
- → `/lecture-recording-app-college`（録音機能の詳細）
- → `/ai-note-taking-for-international-students`（留学生向け）
- → `/otter-alternative-for-lectures`（比較ページ）
- → `/`（トップページ CTA）

---

#### ② `/lecture-recording-app-college`

**ファイル:** `app/lecture-recording-app-college/page.tsx`

**メタデータ：**
```typescript
export const metadata: Metadata = {
  title: "Best Lecture Recording App for College – Record & Transcribe on iPhone",
  description: "Record college lectures on your iPhone with Lecsy. Works offline, transcribes with AI, and lets you review anytime. The best lecture recording app for students.",
  alternates: {
    canonical: "https://www.lecsy.app/lecture-recording-app-college",
  },
  openGraph: {
    title: "Best Lecture Recording App for College | Lecsy",
    description: "Record and transcribe college lectures on iPhone. Offline. Free.",
    url: "https://www.lecsy.app/lecture-recording-app-college",
  },
}
```

**見出し構成：**
```
H1: Lecture Recording App for College Students

H2: Why Students Need a Dedicated Lecture Recording App
  - スマホの標準ボイスメモの限界
  - 録音だけじゃ復習できない
  - 授業タイプ別の課題（lecture / seminar / lab）

H2: How Lecsy Records and Transcribes Your Lectures
  - iPhoneでの使い方（具体的な手順）
  - バックグラウンド録音
  - ロック画面でも動作
  - オフラインで文字起こし

H2: Recording Different Types of Classes
  - 大教室のレクチャー
  - 少人数セミナー
  - ラボ・実習
  - それぞれでの録音Tipsを記載

H2: From Recording to Review: The Complete Workflow
  - 録音 → 文字起こし → ウェブで閲覧 → AI要約 → 試験対策
  - スクリーンショットやフロー図のイメージ

H2: Lecsy vs Voice Memos vs Zoom Recording
  - 比較表
  - 文字起こし機能の有無
  - オフライン対応
  - プライバシー

H2: FAQs
  - How long can I record?
  - Does it drain my battery?
  - Can I record in airplane mode?
  - Is it legal to record lectures?（→ /how-to-record-lectures-legally リンク）
```

**内部リンク：**
- → `/ai-transcription-for-students`（文字起こし詳細）
- → `/how-to-record-lectures-legally`（合法性）
- → `/ai-note-taking-for-international-students`（留学生向け）
- → `/`（トップページ CTA）

---

#### ③ `/ai-note-taking-for-international-students` 🔥超重要

**ファイル:** `app/ai-note-taking-for-international-students/page.tsx`

**メタデータ：**
```typescript
export const metadata: Metadata = {
  title: "AI Note Taking for International Students – Never Miss a Lecture Again",
  description: "International and ESL students: stop struggling with fast-paced English lectures. Lecsy records, transcribes, and summarizes your lectures with AI. Read at your own pace.",
  alternates: {
    canonical: "https://www.lecsy.app/ai-note-taking-for-international-students",
  },
  openGraph: {
    title: "AI Note Taking for International Students | Lecsy",
    description: "For ESL students who struggle with fast-paced English lectures. Record, transcribe, review.",
    url: "https://www.lecsy.app/ai-note-taking-for-international-students",
  },
}
```

**見出し構成：**
```
H1: AI Note Taking App for International Students

H2: Why International Students Struggle With English Lectures
  - リスニングスピードのギャップ
  - アクセント・スラング
  - ノートを取りながら聞くのは二重負荷
  - 「I struggled with understanding fast professors」的な体験談
  - ESL students face unique challenges...

H2: How AI Note Taking Transforms the Lecture Experience
  - 全部録音 → 後から自分のペースで読む
  - 知らない単語を調べながら復習できる
  - AI要約で要点把握
  - 母語で理解 → 英語で再確認

H2: Why Lecsy Is the Best Choice for International Students
  - オフライン対応（海外SIMの問題なし）
  - プライバシー（データが国外に出ない）
  - シンプルUI（言語バリアなし）
  - 無料で使える

H2: Lecsy vs Otter for International Students
  - Otter: ネット必須、プライバシー懸念、高い
  - Lecsy: オフライン、ローカル処理、無料
  - 留学生の視点で比較

H2: Real Student Stories (体験風コンテンツ)
  - "As a Japanese student studying in the US..."
  - "I used to miss half of what my professor said in History 101..."
  - 具体的な授業名・シーンを入れる

H2: How to Get Started
  - Step-by-step ガイド

H2: FAQs
  - Does it understand accented English?
  - Can I review lectures in my native language?
  - Is it free for students?
  - How is this different from Otter.ai?
```

**内部リンク：**
- → `/ai-transcription-for-students`
- → `/otter-alternative-for-lectures`（Otter比較）
- → `/lecture-recording-app-college`
- → `/`（トップページ CTA）

---

#### ④ `/otter-alternative-for-lectures` 🔥比較ページ

**ファイル:** `app/otter-alternative-for-lectures/page.tsx`

**メタデータ：**
```typescript
export const metadata: Metadata = {
  title: "Best Otter.ai Alternative for Lectures – Lecsy vs Otter vs Notta (2026)",
  description: "Looking for an Otter.ai alternative for college lectures? Compare Lecsy, Otter, and Notta side-by-side. Offline transcription, privacy-first, built for students.",
  alternates: {
    canonical: "https://www.lecsy.app/otter-alternative-for-lectures",
  },
  openGraph: {
    title: "Best Otter.ai Alternative for Lectures (2026) | Lecsy",
    description: "Lecsy vs Otter vs Notta: Which lecture transcription app is best for students?",
    url: "https://www.lecsy.app/otter-alternative-for-lectures",
  },
}
```

**見出し構成：**
```
H1: Best Otter.ai Alternative for College Lectures (2026)

H2: Why Students Are Looking for Otter Alternatives
  - Otter の制限（無料枠、インターネット必須）
  - プライバシーの懸念
  - 大学講義に最適化されていない
  - 価格が高い

H2: Lecsy vs Otter vs Notta – Detailed Comparison
  ★ 大きな比較表（最重要セクション）

  | Feature | Lecsy | Otter.ai | Notta |
  |---------|-------|----------|-------|
  | Price | Free (Pro $2.99/mo) | Free limited, $16.99/mo | Free limited, $13.99/mo |
  | Offline Recording | ✅ | ❌ | ❌ |
  | Offline Transcription | ✅ | ❌ | ❌ |
  | Privacy (Local Processing) | ✅ | ❌ (Cloud) | ❌ (Cloud) |
  | Built for Students | ✅ | General | General |
  | iPhone App | ✅ | ✅ | ✅ |
  | AI Summary | ✅ (Pro) | ✅ (Paid) | ✅ (Paid) |
  | Exam Prep Mode | ✅ (Pro) | ❌ | ❌ |
  | Languages | EN, JP | EN + others | EN + others |

H2: Why Lecsy Wins for College Lectures
  - オフライン = 講義室のWi-Fi問題解決
  - ローカル処理 = 学校のネットワークポリシーに準拠
  - 学生向け価格設計
  - 試験対策モード

H2: Why Lecsy Wins for International Students
  - 英語講義の文字起こし → 自分のペースで復習
  - 安いSIMでもOK（オフライン）
  - プライバシー重視

H2: How to Switch from Otter to Lecsy
  - 移行ステップ

H2: FAQs
  - Is Lecsy really free?
  - How does offline transcription work?
  - Can Lecsy replace Otter for meetings too?
  - What if I need multi-language support?
```

**内部リンク：**
- → `/ai-transcription-for-students`
- → `/ai-note-taking-for-international-students`
- → `/lecture-recording-app-college`
- → `/`（トップページ CTA）

---

#### ⑤ `/how-to-record-lectures-legally`

**ファイル:** `app/how-to-record-lectures-legally/page.tsx`

**メタデータ：**
```typescript
export const metadata: Metadata = {
  title: "How to Record Lectures Legally – Student Guide (2026)",
  description: "Is it legal to record college lectures? Learn the rules, get professor permission, and record lectures the right way. A complete guide for US college and international students.",
  alternates: {
    canonical: "https://www.lecsy.app/how-to-record-lectures-legally",
  },
  openGraph: {
    title: "How to Record Lectures Legally – Student Guide (2026) | Lecsy",
    description: "Everything students need to know about recording college lectures legally in the US.",
    url: "https://www.lecsy.app/how-to-record-lectures-legally",
  },
}
```

**見出し構成：**
```
H1: How to Record College Lectures Legally (2026 Guide)

H2: Is It Legal to Record Lectures in the US?
  - 連邦法 vs 州法の概要
  - 一般的には可能（one-party consent states）
  - 大学ごとのポリシーの違い

H2: University Recording Policies: What You Need to Know
  - 一般的な大学のルール
  - Syllabus に記載されることが多い
  - Academic integrity との関係

H2: How to Get Professor Permission
  - メールテンプレート
  - 直接聞く場合の言い方
  - Disability services を通す方法

H2: Special Considerations for International Students
  - 留学生の権利
  - アコモデーション申請
  - 文化的な違い（録音に対する考え方）

H2: Best Practices for Recording Lectures
  - 許可を得てから
  - 個人利用に限る
  - 共有しない
  - Lecsyならプライバシーが守られる（ローカル処理）

H2: How Lecsy Helps You Record Responsibly
  - 音声はデバイスに留まる
  - 共有機能は意図的に制限
  - 学習目的に特化

H2: FAQs
  - Can I share recorded lectures?
  - What if my professor says no?
  - Do I need to tell classmates?
  - Is it different in other countries?
```

**内部リンク：**
- → `/lecture-recording-app-college`
- → `/ai-transcription-for-students`
- → `/ai-note-taking-for-international-students`
- → `/`（トップページ CTA）

---

### Phase 4: 共通コンポーネント作成

#### 4-1. `components/SEOPageLayout.tsx`（新規）

SEOページ共通のレイアウトラッパー。ヘッダー、フッター、CTA、パンくずを含む。

#### 4-2. `components/ComparisonTable.tsx`（新規）

比較表の再利用可能コンポーネント。`/otter-alternative-for-lectures` と他ページで使用。

#### 4-3. `components/FAQSection.tsx`（新規）

FAQ セクション + JSON-LD 構造化データの自動生成。props で Q&A 配列を渡す。

```typescript
interface FAQ {
  question: string;
  answer: string;
}

interface FAQSectionProps {
  faqs: FAQ[];
}
```

#### 4-4. `components/BreadcrumbJsonLd.tsx`（新規）

パンくずリストの構造化データコンポーネント。

```typescript
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://www.lecsy.app/" },
    { "@type": "ListItem", "position": 2, "name": "AI Transcription for Students", "item": "https://www.lecsy.app/ai-transcription-for-students" }
  ]
}
</script>
```

#### 4-5. `components/CTASection.tsx`（新規）

全SEOページ末尾の CTA セクション。

```tsx
<section className="py-20 bg-gradient-to-br from-blue-600 to-blue-500 text-white">
  <div className="max-w-4xl mx-auto text-center">
    <h2>Ready to understand every lecture?</h2>
    <p>Start recording and transcribing for free.</p>
    <Link href="/login">Try Lecsy Free →</Link>
  </div>
</section>
```

---

### Phase 5: 内部リンク設計

#### 全ページ間のリンクマップ

```
                    ┌──────────────────┐
                    │    / (トップ)     │
                    │  ← 全SEOページから │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────┐  ┌────────────────┐  ┌──────────────────────┐
│ /ai-transcrip │  │ /lecture-recor │  │ /ai-note-taking-for  │
│ tion-for-     │◄─┤ ding-app-     │◄─┤ international-       │
│ students      │──►│ college       │──►│ students             │
└───────┬───────┘  └───────┬────────┘  └──────────┬───────────┘
        │                  │                       │
        │         ┌────────┘                       │
        ▼         ▼                                ▼
┌───────────────────────┐          ┌──────────────────────────┐
│ /otter-alternative-   │◄─────────│ /how-to-record-lectures- │
│ for-lectures          │──────────►│ legally                  │
└───────────────────────┘          └──────────────────────────┘
```

**リンクルール：**
- 全SEOページ → `/`（トップページ CTA）
- 全SEOページ → 他の全SEOページ（最低2本）
- `/otter-alternative-for-lectures` → 全機能ページ
- `/how-to-record-lectures-legally` → `/lecture-recording-app-college`
- トップページフッター → 全SEOページ

---

### Phase 6: `next.config.js` の改善

**現状：**
```javascript
const nextConfig = {
  reactStrictMode: true,
}
```

**変更後：**
```javascript
const nextConfig = {
  reactStrictMode: true,
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
        ],
      },
    ]
  },
}
```

---

## 📋 実装の優先順位まとめ

### Week 1（テクニカル基盤 + トップページ改善）
1. ✅ `app/robots.ts` 作成
2. ✅ `app/sitemap.ts` 作成
3. ✅ `app/layout.tsx` メタデータ強化（OG/Twitter/keywords）
4. ✅ OGP画像作成（`app/opengraph-image.png`）
5. ✅ `app/page.tsx` に JSON-LD構造化データ追加
6. ✅ フッター拡張（内部リンク追加）
7. ✅ `next.config.js` ヘッダー追加
8. ✅ 共通コンポーネント作成（SEOPageLayout, FAQSection, CTASection, ComparisonTable, BreadcrumbJsonLd）

### Week 2
9. ✅ `/ai-transcription-for-students` ページ作成

### Week 3
10. ✅ `/lecture-recording-app-college` ページ作成

### Week 4
11. ✅ `/ai-note-taking-for-international-students` ページ作成 🔥

### Week 5
12. ✅ `/otter-alternative-for-lectures` ページ作成 🔥

### Week 6
13. ✅ `/how-to-record-lectures-legally` ページ作成

---

## 📁 作成/変更ファイル一覧

### 新規作成ファイル（14ファイル）

| ファイル | 種類 |
|----------|------|
| `app/robots.ts` | テクニカルSEO |
| `app/sitemap.ts` | テクニカルSEO |
| `app/opengraph-image.png`（または `.tsx`） | OGP画像 |
| `app/ai-transcription-for-students/page.tsx` | SEOページ① |
| `app/lecture-recording-app-college/page.tsx` | SEOページ② |
| `app/ai-note-taking-for-international-students/page.tsx` | SEOページ③ |
| `app/otter-alternative-for-lectures/page.tsx` | SEOページ④ |
| `app/how-to-record-lectures-legally/page.tsx` | SEOページ⑤ |
| `components/SEOPageLayout.tsx` | 共通コンポーネント |
| `components/ComparisonTable.tsx` | 共通コンポーネント |
| `components/FAQSection.tsx` | 共通コンポーネント |
| `components/BreadcrumbJsonLd.tsx` | 共通コンポーネント |
| `components/CTASection.tsx` | 共通コンポーネント |
| `components/SEOFooter.tsx` | 共通コンポーネント |

### 変更ファイル（3ファイル）

| ファイル | 変更内容 |
|----------|----------|
| `app/layout.tsx` | メタデータ大幅強化（OG/Twitter/keywords/metadataBase） |
| `app/page.tsx` | JSON-LD追加、フッター拡張、ページメタデータ追加、**App Storeバッジ3箇所追加**（Hero/Final CTA/Pricing） |
| `next.config.js` | セキュリティヘッダー追加 |

### 定数ファイル（推奨新規）

| ファイル | 内容 |
|----------|------|
| `lib/constants.ts` | App Store URL等の共通定数を管理 |

```typescript
// lib/constants.ts
export const APP_STORE_URL = "https://apps.apple.com/us/app/lecsy/id6758414856"
export const SITE_URL = "https://www.lecsy.app"
export const APP_NAME = "Lecsy"
```

---

## 🎯 KPI目標（3ヶ月後）

| 指標 | 目標 |
|------|------|
| 「lecture recording app」系 | Top 10 |
| 「ai transcription for students」 | Otter.ai と同ページ |
| 「international students lecture」系 | 1位 |
| Google Search Console 表示回数 | 月10,000+回 |
| オーガニック流入 | 月500+クリック |

---

## 🚫 禁止事項（実装時の注意）

- ❌ キーワード詰め込み（不自然な繰り返し）
- ❌ 全ページ同じ文章のコピペ
- ❌ 抽象的な「AI is amazing」的な説明
- ❌ 学生視点がない記事（ビジネス向けトーンNG）
- ❌ 内部リンクのないページ
- ❌ canonical URLの欠落
- ❌ H1タグの複数使用
