# Lecsy for Schools — 導入 1 ページ手順書

> 新規導入校に渡す 1 枚紙。先生 1 人 + 生徒 50 人の組織を **5 分** で立ち上げる。

---

## STEP 1 — 名簿を CSV で送る (学校側)

学校管理者は以下のフォーマットの CSV を Lecsy 担当者にメール送付:

```csv
email,role
principal@yourschool.edu,admin
sarah.smith@yourschool.edu,teacher
john.doe@yourschool.edu,teacher
alice@yourschool.edu,student
bob@yourschool.edu,student
...
```

`role` は `admin` / `teacher` / `student` のいずれか。最大 1,000 行まで一度に処理可。

---

## STEP 2 — Lecsy 側で組織作成 + 一括インポート (Lecsy 担当者、約 2 分)

1. https://admin.lecsy.app/admin にスーパー管理者でログイン
2. 「New Organization」→ 学校名・slug・座席数・許可ドメイン (例: `yourschool.edu`) を入力
3. 作成された組織の「Members → Import CSV」を開いて CSV をドラッグ&ドロップ
4. 結果サマリ (成功 / 失敗 / 重複) を確認

この時点で全員に **招待メール** が自動送信される (Apple/Google サインインを促す内容)。

---

## STEP 3 — 学校側にダウンロードリンクを案内 (1 通のメール)

```
件名: Lecsy へようこそ — アプリのダウンロード方法

[学校名] の Lecsy 利用準備ができました。

1. App Store からアプリをダウンロード: https://apps.apple.com/app/lecsy/id...
2. 学校で配布されているメールアドレスで Apple または Google サインイン
3. 自動的に [学校名] のアカウントに参加されます

質問は [担当者メール] まで。
```

---

## STEP 4 — 完了 (生徒側、各自 30 秒)

- 生徒/先生がアプリを開いて Apple/Google でサインイン
- 自動的に組織のメンバーとして active 化される (`activate_pending_memberships` RPC)
- すぐに録音・文字起こし・グロッサリ機能が使える

---

## 管理者ができること (Web ダッシュ)

| 操作 | URL |
|---|---|
| 利用状況・座席数 | `/org/{slug}/usage` |
| メンバー追加・削除・ロール変更 | `/org/{slug}/members` |
| クラス管理 | `/org/{slug}/ai` (グロッサリ含む) |
| 組織設定・ドメイン制限 | `/org/{slug}/settings` |
| 課金 (近日) | `/org/{slug}/settings` (Stripe Customer Portal 経由) |

---

## トラブルシューティング

| 症状 | 対応 |
|---|---|
| 招待メールが届かない | spam 確認 → それでも無ければ Apple/Google サインインで直接入れる (同じメールなら自動ジョイン) |
| 「Seat limit exceeded」エラー | 座席数を超過している。`Settings` から座席数を増やす or 不要メンバーを削除 |
| 「Domain not allowed」エラー | 組織の `allowed_email_domains` にそのメールドメインが入っていない。Settings から追加 |
| サインインしても組織に入らない | メールアドレスが完全一致していないか、`status` が既に `active` の重複行がある可能性 |

---

## 営業時のチェックリスト

- [ ] デモ組織 `lecsy-demo` (https://admin.lecsy.app/org/lecsy-demo) を見せる
- [ ] CSV インポート → 即座に 50 名追加できることを実演
- [ ] 座席上限が **本当に** 弾くことを実演 (`max_seats: 3` のテスト org で 4 人目を追加)
- [ ] iOS アプリで実際にサインイン → 自動ジョインされる流れを実演
- [ ] 価格表 (Starter $299/mo, Growth $599/mo, Business カスタム) を提示
