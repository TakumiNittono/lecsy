# Magic Link (Email OTP) — Supabase セットアップ手順

最終更新: 2026-04-07
関連コミット: TBD (後ほど git log で参照)

## なぜマジックリンクを入れたか

`doc/STRATEGIC_REVIEW_2026Q2.md` の国際留学生 + B2B 学校プレイで、Apple/Google だけだと致命的な穴がある:

1. **中国本土の学生は Google にログインできない** (great firewall)
2. **B2B CSV 招待フローが片肺**: 学校が `org-csv-import` で `zhang.wei@nyu.edu` を投入しても、学生がそのメールに紐づく Apple/Google を持ってない → 個人 Gmail でログインしたら別人扱い → ダッシュボードに出ない
3. **ESL Director 商談で必ず聞かれる**: "Apple ID 持ってない学生はどうするの?"

これらを 1 通の "メールで 6 桁コード送信" で全部解決する。

## 実装済の範囲

- ✅ `lecsy/Services/AuthService.swift`: `sendMagicLink(email:)` / `verifyMagicLinkCode(email:code:)`
- ✅ `lecsy/Views/Auth/LoginView.swift`: Email 入力 → コード入力の 2 段 UI、6 桁入力で auto-submit
- ✅ Deep link コールバック: 既存の `lecsyApp.swift` `handleIncomingURL` で `lecsy://auth/callback` を処理済 (link クリック経路もカバー)

## ⚠️ 動かすために必要な Supabase Dashboard 設定

iOS 側のコードは入ってるが、**Supabase 側の設定が無いとメールが送られない**。以下を本番環境 (`bjqilokchrqfxzimfnpm`) で設定:

### 1. Email Provider を有効化

```
Dashboard → Authentication → Providers → Email
  ✅ Enable Email provider
  ✅ Confirm email = OFF (OTP 自体が確認なので不要)
  ✅ Secure email change = ON
```

### 2. SMTP プロバイダを Resend に変更 (重要)

Supabase デフォルトの SMTP は **1 時間 4 通制限**。商談で 10 校に送り出した瞬間に詰まる。Resend に切り替えること。

```
Dashboard → Project Settings → Auth → SMTP Settings
  ✅ Enable Custom SMTP

  Host:        smtp.resend.com
  Port:        587
  User:        resend
  Password:    re_xxxxxxxxxxxx  (Resend dashboard で API key 発行)
  Sender name: Lecsy
  Sender email: noreply@lecsy.app  (Resend で domain 認証済のもの)
```

Resend のセットアップ:
1. https://resend.com/ で signup
2. Add Domain → `lecsy.app` → DNS レコード (SPF/DKIM/DMARC) を Cloudflare 等で設定
3. API Key 発行 → Supabase に貼る

無料プラン: 100 通/日、3000 通/月 — パイロット段階は十分。

### 3. メールテンプレートをカスタマイズ

```
Dashboard → Authentication → Email Templates → Magic Link
```

デフォルトテンプレートは "Click this link" だけで OTP コードを表示しない。**変数 `{{ .Token }}` を必ず追加すること**。

推奨テンプレート (英語):

```html
<h2>Sign in to Lecsy</h2>

<p>Hi,</p>

<p>You requested a sign-in code for Lecsy. Enter this 6-digit code in the app:</p>

<p style="font-size: 32px; font-weight: bold; letter-spacing: 4px; text-align: center; padding: 20px; background: #f3f4f6; border-radius: 12px;">
  {{ .Token }}
</p>

<p>Or click this link to sign in directly:</p>

<p><a href="{{ .ConfirmationURL }}">Sign in to Lecsy</a></p>

<p>This code expires in 1 hour. If you didn't request this, ignore this email.</p>

<p>—<br>The Lecsy Team<br>For international students who study in English</p>
```

### 4. Redirect URLs を許可

```
Dashboard → Authentication → URL Configuration
  Site URL:           https://lecsy.app
  Redirect URLs (1 行ずつ):
    lecsy://auth/callback
    https://lecsy.app/auth/callback
    http://localhost:3000/auth/callback   (開発用)
```

### 5. Rate Limit 確認

```
Dashboard → Authentication → Rate Limits
  ✅ Email signups & sign-ins: 30/hour (デフォルト)
```

パイロット規模では十分。商談 50 校送ってもこのレートに当たらない。

## 動作確認手順

1. iOS シミュレータで Lecsy を起動
2. LoginView で **"OR" 区切り線の下** に "School email" 入力 + "Send code to email" ボタンが見える
3. 自分のメールアドレスを入力 → "Send code to email"
4. メール受信箱に 6 桁コードが届く (Resend 設定済なら 5 秒以内)
5. アプリに戻ると自動で OTP 入力画面に切替済
6. 6 桁入力 → auto-submit → サインイン完了 → メイン画面に遷移

## トラブルシュート

| 症状 | 原因 | 対処 |
|---|---|---|
| "Could not send magic link" エラー | Email Provider 無効 | §1 を確認 |
| メールが届かない (エラーは出ない) | デフォルト SMTP のレート上限 (4/h) | §2 で Resend に切替 |
| メールが届くがリンクだけでコードが無い | テンプレートが `{{ .Token }}` 未含有 | §3 を反映 |
| "Invalid or expired code" | コード入力が 1 時間超過 | "Resend code" で再送 |
| Deep link をタップしてもアプリが開かない | Redirect URL が allowlist に無い | §4 を確認 |
| 中国人学生が "code が来ない" | Resend が中国宛 SMTP block されてる場合あり | 学生に Gmail 以外の母国メール (QQ, 163) を試してもらう |

## B2B CSV 招待フローとの連携

`org-csv-import` Edge Function は学校管理者が CSV で学生メールを投入する。投入後の学生フローは:

```
1. 学校管理者 → /org/[slug]/members → "Import CSV" → メール一覧アップロード
2. organization_members に email + status='pending' で行が作られる
3. 学校管理者から学生に「Lecsy をダウンロードして school email でログインしてください」と連絡
4. 学生 → App Store で Lecsy DL → "Send code to email" → school email 入力
5. メール受信 → コード入力 → サインイン
6. AuthService の auth state change が PostLoginCoordinator を呼ぶ
7. PostLoginCoordinator が organization_members で email match → status='active' に変更
8. ダッシュボードに学生が表示される
```

⚠️ Step 7 の email match は **PostLoginCoordinator が大文字小文字を無視して比較**してることを要確認。`zhang.wei@nyu.edu` と `Zhang.Wei@nyu.edu` が別扱いだとパイロット時に問題になる。

## 残タスク (これは別途やる)

- [ ] Resend account 開設 + DNS レコード設定
- [ ] Supabase Dashboard で §1-§5 を全部反映
- [ ] PostLoginCoordinator の email match を case-insensitive にする (上記注意点)
- [ ] テンプレートを多言語化 (中国語/韓国語/日本語など) — Phase 2
