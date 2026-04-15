# 09. 実行チェックリスト(優先順)

**このファイルを毎日開く。** 終わったら ✅ を入れる。

## 🔴 提出ブロッカー(これをやる前にストア提出しない)
- [x] **`supabase/functions/summarize/index.ts` の organization membership ゲートを外した** ✅ 2026-04-08
  - サインイン済みなら誰でも要約可。レート制限は日次20件/月400件で継続
- [x] **`web/utils/isPro.ts` を全員Pro化**(source: 'free-for-all')✅ 2026-04-08
- [ ] **デプロイ**:`supabase functions deploy summarize` 実行
- [ ] **動作確認**:新規アカウント作成 → 録音 → AI要約が通ることを iOS / Web 両方で確認
- [ ] `PRIVACY_POLICY.md` に「AI要約時は文字起こしテキストが OpenAI に送信される」旨を追記(漏れているなら)
- [ ] Cloud Sync の ON/OFF 設定 UI があるか確認(プラポリで「いつでもオフにできる」と書いているため)
- [ ] 既存の `AISummaryButton.tsx` / `ExamModeButton.tsx` の `isPro` 表示は `getProStatus` 経由で自動的に解放される(コード変更不要)が、実機で "Upgrade to Pro" 表示が出ないことを目視確認

## 🔥 今週やる(Week 1)
- [ ] `04_metadata_master.md` の JP/EN メタデータを App Store Connect に反映
  **※ サブタイトル/スクショの「AI要約まで無料」が今フェーズの最重要メッセージ**
- [ ] en-GB と en-AU ロケールを追加(テキストは en-US からコピペ)
- [ ] カテゴリを Education(primary)/ Productivity(secondary)に設定
- [ ] Promotional Text に「完全無料」キャンペーン文言セット
- [ ] 現行スクショを `05` の構図で再制作開始(枚2「AI要約まで全部無料」を先行)
- [ ] 07 の SKStoreReviewController を実装(前に Happy/Not-happy ダイアログ)
- [ ] **広告実装まわり**:
  - [ ] AdMob SDK 導入、コンテンツフィルタ "G"(4+維持)
  - [ ] ATT ダイアログを初回録音完了後に表示
  - [ ] App Store Connect "App Privacy" で IDFA/Usage Data/Diagnostics を宣言
  - [ ] SKAdNetwork ID を Info.plist に追加
- [ ] 次回アプリ提出に上記を全て入れる

## ⚡ 今月やる(Week 2-4)
- [ ] スクショ10枚 完成
- [ ] App Preview 動画 15-30秒 完成
- [ ] Product Page Optimization:アイコン A/B テスト開始
- [ ] Web に ASO 向けブログ3本(Otter alternative / Offline transcription / International students)
- [ ] Product Hunt ローンチ準備(Maker アカウント、teaser 画像、launch day coordinators)
- [ ] Reddit 3投稿、24h 以内に返信を全て対応
- [ ] 既存レビュー(★1-3)に全返信
- [ ] App Store Connect > Analytics > Search Terms の現状スクショ保存(Before)

## 📈 2ヶ月目(Week 5-8)
- [ ] TikTok / YouTube Shorts 10本
- [ ] 留学生インフルエンサー5人にギフト Pro
- [ ] ko / es-MX ロケール追加(DeepL + Fiverr ネイティブ校正)
- [ ] Search Terms 見直し → Name/Subtitle 更新(次バージョン)
- [ ] 平均★4.5 維持 確認

## 🎯 3ヶ月目(Week 9-12)
- [ ] zh-Hans ロケール追加
- [ ] Apple "Today" エディトリアル申請
- [ ] フロリダ ESL 学校 30校に営業メール(sales/ 連携)
- [ ] 学生アンバサダー制度ローンチ
- [ ] ★4.6 / 100レビュー達成したら、Apple Search Ads を $50/日でテスト開始

---

## 判定基準(これを満たしたら次のフェーズへ)

### Phase 1 → Phase 2
- スクショ新版リリース済み
- レビュー依頼実装済み
- ★4.5 維持
- CVR 5%↑

### Phase 2 → Phase 3
- DL 2,000超
- "otter alternative" 検索で表示されている(Search Terms で確認)
- レビュー 50件超

### Phase 3 → Phase 4
- DL 5,000超
- CVR 7%↑
- ★4.6↑
- TikTok / Shorts から週100 DL以上の流入

### 最終ゴール(Week 12)
- **DL 10,000**
- **★4.6 / レビュー 150+**
- **主要 KW "講義 録音 AI" "otter alternative" で上位20位以内**
- これを B2B セールスデックに埋め込み、語学学校営業の"信用装置"として機能させる

---

## 連携リファレンス
- B2B 戦略:`memory/project_b2b_strategy.md`
- B2C 戦略:`memory/project_b2c_strategy.md`
- 既存メタデータ元:`doc/deployment/APP_STORE_METADATA.md`
- Sales パイプ:`sales/` ディレクトリ
