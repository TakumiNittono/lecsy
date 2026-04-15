# 07. レーティング & レビュー戦略

**★4.5以上** がアルゴリズムの「快適ゾーン」。
★4.0を切ると検索順位が急落する。

## 現状想定のリスク
- DL 500、レビュー数は恐らく 20 未満 → 1件の★1で平均が大きく動く
- 最優先:**レビュー数を 100 件以上に積む**(平均が安定する)

## レビュー依頼の黄金タイミング(実装)
SKStoreReviewController をアプリ内で**"ユーザーが成功を感じた直後"** に呼ぶ。

### 推奨トリガー(優先順)
1. **文字起こしが完了し、ユーザーが結果を3秒以上スクロールした**
2. **AI 要約の生成が完了した**
3. **3回目の録音を完了した**

### NG トリガー
- ❌ 起動直後
- ❌ 有料購入のあとすぐ(強制感)
- ❌ エラー画面の直後

### 実装コード例(Swift)
```swift
import StoreKit

func requestReviewIfAppropriate() {
    let defaults = UserDefaults.standard
    let completedSummaries = defaults.integer(forKey: "completedSummaries")
    let lastPrompt = defaults.double(forKey: "lastReviewPromptDate")
    let now = Date().timeIntervalSince1970

    // 3回目以上の要約完了 & 前回依頼から90日以上
    guard completedSummaries >= 3,
          now - lastPrompt > 60 * 60 * 24 * 90 else { return }

    if let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive })
        as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
        defaults.set(now, forKey: "lastReviewPromptDate")
    }
}
```
Apple は **1年に最大3回** しか実際には表示しないので、安全にトリガーして良い。

## 先に"不満"を逃がす(★1予防)
レビューダイアログの**前に** アプリ内で以下を聞く:
> 「Lecsy を楽しんでいますか?」
> - 😀 はい → SKStoreReviewController 起動
> - 😕 いいえ → フィードバックフォーム(Google Form / mailto:support@lecsy.app)

これで不満ユーザーを App Store ではなくメールに流す。業界標準手法、Apple ガイドラインにも準拠。

## 既存ユーザーへの大量依頼
- **次のアプリアップデート時** に、初回起動時モーダルで「新機能を追加しました。もしよければ★をお願いします」
- push 通知での依頼は Apple NG

## ネガティブレビューへの返信テンプレ
全ての★1-3に 48h 以内返信(返信すると評価を上げてくれる率 33%)。
```
ご指摘ありがとうございます。〇〇の件、次のアップデート(vX.X)で改善予定です。
もしよろしければ support@lecsy.app までご連絡ください、個別に対応いたします。
```

## KPI
- 月次:平均★、新規レビュー数、★1-2率
- 目標:**平均★4.6 / レビュー数 +30/月**
