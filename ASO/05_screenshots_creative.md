# 05. スクリーンショット / アイコン / App Preview 戦略

スクショは**ASOの CVR を最大+30%** 動かす最強レバー。
検索結果画面で見える**最初の3枚**が勝負の8割。

> **2026-04-09 方針**:英語圏の大学生をターゲットにするため、**英語版スクショを先に完成**させる(日本語版は後工程でテキスト差し替え)。
> 最初の3枚は **(1) 学生が一瞬で自分事化 → (2) 無料 → (3) プライバシー** の順に固定。Otter / Notta と並んだときに「学生用」「無料」「オフライン」で即判別できることを最優先する。

## サイズ(必須)
- 6.9" (iPhone 17 Pro Max) 1320×2868
- 6.5" (iPhone 11 Pro Max) 1284×2778
- 6.9" を作って流用でOK(Apple が自動適用)
- iPad は B2B 訴求なら追加(12.9")

## 推奨:10枚セット(順番がそのまま表示順)

### 枚 1 — フック「オフラインで動く唯一のAI講義アプリ」
- 背景:講義室の写真(薄暗い)
- 大見出し:**"電波ゼロでも、講義は逃さない"**
- サブ:Wi-Fi 無しアイコン + 録音中インジケータ
- 右下バッジ:**"100% OFFLINE"**

### 枚 2 — 無料訴求 ★最重要スロット
- 大見出し:**"6月1日まで、全部無料"**
- サブ:"広告なし・課金なし・クレカ不要。AI要約まで全部。"
- 実画面:録音リスト画面
- バッジ:**"FREE UNTIL JUNE 1"**
- ※期間限定 + 完全無料 の二段構えで緊急性を作る
- 英語版:`"Free Until June 1 — No Ads, No Subscription"`

### 枚 3 — プライバシー(事実ベース・最強スロット)
- 大見出し:**"音声は、あなたの iPhone から出ません"**
- サブ:"録音ファイルは端末内のみ。サーバーに送りません。"
- 図解:iPhone → ❌ Cloud(音声部分のみ)、iPhone → ✅ Cloud(テキスト同期はオプション)
- ※Otter の名前はスクショに書かない。"他社クラウド型と違い" に留める
- ※**これはコードで裏取り済みの事実**(`10_data_flow_truth.md`)。堂々と言える

### 枚 4 — AI 要約
- 大見出し:**"90分の講義を、30秒で理解"**
- 実画面:AI サマリー画面
- バッジ:**"FREE"**(Pro表記は一切しない)

### 枚 5 — 多言語
- 大見出し:**"12言語に対応、留学生の味方"**
- 国旗バッジ横並び:🇯🇵🇺🇸🇰🇷🇨🇳🇪🇸🇫🇷🇩🇪
- 実画面:英→日 対訳ノート

### 枚 6 — プライバシー二段活用
- 大見出し:**"無料なのに、データを売りません"**
- 実画面:オフライン設定 or 権限説明画面
- サブ:"広告SDK なし・トラッカーなし・IDFA 取得なし。"
- ※ "無料 = データ売られる" という疑いを先回りで潰す(事実なので強い)

### 枚 7 — Web でも読める
- 大見出し:**"iPhone で録って、PC で読む"**
- Web 画面 + iPhone の併置モックアップ

### 枚 8 — バックグラウンド録音
- 大見出し:**"画面を消しても、録音は続く"**
- ロック画面 + 録音インジケータ

### 枚 9 — 対象ユーザーの声(ソーシャルプルーフ)
- 「★★★★★ "Finally an Otter that respects my privacy." — ICU 学生」
- 実レビュー取れたら差し替え

### 枚 10 — CTA
- 大見出し:**"今すぐ無料ダウンロード"**
- App Store バッジ + QR(Webランディング)

## デザインガイド
- **上20%**にコピー、**下80%**に実スクショ(Apple 公式ガイド)
- 文字サイズ **80pt 以上**(検索結果で潰れないように)
- ブランドカラーを固定(例:濃紺 #0B1F3A + アクセント黄 #FFD84D)
- スクショ間で**背景色を変えない**(ブランド一貫性)
- 日本語版と英語版は**テキストのみ差し替え**、構図は完全共通

## App Preview 動画(15-30秒)
**これを作ると CVR が +10-25% 伸びる。必ず作る。**
構成:
1. (0-2s) 講義室で iPhone を録音開始 ← フック
2. (2-6s) 録音中、画面ロック、時間経過
3. (6-10s) 停止 → 文字起こし画面に遷移(一気にテキストが出る)
4. (10-14s) AI 要約ボタン → サマリー表示
5. (14-18s) 試験モード → Q&A
6. (18-22s) 多言語ボタン → 英・日・中の切替
7. (22-25s) App Store バッジ + "Free. Offline. For students."

## アイコン(A/B 候補)
- 現状アイコンのレビューが別途必要。候補:
  - A:マイク + 波形 + 本(教育)
  - B:吹き出し + "L" モノグラム
  - C:波形のみ(ミニマル)
- Product Page Optimization で A/B テスト可能(App Store Connect)

## Product Page Optimization(Apple 公式機能)
- **無料で3つまで** スクショ/アイコン/プレビュー動画の A/B テスト可能
- **常時1枠**回す運用にする(04 の keyword 見直しと同じ月次サイクル)

---

## 📸 英語版スクショ撮影プレイブック(大学生ターゲット版)

英語 10 枚の**撮影→加工→書き出し**まで迷わないための具体指示。
Xcode の iPhone 17 Pro Max シミュレータ(6.9", 1320×2868)で撮れば、6.5" は Apple 側で自動生成される。

### 準備(撮影前に必ずやる)
1. **シミュレータで「Erase All Content and Settings」**(通知バッジ・過去録音の残渣を消す)
2. **Status Bar を整える**:ターミナルで以下を実行(サインアル4本・Wi-Fi 満・バッテリー100%・時刻 9:41)
   ```bash
   xcrun simctl status_bar "iPhone 17 Pro Max" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
   ```
3. **ダミーデータ仕込み**(本物の講義音声でなくていい、**見た目の完成度**が CVR を決める):
   - 録音リストに 5〜6 件、タイトルを学生っぽく:
     - `BIO 201 — Cellular Respiration`
     - `PSYC 101 — Operant Conditioning`
     - `CS 106A — Big-O & Recursion`
     - `ECON 110 — Elasticity of Demand`
     - `HIST 215 — Cold War Lecture 4`
   - duration は 42:11 / 1:18:04 / 56:30 のように **現実的な講義尺**
   - 1 件分だけは transcript / AI summary / Exam Mode の中身まで埋める(枚 4〜5 で使う)
4. **日付を「This week」に寄せる**(Apple レビュワーが未来日でリジェクトしない範囲で)
5. **画面言語を English (US) に**(Settings → General → Language & Region)

### 撮影コマンド
シミュレータでスクショしたい画面を出した状態で:
```bash
xcrun simctl io "iPhone 17 Pro Max" screenshot ~/Desktop/lecsy-shots/01_raw.png
```
`01_raw.png` 〜 `10_raw.png` まで連番で保存。

### 加工テンプレ(Figma 推奨)
- キャンバス:**1320 × 2868**
- 上 20%(=〜574px)に帯コピー、下 80% に端末モックアップ + 生スクショ
- フォント:**Inter Black** もしくは **SF Pro Display Black**、本文 **140pt**、サブ 70pt(Apple の 80pt 最低ルールを上回る)
- カラー:背景 `#0B1F3A` 固定、アクセント `#FFD84D`、白 `#FFFFFF`
- バッジは **右上**に円形(`FREE` `OFFLINE` `NO ADS` 等)
- 10 枚すべて背景色統一(検索結果でブランドとして認識される)

---

### 枚 1 — HOOK : 学生の自己認識を一瞬で掴む(最重要スロット)
- **撮影元画面**:録音リスト(上記ダミーが並んだ状態)
- **上部コピー(英語)**:
  - Headline: **"Record your lecture. Walk out with notes."**
  - Sub: "Works in lecture halls with zero Wi-Fi."
- **バッジ**:右上に `BUILT FOR STUDENTS`
- 狙い:Otter / Notta は "meetings" を訴求している。Lecsy は**"lecture" "walk out"**で学生の1日に刺す。

### 枚 2 — FREE : 無料+期限(2番目に重要)
- **撮影元画面**:AI Summary 完了画面(黄色いサマリーカード)
- **上部コピー**:
  - Headline: **"Free through June 1, 2026"**
  - Sub: "No ads. No subscription. No credit card."
- **バッジ**:`FREE` を巨大に
- 狙い:`Otter $16.99` `Notta $13.99` の価格比較を裏で起動させる。

### 枚 3 — PRIVACY : 唯一無二のエッジ
- **撮影元画面**:Settings → Privacy → Cloud Sync のトグル画面
- **上部コピー**:
  - Headline: **"Your voice stays on your iPhone."**
  - Sub: "Audio is never uploaded. Not to us, not to OpenAI, not to anyone."
- **図解**(Figma で追加):iPhone アイコン → ❌ → Cloud(音声に×)/ iPhone → ✅ → Cloud(テキストは任意)
- ※`10_data_flow_truth.md` で裏取り済みの事実のみ。Otter / Notta の名前は書かない(比較広告ガイドライン回避)。

### 枚 4 — AI SUMMARY : 時間短縮
- **撮影元画面**:AI Summary 画面(key points + outline が見える状態)
- **上部コピー**:
  - Headline: **"A 90-minute lecture, understood in 30 seconds."**
  - Sub: "Key points. Section outlines. Definitions. Automatically."

### 枚 5 — EXAM MODE : 学生の最大の悩みを解決
- **撮影元画面**:Exam Mode の Q&A リスト
- **上部コピー**:
  - Headline: **"AI writes your likely exam questions."**
  - Sub: "With model answers. The night before the test."
- 狙い:**これが大学生に一番刺さる**。Otter にも Notta にも無い機能。

### 枚 6 — MULTILINGUAL SUMMARIES : 留学生(B2B への種)
- **撮影元画面**:AI サマリー画面で出力言語を日本語やスペイン語に切り替えた状態（サマリー言語ピッカー + 非英語サマリー本文が見える）
- **上部コピー**:
  - Headline: **"Studying in your second language?"**
  - Sub: "Record in English. Read AI summaries in your native language. 12 languages."
- **国旗バッジ**:🇺🇸🇪🇸🇨🇳🇰🇷🇯🇵🇫🇷🇩🇪 を横一列

### 枚 7 — OFFLINE TRANSCRIPTION
- **撮影元画面**:文字起こし進行中(オフラインアイコンを見せる)
- **上部コピー**:
  - Headline: **"Works in the basement lecture hall."**
  - Sub: "On-device transcription. No Wi-Fi required."
- **撮影 tip**:シミュレータで `--wifiMode failed` にしてから撮るとオフライン感が出る。

### 枚 8 — BACKGROUND RECORDING
- **撮影元画面**:iPhone ロック画面 + Now Playing に Lecsy 録音中
- **上部コピー**:
  - Headline: **"Lock the screen. Keep recording."**
  - Sub: "Your battery can handle a full 3-hour lecture."

### 枚 9 — WEB ACCESS
- **撮影元画面**:iPhone + Mac ブラウザ(lecsy.app)の併置モックアップ
- **上部コピー**:
  - Headline: **"Record on iPhone. Study on your laptop."**
  - Sub: "Search, copy, and review at lecsy.app."

### 枚 10 — CTA
- **撮影元画面**:アプリアイコン中央 + ホーム画面
- **上部コピー**:
  - Headline: **"Built by one developer. For students who deserve better."**
  - Sub: "Download free — no sign-up required to start recording."
- **バッジ**:`100% FREE` + 小さく `iOS 17.6+`

---

### コピーだけ列挙(Figma に貼る用)

| # | Headline | Sub |
|---|---|---|
| 1 | Record your lecture. Walk out with notes. | Works in lecture halls with zero Wi-Fi. |
| 2 | Free through June 1, 2026 | No ads. No subscription. No credit card. |
| 3 | Your voice stays on your iPhone. | Audio is never uploaded. Not to us, not to OpenAI, not to anyone. |
| 4 | A 90-minute lecture, understood in 30 seconds. | Key points. Section outlines. Definitions. Automatically. |
| 5 | AI writes your likely exam questions. | With model answers. The night before the test. |
| 6 | Studying in your second language? | Record in English. Read AI summaries in your native language. 12 languages. |
| 7 | Works in the basement lecture hall. | On-device transcription. No Wi-Fi required. |
| 8 | Lock the screen. Keep recording. | Your battery can handle a full 3-hour lecture. |
| 9 | Record on iPhone. Study on your laptop. | Search, copy, and review at lecsy.app. |
| 10 | Built by one developer. For students who deserve better. | Download free — no sign-up required to start recording. |

### 絶対に書いてはいけない(事実と外れる or 規約違反)
- ❌ "100% offline"(AI 要約はクラウド)
- ❌ "Better than Otter" 系の明示比較(Apple の比較広告ガイドラインで危険)
- ❌ "#1 lecture app" "Best" 系(リジェクト要因)
- ❌ "Never sends anything to the cloud"(テキスト同期はある)
- ❌ 実在しない学生レビューの捏造(Apple ガイドライン違反)

### 書き出しと App Store Connect 提出
1. Figma で 10 枚を `01_en.png` 〜 `10_en.png` で書き出し(1320×2868 PNG)
2. App Store Connect → App Store → 6.9" Display → en-US ロケール に 10 枚投入
3. en-GB / en-AU / en-CA は en-US と**同一画像**でOK(テキストは英語なので差分不要)
4. ja-JP は後工程:同じ Figma ファイルでテキストレイヤーだけ日本語に差し替えて再書き出し
5. Product Page Optimization で **枚 1 の 2 バリアント**(例:"Record your lecture. Walk out with notes." vs "Turn any lecture into notes. Automatically.")を A/B テストで1枠回す
