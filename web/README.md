# lecsy Web

lecsy の Web アプリケーション（Next.js）

## 開発環境セットアップ

```bash
# 依存関係のインストール
npm install

# 開発サーバー起動
npm run dev
```

ブラウザで [http://localhost:3020](http://localhost:3020) を開く

## ビルド

```bash
npm run build
npm start
```

## デプロイ

Vercel にデプロイする場合：

```bash
# Vercel CLI でデプロイ
vercel
```

または、GitHub リポジトリを Vercel に接続して自動デプロイ

## ルーティング

- `/` - LP（ランディングページ）
- `/login` - ログインページ

## 技術スタック

- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- React 18
