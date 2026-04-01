# 05. B2B機能 開発ロードマップ
**語学学校のニーズを優先**

---

## 現在の実装済み機能

- [x] オンデバイスAI文字起こし（WhisperKit）
- [x] 12言語対応
- [x] クラウド同期（Supabase）
- [x] OAuth認証（Apple, Google）
- [x] AI要約 & 試験対策（Pro, GPT-4）
- [x] Webダッシュボード
- [x] Stripe課金基盤
- [x] Live Activities

---

## Phase 1: 語学学校パイロット対応（6月1日〜7月15日）

### 1.1 組織アカウント基盤（2週間）
```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT CHECK (type IN ('language_school', 'university_iep', 'college', 'corporate')),
  plan TEXT CHECK (plan IN ('pilot', 'classroom', 'school', 'chain', 'corporate')),
  max_seats INTEGER DEFAULT 50,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  admin_user_id UUID REFERENCES auth.users(id)
);

CREATE TABLE organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id),
  user_id UUID REFERENCES auth.users(id),
  role TEXT CHECK (role IN ('admin', 'teacher', 'student')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(org_id, user_id)
);
```
- [ ] メール招待でメンバー追加
- [ ] RLSポリシー追加

### 1.2 先生ダッシュボード（2週間）
- [ ] `/teacher`ルート（Web）
  - クラスの生徒一覧
  - 生徒の利用状況（文字起こし回数、総時間）
  - クラスへの招待リンク生成
- [ ] 基本レポート（CSV出力）

### 1.3 語学学校向けランディングページ（3日）
- [ ] `lecsy.app/languages`
  - 12言語対応を前面に
  - 「言語ラボの代替」メッセージ
  - デモ動画埋め込み（英語↔スペイン語切替デモ）
  - パイロット申込フォーム
  - 価格表

### 1.4 営業資料（3日）
- [ ] 2分デモ動画撮影（Loom）
- [ ] 語学学校向け1ページャーPDF
- [ ] FERPA対応ドキュメント

---

## Phase 2: パイロット強化 & 有料変換（7月15日〜9月末）

### 2.1 利用分析ダッシュボード（2週間）
- [ ] 日/週/月別の文字起こし数
- [ ] 言語別利用統計（語学学校に特に重要）
- [ ] アクティブユーザー数・率
- [ ] グラフ/チャート表示

### 2.2 学校管理ダッシュボード（2週間）
- [ ] `/admin`ルート
  - メンバー管理
  - クラス/コース管理
  - 利用制限設定
  - バルク招待（CSV）
- [ ] 学校ロゴ表示

### 2.3 B2B課金（1.5週間）
- [ ] Stripe Invoice（請求書払い）
- [ ] 学期契約/年間契約
- [ ] ボリュームディスカウント

---

## Phase 3: 大学対応 & スケール（10月〜12月）

### 3.1 Canvas LTI 1.3連携（3-4週間）
- [ ] LTI認証フロー
- [ ] Deep Linking
- [ ] Roster Sync
- [ ] Canvas EdTech Collective申請

### 3.2 SSO/SAML（2週間）
- [ ] SAML 2.0対応
- [ ] 大学IdP連携
- [ ] 自動ユーザープロビジョニング

### 3.3 ADAコンプライアンスレポート（1週間）
- [ ] アクセシビリティカバレッジ率
- [ ] 人間ノートテイカーとのコスト比較レポート

### 3.4 iPad最適化（1.5週間）
- [ ] iPad専用レイアウト
- [ ] Split View対応

---

## Phase 4: エンタープライズ（2027年Q1〜）

- [ ] REST API提供
- [ ] Webhook
- [ ] D2L Brightspace / Moodle連携
- [ ] SOC 2準備
- [ ] Android版（検討）

---

## 優先順位マトリクス

```
        影響度 高
          │
 SSO/SAML │  組織アカウント
 Canvas   │  先生ダッシュボード
 iPad     │  LP（/languages）
          │  B2B課金
          │  利用分析
──────────┼──────────────
 SOC2     │  学校管理画面
 API      │  バルク招待
 Android  │  ロゴ表示
          │
        影響度 低
  工数大 ←───→ 工数小
```

**6-8月は右上（高影響×低工数）に集中。**
