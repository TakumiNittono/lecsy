# Deepgram リアルタイム字幕 実装仕様書

作成日: 2026-04-13
関連: [[Deepgramセットアップ手順]] / [[iOSアプリ設計]] / [[リアルタイム文字起こしAPI比較]] / [[lecsyパイプライン完全設計]] / [[ローンチ戦略_6月1日無料開放]] / [[CURRENT_STATUS]]

---

## 0. この文書の位置づけ

Battle Plan「5月: Deepgram Swift SDK統合PoC」「6月: WhisperKit/Deepgram切り替えロジック」の実装スペック。
**方針**: サンプル実装をベースに、**本番運用に耐える構造**で一発目から書く。PoCで動けばそのままMVPへ。

---

## 1. アーキテクチャ全体像

```
┌────────────────────────────────────────────────────────────────┐
│                         iOS App                                │
│                                                                │
│  ┌──────────────────┐                                          │
│  │  RecordingView   │ ← ユーザーが「録音開始」タップ             │
│  └────────┬─────────┘                                          │
│           ▼                                                    │
│  ┌──────────────────────────────────────────────┐              │
│  │       TranscriptionCoordinator               │              │
│  │  （ネットワーク判定 → エンジン選択）            │              │
│  └────┬──────────────────────┬──────────────────┘              │
│       │ online               │ offline / fallback              │
│       ▼                      ▼                                 │
│  ┌──────────────┐      ┌────────────────┐                      │
│  │ DeepgramLive │      │  WhisperKitLive│                      │
│  │ Service      │      │  Service       │                      │
│  └──────┬───────┘      └────────┬───────┘                      │
│         │                        │                             │
│         └──────────┬─────────────┘                             │
│                    ▼                                           │
│         @Published transcript: [Segment]                       │
│                    ▼                                           │
│  ┌──────────────────────────────────────────┐                  │
│  │      LiveCaptionView (SwiftUI)           │                  │
│  │  [BETA] badge + interim/final 差分表示    │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
         │
         ▼ (APIキー取得は常にEdge Function経由、クライアントに埋め込まない)
┌────────────────────────────────────────────────────────────────┐
│  Supabase Edge Function: deepgram-token                        │
│  - ユーザー認証確認                                              │
│  - Deepgram残高チェック（$100割ったら拒否）                      │
│  - 短寿命トークン発行（15分TTL）                                 │
│  - 使用量を org_usage_monthly に記録                            │
└────────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────────┐
│  Deepgram API (wss://api.deepgram.com/v1/listen)               │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. 依存関係

### Swift Package Manager

```
Starscream         4.0.8+      WebSocket クライアント
                               (URLSessionWebSocketTask でも可だが Starscream の方が iOS 15互換で安定)
```

**注**: 公式「Deepgram Swift SDK」は2026年4月時点で**存在しない**（WebSocket直叩き一択）。[[リアルタイム文字起こしAPI比較]] の記述は誤り。Go/JS/Python/.NETのみ公式SDKあり。

### Info.plist

```xml
<key>NSMicrophoneUsageDescription</key>
<string>講義を録音してリアルタイム字幕を生成するためマイクへのアクセスが必要です。</string>
```

### xcconfig

```
// Debug.xcconfig
DEEPGRAM_TOKEN_ENDPOINT = https://$(SUPABASE_PROJECT_REF).supabase.co/functions/v1/deepgram-token
```

**APIキーを iOS バイナリに埋め込まない**。必ず Edge Function 経由で短寿命トークンを取得。

---

## 3. Deepgram WebSocket 接続パラメータ

### lecsy 用の決定版 URL

```
wss://api.deepgram.com/v1/listen
  ?model=nova-3
  &language=en
  &encoding=linear16
  &sample_rate=16000
  &channels=1
  &interim_results=true
  &smart_format=true
  &punctuate=true
  &diarize=false
  &endpointing=300
  &utterance_end_ms=1000
  &vad_events=true
  &filler_words=false
```

### 各パラメータの根拠

| パラメータ | 値 | 理由 |
|-----------|-----|------|
| `model` | `nova-3` | 最新・最高精度・日本語対応（2025年3月リリース） |
| `language` | `en` | ESL講義は英語。多言語混在が必要なら `multi` に切替（monolingual→multilingual でコスト1.2倍） |
| `encoding` | `linear16` | AVAudioEngineから素直に出せる。PCM16bit |
| `sample_rate` | `16000` | 48kHzでも動くが、STT精度は16kHzで十分。**帯域1/3** で通信コスト削減 |
| `channels` | `1` | mono。音声講義用途で2ch不要 |
| `interim_results` | `true` | 発話中に暫定字幕を表示（UX最重要） |
| `smart_format` | `true` | "three dollars" → "$3", "at gmail dot com" → "@gmail.com" |
| `punctuate` | `true` | 句読点・大文字化。ESL学習者の読みやすさに直結 |
| `diarize` | `false` | **MVPでは false**。講義は教授1人想定。話者分離ONにすると精度トレードオフ発生 |
| `endpointing` | `300` | 300ms無音で文確定。デフォ10msは早すぎる |
| `utterance_end_ms` | `1000` | 1秒無音で UtteranceEnd イベント発火。段落区切りに使う |
| `vad_events` | `true` | SpeechStarted イベント受信。バッテリー最適化に使う |
| `filler_words` | `false` | "um" "uh" を落とす。ESL講義ではノイズ |

### 将来追加検討

| パラメータ | 条件 |
|-----------|------|
| `diarize=true` | Phase C（2026-11）で話者分離UI追加時 |
| `keyterm=ESL,pronunciation,grammar` | 専門用語ブースト。教授ごとにキーワード学習 |
| `redact=pci,numbers,ssn` | B2Bエンタープライズ契約時（コンプラ要件） |
| `detect_entities=true` | 語彙カード自動抽出の強化 |

---

## 4. Swift 実装（本番クラス）

### 4.1 型定義

```swift
// Models/DeepgramMessage.swift
import Foundation

enum DeepgramMessage: Decodable {
    case results(Results)
    case metadata(Metadata)
    case speechStarted(SpeechStarted)
    case utteranceEnd(UtteranceEnd)
    
    private enum CodingKeys: String, CodingKey { case type }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let single = try decoder.singleValueContainer()
        switch type {
        case "Results":       self = .results(try single.decode(Results.self))
        case "Metadata":      self = .metadata(try single.decode(Metadata.self))
        case "SpeechStarted": self = .speechStarted(try single.decode(SpeechStarted.self))
        case "UtteranceEnd":  self = .utteranceEnd(try single.decode(UtteranceEnd.self))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown Deepgram message type: \(type)")
        }
    }
    
    struct Results: Decodable {
        let channelIndex: [Int]
        let duration: Double
        let start: Double
        let isFinal: Bool
        let speechFinal: Bool
        let channel: Channel
        
        struct Channel: Decodable {
            let alternatives: [Alternative]
        }
        struct Alternative: Decodable {
            let transcript: String
            let confidence: Double
            let words: [Word]
        }
        struct Word: Decodable {
            let word: String
            let start: Double
            let end: Double
            let confidence: Double
            let speaker: Int?
        }
    }
    struct Metadata: Decodable {
        let requestId: String
        let duration: Double
    }
    struct SpeechStarted: Decodable {
        let timestamp: Double
    }
    struct UtteranceEnd: Decodable {
        let lastWordEnd: Double
    }
}

// Models/LiveCaptionSegment.swift
struct LiveCaptionSegment: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var isFinal: Bool
    var startTime: TimeInterval
    var endTime: TimeInterval
    var confidence: Double
}
```

### 4.2 本体サービス

```swift
// Services/DeepgramLiveService.swift
import Foundation
import AVFoundation
import Combine
import Starscream

@MainActor
final class DeepgramLiveService: NSObject, ObservableObject {
    
    @Published private(set) var segments: [LiveCaptionSegment] = []
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: Error?
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed
    }
    
    enum ServiceError: LocalizedError {
        case tokenFetchFailed
        case budgetExceeded
        case socketClosed(code: UInt16, reason: String)
        
        var errorDescription: String? {
            switch self {
            case .tokenFetchFailed:          return "Deepgram認証に失敗しました"
            case .budgetExceeded:            return "当月のリアルタイム字幕利用上限に達しました"
            case .socketClosed(let c, let r): return "接続が切断されました (\(c): \(r))"
            }
        }
    }
    
    private let audioEngine = AVAudioEngine()
    private var socket: WebSocket?
    private var keepAliveTimer: Timer?
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 3
    private var currentInterimText: String = ""
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    private let tokenProvider: DeepgramTokenProviding
    
    init(tokenProvider: DeepgramTokenProviding) {
        self.tokenProvider = tokenProvider
        super.init()
    }
    
    // MARK: - Public API
    
    func start() async throws {
        guard connectionState == .disconnected else { return }
        connectionState = .connecting
        
        let token: String
        do {
            token = try await tokenProvider.fetchShortLivedToken()
        } catch {
            connectionState = .failed
            throw ServiceError.tokenFetchFailed
        }
        
        try await connectSocket(token: token)
        try startAudioEngine()
        startKeepAlive()
    }
    
    func stop() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        sendCloseStream()
        socket?.disconnect()
        socket = nil
        connectionState = .disconnected
        reconnectAttempt = 0
    }
    
    // MARK: - Socket
    
    private func connectSocket(token: String) async throws {
        var request = URLRequest(url: Self.buildURL())
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        let socket = WebSocket(request: request)
        socket.delegate = self
        self.socket = socket
        socket.connect()
    }
    
    private static func buildURL() -> URL {
        var comps = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        comps.queryItems = [
            .init(name: "model",           value: "nova-3"),
            .init(name: "language",        value: "en"),
            .init(name: "encoding",        value: "linear16"),
            .init(name: "sample_rate",     value: "16000"),
            .init(name: "channels",        value: "1"),
            .init(name: "interim_results", value: "true"),
            .init(name: "smart_format",    value: "true"),
            .init(name: "punctuate",       value: "true"),
            .init(name: "endpointing",     value: "300"),
            .init(name: "utterance_end_ms", value: "1000"),
            .init(name: "vad_events",      value: "true"),
            .init(name: "filler_words",    value: "false"),
        ]
        return comps.url!
    }
    
    // MARK: - Audio Engine
    
    private func startAudioEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .spokenAudio,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Deepgram送信用: 16kHz linear16 mono
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "DeepgramLiveService", code: -1)
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "DeepgramLiveService", code: -2)
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }
            guard let converted = self.convert(buffer: buffer, using: converter, to: outputFormat) else { return }
            if let data = self.pcmBufferToData(converted) {
                self.socket?.write(data: data)
            }
        }
        
        try audioEngine.start()
    }
    
    private func convert(buffer: AVAudioPCMBuffer,
                         using converter: AVAudioConverter,
                         to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        
        var error: NSError?
        var fed = false
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
    
    private func pcmBufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        let channels = buffer.audioBufferList.pointee.mBuffers
        return Data(bytes: channels.mData!, count: Int(channels.mDataByteSize))
    }
    
    // MARK: - Keep-Alive
    
    private func startKeepAlive() {
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            let payload = #"{"type":"KeepAlive"}"#
            self?.socket?.write(string: payload)
        }
    }
    
    private func sendCloseStream() {
        let payload = #"{"type":"CloseStream"}"#
        socket?.write(string: payload)
    }
    
    // MARK: - Message Handling
    
    private func handle(message: DeepgramMessage) {
        switch message {
        case .results(let r):
            guard let alt = r.channel.alternatives.first else { return }
            if r.isFinal {
                if !alt.transcript.isEmpty {
                    segments.append(LiveCaptionSegment(
                        text: alt.transcript,
                        isFinal: true,
                        startTime: r.start,
                        endTime: r.start + r.duration,
                        confidence: alt.confidence
                    ))
                }
                currentInterimText = ""
            } else {
                currentInterimText = alt.transcript
                // 最後のセグメントを暫定テキストで上書き表示する責務はViewModel側に委譲
            }
        case .metadata:      break
        case .speechStarted: break
        case .utteranceEnd:  break // 段落区切りに使う場合はここでflush
        }
    }
    
    // MARK: - Reconnect
    
    private func attemptReconnect() {
        guard reconnectAttempt < maxReconnectAttempts else {
            connectionState = .failed
            return
        }
        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)
        let delay = pow(2.0, Double(reconnectAttempt)) // 2s, 4s, 8s
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await start()
        }
    }
}

extension DeepgramLiveService: WebSocketDelegate {
    nonisolated func didReceive(event: WebSocketEvent, client: WebSocket) {
        Task { @MainActor in
            switch event {
            case .connected:
                connectionState = .connected
                reconnectAttempt = 0
            case .text(let text):
                guard let data = text.data(using: .utf8) else { return }
                do {
                    let msg = try decoder.decode(DeepgramMessage.self, from: data)
                    handle(message: msg)
                } catch {
                    lastError = error
                }
            case .disconnected(let reason, let code):
                lastError = ServiceError.socketClosed(code: code, reason: reason)
                attemptReconnect()
            case .error(let err):
                lastError = err
                attemptReconnect()
            case .cancelled:
                connectionState = .disconnected
            default:
                break
            }
        }
    }
}

// MARK: - Token Provider

protocol DeepgramTokenProviding {
    func fetchShortLivedToken() async throws -> String
}

final class EdgeFunctionTokenProvider: DeepgramTokenProviding {
    private let supabase: SupabaseClient
    init(supabase: SupabaseClient) { self.supabase = supabase }
    
    func fetchShortLivedToken() async throws -> String {
        struct Response: Decodable { let token: String }
        let res: Response = try await supabase.functions.invoke("deepgram-token")
        return res.token
    }
}
```

### 4.3 Supabase Edge Function

```typescript
// supabase/functions/deepgram-token/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response('Unauthorized', { status: 401 });
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });
  
  // 残高チェック
  const balance = await fetchDeepgramBalance();
  if (balance < 100) {
    return new Response(JSON.stringify({ error: 'budget_exceeded' }), { status: 402 });
  }
  
  // ユーザー単位のレート制限（1日2時間）
  const usage = await getUserDailyUsageMinutes(user.id);
  if (usage > 120) {
    return new Response(JSON.stringify({ error: 'daily_cap' }), { status: 429 });
  }
  
  // 短寿命トークン発行（Deepgram Project APIs）
  const token = await mintDeepgramProjectKey({
    scopes: ['usage:write'],
    expirationSeconds: 900,  // 15分
    comment: `user:${user.id}`,
  });
  
  return Response.json({ token });
});
```

---

## 5. WhisperKit フォールバック切替ロジック

### 5.1 TranscriptionCoordinator

```swift
// Services/TranscriptionCoordinator.swift
@MainActor
final class TranscriptionCoordinator: ObservableObject {
    enum Mode: Equatable {
        case deepgram
        case whisperKit
    }
    
    @Published private(set) var mode: Mode = .deepgram
    @Published private(set) var reason: String = ""
    
    private let network: NetworkMonitor
    private let deepgram: DeepgramLiveService
    private let whisperKit: WhisperKitLiveService
    
    func start() async throws {
        mode = decideMode()
        switch mode {
        case .deepgram:
            do {
                try await deepgram.start()
            } catch {
                // Deepgram失敗時は自動フォールバック
                mode = .whisperKit
                reason = "Deepgram unreachable, falling back to offline transcription"
                try await whisperKit.start()
            }
        case .whisperKit:
            try await whisperKit.start()
        }
    }
    
    private func decideMode() -> Mode {
        if !network.isOnline { reason = "offline"; return .whisperKit }
        if UserDefaults.standard.bool(forKey: "ferpa_strict_mode") {
            reason = "FERPA strict mode"
            return .whisperKit
        }
        return .deepgram
    }
}
```

### 5.2 切替ルール

| 条件 | エンジン | 発火タイミング |
|------|---------|--------------|
| ネットワーク無し | WhisperKit | 起動時 + 録音中の切断検知 |
| FERPA厳格モード ON | WhisperKit | 起動時 |
| Deepgram 3回連続再接続失敗 | WhisperKit | 録音中 |
| Deepgram残高 $100以下（Edge Function 402応答） | WhisperKit | 起動時 |
| ユーザー日次上限（2時間/日）超過 | WhisperKit | 起動時 |
| 上記以外 | Deepgram | デフォルト |

### 5.3 切替時のUX

- トースト: 「オフラインに切り替わりました（WhisperKitで継続）」
- 字幕上部に小さなバナー: `📡 Offline transcription`
- **録音は絶対に止めない**。継続性最優先。

---

## 6. ベータ UX 実装

### 6.1 BETAバッジコンポーネント

```swift
// Views/Components/BetaBadge.swift
struct BetaBadge: View {
    var body: some View {
        Text("BETA")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.yellow)
            .clipShape(Capsule())
    }
}
```

### 6.2 初回起動時ダイアログ

```swift
// Views/LiveCaptionView.swift 内
.onAppear {
    if !UserDefaults.standard.bool(forKey: "seen_realtime_caption_beta_dialog") {
        showBetaDialog = true
        UserDefaults.standard.set(true, forKey: "seen_realtime_caption_beta_dialog")
    }
}
.alert("リアルタイム字幕（ベータ）", isPresented: $showBetaDialog) {
    Button("フィードバックを送る") { openFeedbackForm() }
    Button("OK", role: .cancel) { }
} message: {
    Text("この機能は実験中です。字幕の精度や遅延が不安定な場合があります。\n6/1まで無料で全員にご利用いただけます。フィードバックお待ちしています。")
}
```

### 6.3 App Store リリースノート（テンプレ）

```
🆕 New: Real-time captions (Beta)
Get live English captions as you record lectures. 
Free for everyone until June 1, 2026.

Know before you use:
• Beta feature — accuracy may vary
• Requires network connection (offline mode still available)
• Tap feedback button in-app to help us improve
```

---

## 7. コスト監視と安全弁

### 7.1 Deepgram残高監視 Edge Function（cron）

```typescript
// supabase/functions/deepgram-balance-check/index.ts
// 毎日 UTC 00:00 に実行

Deno.serve(async () => {
  const balance = await fetchDeepgramBalance();
  
  if (balance < 150) {
    await notifyAdmin({ level: 'warning', balance });
  }
  if (balance < 100) {
    await notifyAdmin({ level: 'critical', balance });
    // feature_flags テーブルで realtime_captions を OFF に
    await supabase.from('feature_flags')
      .update({ enabled: false })
      .eq('name', 'realtime_captions_beta');
  }
});
```

### 7.2 使用量記録

Deepgram残高は `GET https://api.deepgram.com/v1/projects/{project_id}/balances` で取得。
各セッション終了時に Metadata メッセージの `duration` を `org_usage_monthly.realtime_seconds` に加算。

### 7.3 ユーザー毎の使用量可視化（将来）

Pro移行誘導用: 「今週、リアルタイム字幕を○時間使いました（有料換算$X）」をProfile画面に表示。**使った価値の可視化**は6/1の課金転換率に直結。

---

## 8. エラーハンドリング マトリクス

| エラー | 発生箇所 | ユーザー影響 | 対応 |
|-------|---------|-------------|------|
| Edge Functionで token取得失敗 | 起動時 | 録音不可 | WhisperKitへ自動切替 |
| WebSocket接続タイムアウト | 起動時 | 録音不可 | 2s/4s/8s で3回再接続 → WhisperKit |
| 401 Unauthorized | 録音中 | 切断 | トークン再取得して再接続 |
| 1011 Internal Error | 録音中 | 切断 | 即再接続 |
| 1008 Policy Violation（音声形式不一致） | 録音中 | 切断 | ログ収集→バグとして修正（再接続せず） |
| 10秒間無音で自動切断 | 録音中 | 切断 | KeepAliveで予防。切れたら再接続 |
| ネットワーク喪失 | 録音中 | 切断 | WhisperKitへシームレス切替 |
| Deepgram残高切れ（402） | 起動時 | 録音不可 | WhisperKitへ切替 + 管理者通知 |
| JSON decode失敗 | 録音中 | 部分欠損 | そのメッセージだけ無視。接続は維持 |

---

## 9. テスト戦略

### 9.1 単体テスト

```swift
// DeepgramMessageTests.swift
final class DeepgramMessageTests: XCTestCase {
    func test_decode_results_interim() { /* ... */ }
    func test_decode_results_final() { /* ... */ }
    func test_decode_speech_started() { /* ... */ }
    func test_decode_utterance_end() { /* ... */ }
    func test_decode_unknown_type_throws() { /* ... */ }
}
```

### 9.2 統合テスト（手動）

| シナリオ | 期待動作 |
|---------|---------|
| 5分連続録音 | 切断なし、字幕が順次表示される |
| 録音中に機内モード ON | WhisperKitへ切替、字幕継続 |
| 録音中に機内モード OFF → ON → OFF | Deepgramへ復帰、または WhisperKit継続（ユーザー設定次第） |
| 画面ロック | バックグラウンドで録音継続（Audio Background Mode必要） |
| 着信 | 録音一時停止→再開時に再接続 |
| 30分沈黙後に発話 | KeepAliveで接続維持、字幕出る |
| 教室Wi-Fi（低帯域・高ジッター） | 200-500msの遅延で字幕出る |

### 9.3 品質ゲート（公開前）

- [ ] 10分連続録音で切断率 <1%
- [ ] 英語講義サンプルでWER <12%（許容ライン）
- [ ] レイテンシ p50 <400ms, p95 <800ms
- [ ] フォールバック切替時に字幕が途切れない
- [ ] バッテリー消費 20%未満/時（iPhone 15 Pro, Wi-Fi, 明度中）

---

## 10. ロールアウト計画

| フェーズ | 期間 | 対象 | Goal |
|---------|------|------|------|
| α（内部） | 4/13-4/27 | 自分のみ | PoC完成、実環境で10時間録音テスト |
| β限定公開 | 4/28-5/11 | TestFlight 20人 | レイテンシ/精度計測、クラッシュゼロ確認 |
| β全公開 | 5/12-5/31 | App Store全ユーザー | 「BETA」明示で開放、フィードバック収集 |
| v1 | 6/1〜 | Pro限定機能化 | 無料期間終了、Proプランへ誘導 |

### α→β昇格基準
- [ ] クラッシュなしで10時間録音成功
- [ ] 切断後の自動再接続が確実に動く
- [ ] WhisperKitフォールバックが動く

### β→v1昇格基準
- [ ] App Storeレビュー平均4.3以上維持
- [ ] Deepgram残高消費ペースが予測範囲内
- [ ] 課金フロー動作確認済み

---

## 11. 既知の落とし穴

1. **AVAudioSession.Category を `.record` にすると Bluetooth出力が死ぬ** → `.playAndRecord` + `.allowBluetooth` が正解
2. **inputNode.inputFormat のsampleRate は端末依存**（iPhoneは48000が多いがヘッドセット接続で変わる）→ 必ず AVAudioConverterで16kHzに正規化
3. **Starscream の `didReceive` は non-main スレッド** → `Task { @MainActor in ... }` でUIアクセスを守る
4. **KeepAlive を音声データとして送ると切られる**（RFC-6455違反） → 必ず `write(string:)` で制御フレームとして送る
5. **WebSocket切断時、audioEngine.stop() を忘れるとマイクが握りっぱなし** → 必ず対で呼ぶ
6. **バックグラウンド録音には Info.plist に `UIBackgroundModes: audio` が必須**
7. **Deepgramの10秒アイドル切断** → KeepAliveは5-10秒間隔が安全
8. **interim_results の transcript は途中で短くなる**（確定前の訂正で） → UIは「最新のinterimで上書き」、確定時のみsegment配列に追加

---

## 12. 参考資料

- [Deepgram公式: Live Transcriptions with iOS](https://deepgram.com/learn/ios-live-transcription)
- [Deepgram公式: Lower-Level Websockets](https://developers.deepgram.com/docs/lower-level-websockets)
- [Deepgram API Reference: listen-streaming](https://developers.deepgram.com/reference/speech-to-text/listen-streaming)
- [Starscream GitHub](https://github.com/daltoniam/Starscream)
- [サンプル実装: deepgram-devs/deepgram-live-transcripts-ios](https://github.com/deepgram-devs/deepgram-live-transcripts-ios)

---

## 13. 実装順序（推奨）

1. **Week 1（4/13-4/20）**
   - [ ] Supabase Edge Function `deepgram-token` 作成（残高チェック付き）
   - [ ] DeepgramMessage型 + 単体テスト
   - [ ] DeepgramLiveService の接続・切断のみ実装
   - [ ] 自分のiPhoneで接続確認（字幕が出ればOK）

2. **Week 2（4/21-4/27）**
   - [ ] 音声送信（AVAudioEngine + Converter）実装
   - [ ] interim/final 切り分けUI
   - [ ] KeepAlive + 再接続
   - [ ] 実講義で10時間テスト

3. **Week 3（4/28-5/4）**
   - [ ] WhisperKitフォールバック統合
   - [ ] BETAバッジ + 初回ダイアログ
   - [ ] Edge Function残高監視
   - [ ] TestFlight α配布

4. **Week 4（5/5-5/11）**
   - [ ] フィードバック反映
   - [ ] 品質ゲート計測
   - [ ] App Store β提出

5. **Week 5+（5/12〜）**
   - [ ] β全公開
   - [ ] バグフィックス継続
   - [ ] 6/1 Pro機能化準備

---

*次回更新: Week 1完了時（接続確認後）*
