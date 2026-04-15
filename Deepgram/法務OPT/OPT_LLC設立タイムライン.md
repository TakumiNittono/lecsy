# OPT / LLC 設立タイムライン

最終更新: 2026-04-14（B2B契約主体としてLLC必要性を強調）

## ステータス

- OPT開始日: **2026-06-01**
- EADカード: **発行済み（届き待ち）**
- 90日ルール: OPT開始日（6/1）から90日以内に雇用開始 → **8/29が期限**
- ISS報告: 未（カード届き次第連絡予定）
- LLC設立: **最優先。B2B契約のDPA/HECVAT/請求書すべてLLC名義必須**

---

## フェーズ1: 準備期間（〜6/1）

| ステップ | 内容 | 状態 | B2B営業との関係 |
|---------|------|------|---------------|
| 1 | EADカード受取 | 届き待ち | — |
| 2 | ISSに初回連絡（OPT準備中であることを報告） | 未 | — |
| 3 | ソーシャルセキュリティーナンバー（SSN）取得 | 未 | LLCのEIN取得に必須 |
| 4 | **LLC設立（フロリダ州、オンライン$125）** | **未・最優先** | **DPA/HECVAT/請求書のVendor Name必須** |
| 5 | LLC EIN取得（IRS） | 未 | 大学からの支払い受取、Stripe Businessアカウントに必須 |
| 6 | Business銀行口座開設 | 未 | 大学からの小切手・ACH受取 |
| 7 | Cyber Liability + E&O保険 $1M | 未 | 大学契約で要求される |
| 8 | Deepgram移行（技術） | 未 | [[Deepgram-only設計_2026]] 参照 |
| 9 | プライバシーポリシー改訂（Deepgram反映） | 未 | HECVATと整合 |
| 10 | [[HECVAT_Lite_回答テンプレ]] 最終化 | 完了（ドラフト） | 即回答可能に |
| 11 | VPAT自己評価作成 | 未 | Accessibility訴求必須 |
| 12 | DPAテンプレ作成 | 未 | 大学契約で必須 |
| 13 | FERPA Addendum テンプレ作成 | 未 | 大学契約で必須 |

## フェーズ2: OPT開始（6/1）

| ステップ | 内容 |
|---------|------|
| 1 | ISSに正式報告: 「Lecsy LLCで働く」→ SEVIS登録 |
| 2 | ISSにLecsyをサービス一覧に追加してもらう（留学生向けリソース） |
| 3 | 6/1時点で雇用開始 → 90日ルール即日解消 |

## フェーズ3: 営業開始（6/1〜）

| 期間 | 目標 |
|------|------|
| 6月 | **UF ELI + Santa Fe College** 並行営業開始。無料パイロット提案 |
| 6-7月 | Summer sessionでパイロット運用（10-30学生使用） |
| 7-8月 | フロリダ語学学校にも営業拡大（意思決定2-6週間） |
| 8月 | **判断ポイント**: 有料契約1件でも取れたか？ Fall 2026契約交渉開始 |
| 9月〜 | Fall sessionで本格有料契約（UF ELI flagship） |
| 10月〜 | 実績をもとに他大学IEP（USF, FIU, UCF等）へ拡大 |

### B2B契約に必須な書類（LLC名義）
- [ ] DPA (Data Processing Addendum)
- [ ] FERPA Addendum
- [ ] VPAT (Voluntary Product Accessibility Template)
- [ ] HECVAT Lite 回答セット
- [ ] Certificate of Insurance ($1M Cyber + E&O)
- [ ] W-9 (IRS Form)
- [ ] 1-pager + 提案書 PDF
- [ ] パイロット契約書英文1ページ
- [ ] 有料契約書英文

---

## 法的チェックリスト

- [ ] EADカード受取
- [ ] SSN取得
- [ ] **LLC設立（フロリダ州）** ← B2B契約の前提
- [ ] LLC EIN取得
- [ ] Business銀行口座開設
- [ ] Cyber Liability + E&O 保険加入
- [ ] ISS初回連絡
- [ ] ISS正式雇用報告（6/1）
- [ ] Lecsyをサービス一覧に追加依頼

## クリティカルパス

**LLC設立 → EIN → 銀行口座 → 保険 → 初回B2B契約**

この順序でブロックされる。LLC遅延は全体スケジュールを遅らせる。
**4月末までにLLC申請、5月中に全書類揃えるのが理想。**

## 技術チェックリスト（6/1までに完了必須）

- [x] iOS: PostLoginCoordinator トークンガード + リトライ
- [x] iOS: OrganizationContext 伝播修正
- [x] iOS: CloudSyncService 警告ログ追加
- [ ] Stripe webhook → organizations.plan 更新
- [ ] Web middleware `/org/**` 認可ガード
- [ ] ダッシュボードのデータリーク修正
- [ ] Resendメール接続
- [ ] RLS pgTAPテスト
- [ ] CSVインポートのインジェクション対策

## 財務

- 初期投資: $1,200〜$2,000（LLC + Developer Account + 保険 + 交通費）
- 月間バーンレート: $200〜$550
- 最大ダウンサイド（12ヶ月失敗時）: 約$5,000〜$7,000
