# Deepgram リアルタイムSTT実装ベストプラクティス

> 出典: [[NotebookLM_学習/⑨ AI LLM アプリ開発]] / Deepgram 公式
> 対象: lecsy の Deepgram WebSocket 統合

## 5つのベストプラクティス

### 1. WebSocket 接続の維持
**永続的な双方向 WebSocket 接続**を使用し、マイクからの音声をリアルタイムで送受信。
- URL: `wss://api.deepgram.com/v1/listen`
- 切断/再接続のハンドリング必須（[[Swift async await 使い所と落とし穴]]）

### 2. エンドポインティングの活用
Deepgram の **`speech_final` フラグ**を監視し、ユーザーの発話が自然に途切れた瞬間を正確に検知 → パイプライン起動。

```swift
if transcript.speech_final {
    // エンドポイント検出 → Claude に送信
}
```

### 3. タイムスライスによる送信
音声データは **0.25秒（250ms）程度**の短い時間単位でパッケージ化して送信。**遅延最小化**。

```swift
audioRecorder.onBuffer = { buffer in
    // 250ms ごとに WebSocket に送信
    webSocket.send(buffer)
}
```

### 4. モデルの使い分け
- 会議用: Nova-2-Meeting
- 電話用: Nova-2-Phonecall
- 会話型AI用: Nova-2-Conversational
- **語学学習用: Nova-2-General (要検証)**

### 5. 遅延の可視化
**Time-to-First-Byte (TTFB)** を指標として追跡、**300ms 以内**を目指す。

```swift
let ttfb = Date().timeIntervalSince(requestStartTime)
Logger.metric("deepgram_ttfb", value: ttfb)
```

## lecsy での今すぐの改善点

- [ ] `speech_final` を利用した切れ目検出に切り替え（現在は固定タイマー？）
- [ ] タイムスライスを 250ms 基準に
- [ ] TTFB を計測し Supabase にログ → ダッシュボード化
- [ ] モデル選択の A/B テスト（Nova-2-General vs Meeting）

## 関連

- [[Claude プロンプト設計5原則]]
- [[Swift async await 使い所と落とし穴]]
- [[Deepgram/EXECUTION_PLAN]]
