# Lecsy B2B 設計レビュー & 今後ロードマップ

最終更新: 2026-04-07
対象範囲: 直近コミット (`2ce62f4` / `bb9d006` / `10b7d0f` / `5cd88fa`) で投入された B2B 機能一式
関連: `doc/CURRENT_STATUS.md` (短縮版) / `doc/00_統合要件定義_v4_B2B.md` (要件マスタ)

---

## 0. このドキュメントの位置付け

`CURRENT_STATUS.md` は「今動いているか / 動いていないか」のスナップショット。
このドキュメントはそこから一歩踏み込んで:

- **直近導入された B2B 機能の設計上の判断とその根拠**
- **設計の甘さ・将来壊れる可能性が高い箇所**
- **次に作るべき機能の優先順位と、それぞれの実装ヒント**

を残す。営業 / 採用 / 自分が 1 ヶ月後にコードを見直すときの "なぜこうなってる?" を解決するのが目的。

---

## 1. 直近導入された B2B 機能 (現状)

### 1.1 iOS 認証ユーザー向け要約 (commit `2ce62f4`)

| 項目 | 状態 |
|---|---|
| ファイル | `lecsy/Services/SummaryService.swift` (新規) / `LectureDetailView.swift` |
| Edge Function | `supabase/functions/summarize/index.ts` |
| 認可 | **Pro ゲート撤廃**。認証済みなら誰でも要約可能 |
| レートリミット | `usage_logs` テーブルで日 20 / 月 400 (ユーザー単位) |
| 言語 | ja / en / es / zh / ko / fr / de (`output_language` で指定) |
| モデル | `gpt-4o-mini` / `response_format: json_object` |

**設計判断**: B2B 学校ユーザーに「学校が払ってるのに要約使えない」体験をさせない。Pro チェックを取り払い、レートリミットだけで濫用を防ぐ方針。これは `summarize/index.ts:55-58` のコメントに明文化済。

**甘さ**:

1. **レートリミットがユーザー単位、組織単位ではない** — 1 校 100 人いたら理論上 月 40,000 要約。コストは Lecsy が全部かぶる。`org_ai_usage_logs` テーブルがあるのに enforce していない。
2. **`usage_logs.user_id` で一意 — 退会したユーザーの履歴で枠が消費されたままになる**。`created_at` で時間窓を見ているので実害は薄いが整理は要。
3. **`gpt-4o-mini` 固定** — Pro org にはもっと良いモデル (4o / Claude Sonnet) を選べるようにするのが将来課題。`models` カラムを `organizations` に持たせるか、`organization_settings` テーブルを切るか要設計。
4. **iOS 側は `SummaryService` 単独で `transcript_id` を投げているだけ** — `organization_id` を投げていないので、サーバー側で「誰の組織のコストか」を後追いできない。

### 1.2 Web 管理画面 — Super Admin 管理 UI (commit `2ce62f4`)

| 項目 | 内容 |
|---|---|
| 画面 | `/admin/super-admins` (List + Add + Remove) |
| API | `web/app/api/admin/super-admins/route.ts` (GET / POST / DELETE) |
| データ | `super_admin_emails` テーブル (M22) |
| 認可 | `isSuperAdmin(user)` (`web/utils/isSuperAdmin.ts`) |

**設計判断**: 以前は Edge Function 内でハードコード or env 変数だった super admin リストを DB 化。Web から動的に追加できるようになり、新しい運用メンバーが入ったら即足せる。

**甘さ**:

1. **Bootstrap 問題** — 初回 super admin は SQL で直接 INSERT する必要がある。マイグレーション (`20260406130000_super_admin_emails.sql`) で `nittonotakumi@gmail.com` を seed しているのでオーナー本人は OK だが、他人に譲渡するときは手順書化が必要。
2. **DELETE で「最後の super admin を消す」を防ぐガードがない** — 自分自身を消したら復旧手段が SQL のみになる。`route.ts` に `count = 1 のとき DELETE 拒否` を入れるべき。
3. **監査ログ未記録** — super admin の追加/削除は最高権限の変更なのに `audit_logs` に残らない。

### 1.3 組織メンバー = 自動 Pro 扱い (commit `10b7d0f`)

| 項目 | 内容 |
|---|---|
| 中心ロジック | `web/utils/isPro.ts` の `getProStatus()` |
| 判定順 | (1) WHITELIST_EMAILS → (2) 個人 Stripe sub → (3) 組織 plan='pro' |
| 戻り値 | `{ isPro, source, orgName? }` — UI で「○○大学経由で Pro」と出せる |

**設計判断**: 学校が払っているのに UI で「Upgrade」を出すと現場が混乱する。`getProStatus()` を 1 箇所に集約し、全 Pro ゲートをここに通す。

**甘さ**:

1. **N+1 の匂い** — `organization_members` を引いた後に `organizations(name, plan)` を join しているが、ユーザーが複数 org 所属のとき (副担任など) 各メンバーシップを線形ループ。組織数が増えると 50ms くらい遅くなる。実害は当面無い。
2. **キャッシュ無し** — Server Component で毎リクエスト Supabase に 3 クエリ。Next.js の `unstable_cache` か React `cache()` で 60s キャッシュかけたい。ただし plan 変更が即反映しないと営業で困るので慎重に。
3. **`PAID_PLANS = ['pro']` ハードコード** — 将来 `enterprise` 等を入れたら配列に足す必要。`20260407100000_b2b_simplify.sql` で 2 値に縮めたばかりなので当面 OK。
4. **iOS 側に同等のロジックが無い** — iOS は `OrganizationService` で組織所属を見ているが、「Pro かどうか」の単一関数が無い。Web と判定基準がズレるリスクあり。**対応必須**: `lecsy/Services/ProStatusResolver.swift` を切って Web の `getProStatus` と 1:1 対応にする。

### 1.4 B2B スキーマ整理 (commit `bb9d006` / migration `20260407100000_b2b_simplify.sql`)

dead テーブル 10 本を `DROP CASCADE`、`organizations.plan` を `free` / `pro` の 2 値に統一、`transcripts.class_id` 削除。

**設計判断**: v4 で「将来必要かも」で大量に作ったテーブル (sso_configs / scim_tokens / seat_snapshots / classes / billing_profiles…) が全部未配線で残っていた。営業で使わない機能を抱えたままだと RLS テストや監査で説明コストが膨らむので、**実装ゼロのものは一旦消した**。

**注意**: SSO/SCIM/教室機能を再導入するときは、過去のマイグレーション (`20260406000600_v4_m7_org_extensions.sql` 等) を **コピペで戻すのではなく**、当時のコメントを読み直してから設計し直す。`org_classes` などはスキーマの方向が変わる可能性が高い (例: 「クラス」ではなく「コース」になるかもしれない)。

---

## 2. 設計上の "穴" 一覧 (優先度順)

### 🔴 High — 営業前に塞ぐべき

| # | 問題 | 影響 | 修正案 |
|---|---|---|---|
| H1 | iOS 録音保存に `organization_id` / `visibility` が入らない | 学校契約なのに個人領域に保存され、組織管理画面に出てこない | `LectureRecordingService` の保存パスに `OrganizationContext` を注入 |
| H2 | iOS の Pro 判定が Web とズレている | 学校員なのに iOS で「Upgrade」が出る恐れ | `ProStatusResolver.swift` 新規 + `getProStatus` と同じ 3 段判定 |
| H3 | 要約コストが組織単位で上限なし | 1 校で月数万円のコスト爆発 | `summarize/index.ts` で `organization_id` を必須化 → `org_ai_usage_logs` で月次上限 enforce |
| H4 | super admin DELETE に「最後の 1 人保護」なし | 自分自身を誤削除で復旧 SQL 必要 | `route.ts` に count 検証 |
| H5 | Stripe webhook の B2B 分岐は実装したが **テストされていない** | 学校が払ったのに plan='pro' 反映されない事故リスク | Stripe CLI で `checkout.session.completed` を flood テスト |

### 🟡 Medium — 契約 1〜3 校までに塞ぐ

| # | 問題 | 影響 | 修正案 |
|---|---|---|---|
| M1 | `audit_logs` に super admin 操作 / plan 変更が記録されない | エンタープライズ商談で「監査」を聞かれて答えられない | `audit_trigger_cascade_safe.sql` の対象テーブルに `super_admin_emails` / `organizations.plan` 変更を追加 |
| M2 | `/org/**` の Web ガードが各ページ実装に依存 | 1 ページ書き忘れたら漏洩 | `web/middleware.ts` に集約 (※ Next.js 16 では `proxy.ts` が推奨) |
| M3 | `isPro` キャッシュ無しで Server Component 毎回 3 クエリ | レスポンス遅延 | React `cache()` でリクエストスコープのメモ化 |
| M4 | CSV インポートのメール検証が弱い (`=cmd|...` 等) | スプレッドシートインジェクション | `org-csv-import` で先頭 `=+-@` を sanitize |
| M5 | RLS テスト 0 件 | リファクタで認可崩壊しても気づけない | pgTAP で 10 ケース最低限 (member/admin/owner/non-member × R/W) |

### 🟢 Low — エンタープライズ商談が来てから

- SSO (SAML/OIDC) — Edge Function `sso-saml-acs` / `sso-saml-metadata`
- SCIM 2.0 — `scim-users` / `scim-groups` Edge Function
- 教室 (Class) モデル — 学生→クラス→講義の 3 階層
- データ削除リクエスト (GDPR) — `data_deletion_requests` 復活
- 席数スナップショット (cron) — 月次請求精算用
- ステータスページ / Vanta SOC2 / サイバー保険

---

## 3. アーキテクチャ上のまだ決まっていない論点

### 3.1 「学校が払う」と「個人が払う」の関係

現状: 個人 Pro と組織 Pro が **OR** で結合 (`getProStatus` のどちらかが true なら Pro)。

**未決**: 個人で Pro 契約してる人が学校に入ったら、個人 sub を自動キャンセルすべきか? しないと学校契約期間中も個人課金が走る (= ユーザー視点で詐欺感)。

**提案**: 組織加入時に Stripe で `cancel_at_period_end=true` をセットする helper を `/api/org/[slug]/join` 内に追加。退会時は何もしない (放置で次月解約)。

### 3.2 「組織を抜けた人の transcripts」の所有権

現状: `transcripts.user_id` は auth.users.id 直接参照。組織から抜けても本人は読めるが、組織管理者からは見えなくなる。

**未決**: 学校としては「卒業生のデータも一定期間保持して引き継ぎ可能にしたい」要望がありえる。RLS を `org_id IS NOT NULL → org admin も読める` に拡張するか?

### 3.3 要約コストの誰が払うか問題

現状: Lecsy が全額負担 (gpt-4o-mini 固定)。

**未決**: Pro 組織の月額に AI コスト相当が入っていないので、ヘビーユーザー校が来ると赤字。選択肢:

- (A) 月額に組み込み (5,000 円/席 → AI 含む)
- (B) 従量課金オプション (基本 + AI add-on)
- (C) BYOK (組織が OpenAI / Anthropic API キーを入れる) — エンタープライズ向け

**おすすめ**: 当面 (A) で行き、契約 5 校超えてコスト見えてきたら (C) を追加。

### 3.4 iOS と Web の認可ロジック二重化

`isPro` / `isSuperAdmin` / `isOrgMember` が iOS Swift と Web TypeScript で別実装。

**未決**: SSOT (Single Source of Truth) をどこに置くか?

- (案 1) Edge Function `auth/me` を作って iOS/Web 両方が叩く → ネットワーク 1 hop 増
- (案 2) RLS の SECURITY DEFINER 関数を SSOT にして両方が SQL で問い合わせる → 既に `is_org_member` 等あり、これを延長するのが筋
- (案 3) 諦めて両方手書きで保つ → 現状

**おすすめ**: (案 2)。`is_pro(user_id)` SQL 関数を作り、Web/iOS 両方から `rpc('is_pro', { user_id })` で呼ぶ。

---

## 4. 直近 2 週間のアクションプラン (提案)

### Week 1 — "営業して落ちない" を作る

- [ ] H1: iOS 録音保存に org context 注入 (`LectureRecordingService` + `RecorderViewModel`)
- [ ] H2: `ProStatusResolver.swift` 新規 + 既存の Pro ゲート全部置き換え
- [ ] H4: super admin "last one" ガード (1 行)
- [ ] M2: `web/middleware.ts` (or `proxy.ts`) に `/org/**` 一括ガード

### Week 2 — "請求事故を止める"

- [ ] H3: `summarize/index.ts` を `organization_id` 必須化 → `org_ai_usage_logs` で月次上限
- [ ] H5: Stripe webhook B2B フローを CLI で flood テスト (10 イベント)
- [ ] M1: `audit_logs` 拡張 (super admin / plan 変更)
- [ ] M5: pgTAP テスト 10 ケース (RLS スモーク)

### Buffer

- [ ] 3.1 (個人 sub の自動キャンセル) を `/api/org/[slug]/join` に組み込む
- [ ] 3.4 案 2 の `is_pro()` SQL 関数を試作

---

## 5. "壊れる前兆" として監視すべき指標

ダッシュボード化はまだだが、運用で以下を週次目視:

| 指標 | 取得元 | 警戒値 |
|---|---|---|
| `usage_logs` の日次件数 | Supabase SQL | 1 ユーザーが 1 日 18 件超え (= レート上限近い) |
| `org_ai_usage_logs` の月次合計コスト | Supabase SQL | 1 組織で月 50 USD 超え |
| `audit_logs` の `action='member.role_changed'` | Supabase SQL | 1 日 5 件超え (= 誰かが権限弄りまくり = インシデント可能性) |
| Stripe `invoice.payment_failed` | Stripe Dashboard | 1 件でも出たら即対応 |
| Edge Function 5xx 率 | Supabase Functions Logs | 1% 超え |

---

## 6. 振り返り — なぜここまで膨らんだか / なぜ削れたか

直前まで M1〜M21 まで 21 個のマイグレーションを積み、SSO / SCIM / class / billing_profile と全部入りで設計していた。
ところが営業 1 校もまだ獲れていない段階でこのスキーマを抱えても、

- RLS テストの分母が膨らむだけ
- 営業資料で「これも対応してます」と言っても "実装されてないけど?" と即バレる
- 自分が 1 ヶ月後にコード読んでも何が生きてるか分からなくなる

ので、**実装ゼロのテーブルは一旦削った** (`20260407100000_b2b_simplify.sql`)。残ったのは:

```
organizations / organization_members / org_glossaries
org_ai_usage_logs / audit_logs / super_admin_emails
```

の 6 テーブルだけ。これが「最低限営業できる B2B」のミニマム集合。
**教訓**: 要件定義で先回りして作るより、契約 1 件取ってから足すほうが結果的に速い。

---

## 7. リファレンス

- 要件マスタ: `doc/00_統合要件定義_v4_B2B.md`
- 現状サマリ: `doc/CURRENT_STATUS.md`
- Stripe セットアップ: `B2B/11_STRIPE_SETUP.md`
- 営業ガイド: `B2B/09_SALES_GUIDE.md`
- 削除済みテーブル一覧: `supabase/migrations/20260407100000_b2b_simplify.sql` 冒頭コメント
