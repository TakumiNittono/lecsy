# Lecsy 現状スナップショット

最終更新: 2026-04-06
マスタ要件: `doc/00_統合要件定義_v4_B2B.md`

## 構成

- **iOS** (`lecsy/`) — 録音/文字起こし/要約。Xcode 16 file-system synchronized groups。
- **Web** (`web/`) — Next.js。B2C LP + B2B 管理コンソール (`/org/[slug]`, `/admin`)。
- **Supabase** — Postgres + RLS + Edge Functions。
- **Legal** (`legal/`) — MSA/DPA/SLA/AUP/SOC2 Roadmap 等（要弁護士レビュー）。

## B2B 実装状況

### ✅ 完了
- **DB (M1–M7, M11, M14–19)**: 組織/メンバー/クラス/監査ログ/SSO設定/SCIMトークン/請求プロファイル/席数スナップショット。RLS は `is_org_member` / `is_org_role_at_least` SECURITY DEFINER ヘルパで再帰解消。座席上限 & 最後の owner 保護トリガー。
- **Edge Functions**: `org-create` / `org-grant-ownership` / `org-csv-import` / `org-checkout` / `_shared/auth.ts`。
- **Web**: `/admin` に grant-ownership、`/org/[slug]` 系管理画面（既存）。
- **iOS**: `SupabaseClient` / `OrganizationAPI` / `PostLoginCoordinator` / `SuperAdminView`。ビルド通過済み。
- **法務雛形**: MSA / DPA / SLA / AUP / SOC2 Roadmap / Subprocessors / Security Overview / RFP テンプレ。

### ⚠️ 未配線（動くが穴あり）
1. **席課金が DB 未配線** — `seats_purchased` カラムと Stripe Quantity 連動なし。M20 で追加予定。
2. **Stripe Webhook が B2B 未対応** — `metadata.org_id` 経由で `organizations.plan` を更新する処理がない。
3. **iOS ログイン直後に `PostLoginCoordinator.handleSignIn` 未呼び出し** — SupabaseClient に accessToken が入らず 401。
4. **iOS 録音保存時に `organization_id` / `visibility` / `class_id` 未セット** — 組織モードで録音しても private になる。
5. **AI コスト上限がプラン非連動** — `org_usage_monthly` はあるが enforce なし。
6. **テスト 0 件** — RLS/Edge Function の認可テストが未整備。
7. **CSV import のメール検証が弱い** — `=cmd|...` インジェクション対策なし。
8. **監査ログ粒度が粗い** — メンバー追加/削除/ロール変更が未記録。
9. **Web middleware で `/org/**` 一括ガード未実装**。
10. **メール通知未配線** — Resend 連携 (`org-send-notification`) が空。pending 追加が本人に届かない。
11. **iOS SuperAdminView が Settings に未配線**。

## 残タスク（優先順）

### Phase 1.5 — 営業して契約落ちしない状態に
1. M20: `seats_purchased` + Stripe Quantity 連動
2. `stripe-webhook` を B2B 対応（`metadata.org_id` → `organizations.plan` 更新）
3. iOS ログイン導線に `PostLoginCoordinator.handleSignIn` 注入
4. iOS 録音保存に org context を渡す
5. `/org/**` middleware ガード
6. RLS の pgTAP 認可テスト 10 ケース
7. CSV import sanitize 強化

### Phase 2 — エンタープライズ成約に必要
- M8 クラス学生マッピング
- Edge: `sso-saml-*` / `scim-users` / `org-seat-snapshot` (cron)
- iOS: 教室モード / iPad NavigationSplitView / Live Activity / Cross-Summary
- Web: `/org/[slug]/usage` グラフ + PDF / `/audit` / `/security` / `/sso`
- ステータスページ / Vanta SOC2 / サイバー保険

## 運用メモ

- **マイグレーション適用順**: M6 → M5 → M1 → M2 → M3 → M4 → M7 → M11 → M14-19（タイムスタンプで自然にこの順序）
- **Edge Functions デプロイ**: `supabase functions deploy org-create org-grant-ownership org-csv-import org-checkout`
- **Stripe 環境変数**: `STRIPE_PRICE_{STARTER,GROWTH,BUSINESS}_{MONTHLY,YEARLY}`
- **iOS Info.plist**: `SUPABASE_URL` / `SUPABASE_ANON_KEY` は xcconfig 経由で注入済
- **Super admin**: `nittonotakumi@gmail.com`（`/admin` と iOS SuperAdminView でのみ認識）

## 営業判断

- **パイロット 1 校（無償）**: 今の状態で回せる
- **有償契約**: Phase 1.5 の #1–#4 を直してから
- **エンタープライズ（SSO/SCIM 要求）**: Phase 2 完了後
