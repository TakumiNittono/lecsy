# Deepgram リアルタイム字幕 実装ガイド（単体版）

作成日: 2026-04-13
対象: lecsy iOSアプリにDeepgram Nova-3ストリーミング音声認識を統合する
前提: Swift / SwiftUI / AVFoundation / Supabase (auth + Edge Functions)

> このファイル1つで **アカウント作成 → Supabase側 → iOS側 → 実装 → テスト → 本番化** まで全てカバーする。他ファイル参照不要。

---

## 目次

1. [アーキテクチャ](#1-アーキテクチャ)
2. [必要なもの](#2-必要なもの)
3. [Deepgramアカウント準備](#3-deepgramアカウント準備)
4. [Supabase側の構築](#4-supabase側の構築)
5. [iOS Xcodeプロジェクト準備](#5-ios-xcodeプロジェクト準備)
6. [WebSocketパラメータ仕様](#6-websocketパラメータ仕様)
7. [Swift実装コード](#7-swift実装コード)
8. [WhisperKitフォールバック](#8-whisperkitフォールバック)
9. [BETAラベル UX](#9-betaラベル-ux)
10. [コスト監視と安全弁](#10-コスト監視と安全弁)
11. [エラーハンドリングマトリクス](#11-エラーハンドリングマトリクス)
12. [テスト戦略](#12-テスト戦略)
13. [よくあるハマりどころ](#13-よくあるハマりどころ)
14. [セキュリティ](#14-セキュリティ)
15. [動作確認チェックリスト](#15-動作確認チェックリスト)

---

## 1. アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                         iOS App                         │
│                                                         │
│   [RecordingView] ─→ [TranscriptionCoordinator]         │
│                            ├── online ──→ DeepgramLive  │
│                            └── offline ─→ WhisperKitLive│
│                                    │                    │
│                                    ▼                    │
│                          @Published segments            │
│                                    │                    │
│                                    ▼                    │
│                          [LiveCaptionView] + BETA badge │
└─────────────────────────────────────────────────────────┘
             │
             │ 短寿命トークン取得
             ▼
┌─────────────────────────────────────────────────────────┐
│  Supabase Edge Function: deepgram-token                 │
│   1. ユーザー認証                                        │
│   2. Deepgram残高チェック（$100以下で拒否）              │
│   3. 日次使用量チェック（2h/日で拒否）                   │
│   4. 短寿命トークン発行（TTL 15分）                     │
└─────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────┐
│        wss://api.deepgram.com/v1/listen?model=nova-3... │
└─────────────────────────────────────────────────────────┘
```

**原則:** Deepgram管理者キーは**絶対にiOSバイナリに含めない**。Supabase Edge Function経由で短寿命トークンを発行する。

---

## 2. 必要なもの

### アカウント
- Deepgramアカウント（https://console.deepgram.com）
- Supabaseプロジェクト（既存）
- Apple Developer Program契約（既存）

### iOS依存関係
- **Starscream 4.0.8+**（WebSocketクライアント）
  - `https://github.com/daltoniam/Starscream`
  - 理由: 公式 Deepgram Swift SDK は2026年4月時点で**存在しない**。URLSessionWebSocketTask でも可だが Starscream の方が iOS互換と再接続が安定

### Supabase依存関係
- Edge Functions有効化
- Postgres（テーブル2つ追加）
- Secrets設定

---

## 3. Deepgramアカウント準備

### 3.1 サインアップ
- URL: https://console.deepgram.com/signup
- **クレジットカード不要**
- $200フリークレジット自動付与
- プラン: **Pay As You Go** を選択

### 3.2 Project構成

2つに分ける（フリークレジット保護とセキュリティ分離のため）:

| Project | 用途 | 作るタイミング |
|---------|------|-------------|
| `lecsy-dev` | 開発・ベータ | 今すぐ |
| `lecsy-prod` | 本番課金後 | 課金開始直前（5月末） |

### 3.3 APIキーは2種類発行

**キー① `dev-local`（ローカルスモークテスト用）**
- Scope: `usage:write` のみ
- Expiration: Never
- 保存場所: 1Password
- 用途: Phase 4の疎通確認が終わったら破棄

**キー② `admin-for-edge`（Edge Function専用）**
- Scope: `keys:write` + `usage:read` + `billing:read`
- Expiration: Never
- 保存場所: **Supabaseシークレットのみ**（バイナリに絶対に入れない）
- 用途: 短寿命トークン発行、残高確認

### 3.4 控えておく値

```
DEEPGRAM_PROJECT_ID = <Project詳細ページで確認>
DEEPGRAM_ADMIN_KEY  = <キー②発行時の1回だけ表示>
```

### 3.5 残高確認（CLI）

```bash
curl -H "Authorization: Token YOUR_ADMIN_KEY" \
  https://api.deepgram.com/v1/projects/YOUR_PROJECT_ID/balances
```

`amount: 200.00` を確認。

---

## 4. Supabase側の構築

### 4.1 シークレット登録

```bash
cd /path/to/lecsy/supabase

supabase secrets set DEEPGRAM_ADMIN_KEY="..."
supabase secrets set DEEPGRAM_PROJECT_ID="..."
supabase secrets list  # 確認
```

### 4.2 使用量追跡テーブル

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_realtime_usage.sql

create table public.user_daily_realtime_usage (
  user_id       uuid references auth.users(id) on delete cascade,
  usage_date    date not null default current_date,
  minutes_today numeric(10,2) not null default 0,
  primary key (user_id, usage_date)
);

alter table public.user_daily_realtime_usage enable row level security;

create policy "users read own usage"
  on public.user_daily_realtime_usage
  for select using (auth.uid() = user_id);

create policy "service writes usage"
  on public.user_daily_realtime_usage
  for all using (auth.jwt() ->> 'role' = 'service_role');

create index on public.user_daily_realtime_usage (usage_date);
```

### 4.3 Feature Flagテーブル

```sql
create table public.feature_flags (
  name       text primary key,
  enabled    boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags (name, enabled)
values ('realtime_captions_beta', true);

alter table public.feature_flags enable row level security;

create policy "everyone reads flags"
  on public.feature_flags for select using (true);
```

マイグレーション適用:
```bash
supabase db push
```

### 4.4 Edge Function: `deepgram-token`

```bash
supabase functions new deepgram-token
```

`supabase/functions/deepgram-token/index.ts`:

```typescript
import { createClient } from 'jsr:@supabase/supabase-js@2';

const DEEPGRAM_ADMIN_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY')!;
const DEEPGRAM_PROJECT_ID = Deno.env.get('DEEPGRAM_PROJECT_ID')!;

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type',
      },
    });
  }

  // 1. ユーザー認証
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return Response.json({ error: 'unauthorized' }, { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return Response.json({ error: 'unauthorized' }, { status: 401 });
  }

  // 2. Feature flag確認
  const { data: flag } = await supabase
    .from('feature_flags')
    .select('enabled')
    .eq('name', 'realtime_captions_beta')
    .single();
  if (!flag?.enabled) {
    return Response.json({ error: 'feature_disabled' }, { status: 503 });
  }

  // 3. Deepgram残高チェック
  const balRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/balances`,
    { headers: { Authorization: `Token ${DEEPGRAM_ADMIN_KEY}` } }
  );
  const balJson = await balRes.json();
  const balance = balJson.balances?.[0]?.amount ?? 0;
  if (balance < 100) {
    return Response.json({ error: 'budget_exceeded', balance }, { status: 402 });
  }

  // 4. ユーザー日次上限チェック（2時間/日）
  const { data: usageRow } = await supabase
    .from('user_daily_realtime_usage')
    .select('minutes_today')
    .eq('user_id', user.id)
    .eq('usage_date', new Date().toISOString().split('T')[0])
    .maybeSingle();
  if ((usageRow?.minutes_today ?? 0) > 120) {
    return Response.json({ error: 'daily_cap' }, { status: 429 });
  }

  // 5. 短寿命トークン発行
  const tokenRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/keys`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${DEEPGRAM_ADMIN_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        comment: `user:${user.id}`,
        scopes: ['usage:write'],
        time_to_live_in_seconds: 900, // 15分
      }),
    }
  );
  if (!tokenRes.ok) {
    return Response.json({ error: 'token_mint_failed' }, { status: 500 });
  }
  const { key } = await tokenRes.json();

  return Response.json(
    { token: key },
    {
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    }
  );
});
```

デプロイ:
```bash
supabase functions deploy deepgram-token
```

### 4.5 Edge Function: `deepgram-balance-check`（運用監視用）

```bash
supabase functions new deepgram-balance-check
```

```typescript
import { createClient } from 'jsr:@supabase/supabase-js@2';

const DEEPGRAM_ADMIN_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY')!;
const DEEPGRAM_PROJECT_ID = Deno.env.get('DEEPGRAM_PROJECT_ID')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const ADMIN_EMAIL = 'nittonotakumi@gmail.com';

Deno.serve(async () => {
  const balRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/balances`,
    { headers: { Authorization: `Token ${DEEPGRAM_ADMIN_KEY}` } }
  );
  const balJson = await balRes.json();
  const balance = balJson.balances?.[0]?.amount ?? 0;

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  if (balance < 100) {
    // 機能を自動停止
    await supabase
      .from('feature_flags')
      .update({ enabled: false, updated_at: new Date().toISOString() })
      .eq('name', 'realtime_captions_beta');
    await sendAlert('critical', balance);
  } else if (balance < 150) {
    await sendAlert('warning', balance);
  }

  return Response.json({ balance });
});

async function sendAlert(level: 'warning' | 'critical', balance: number) {
  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'lecsy@notifications.example.com',
      to: ADMIN_EMAIL,
      subject: `[lecsy][${level.toUpperCase()}] Deepgram balance: $${balance.toFixed(2)}`,
      text: `Deepgram残高が$${balance.toFixed(2)}になりました。${
        level === 'critical' ? 'realtime_captions_beta フラグを自動停止しました。' : ''
      }`,
    }),
  });
}
```

デプロイ + cron登録:
```bash
supabase functions deploy deepgram-balance-check

# Supabase Dashboard → Database → Cron で以下を実行
```

```sql
select cron.schedule(
  'deepgram-balance-check',
  '0 0 * * *',
  $$
    select net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/deepgram-balance-check',
      headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
    );
  $$
);
```

---

## 5. iOS Xcodeプロジェクト準備

### 5.1 Starscream追加

1. Xcode → File → Add Package Dependencies
2. URL: `https://github.com/daltoniam/Starscream`
3. Dependency Rule: Up to Next Major Version / 4.0.8+
4. Add to Target: lecsy メインターゲット

### 5.2 Info.plist

```xml
<key>NSMicrophoneUsageDescription</key>
<string>講義を録音してリアルタイム字幕を生成するためマイクへのアクセスが必要です。</string>

<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>

<key>DEEPGRAM_TOKEN_ENDPOINT</key>
<string>$(DEEPGRAM_TOKEN_ENDPOINT)</string>
```

### 5.3 Capabilities

Target → Signing & Capabilities → + Capability → **Background Modes** → **Audio, AirPlay, and Picture in Picture** にチェック。

### 5.4 xcconfig

`Debug.xcconfig` と `Release.xcconfig`:
```
DEEPGRAM_TOKEN_ENDPOINT = https://$(SUPABASE_PROJECT_REF).supabase.co/functions/v1/deepgram-token
```

**APIキーは絶対にxcconfigに入れない。エンドポイントURLだけ。**

---

## 6. WebSocketパラメータ仕様

### 使用するURL

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
| `language` | `en` | ESL講義は英語。多言語混在が必要なら `multi` に切替（コスト1.2倍） |
| `encoding` | `linear16` | AVAudioEngineから素直に出せる。PCM 16bit |
| `sample_rate` | `16000` | STT精度は16kHzで十分。48kHzより帯域1/3 |
| `channels` | `1` | mono。音声講義用途で2ch不要 |
| `interim_results` | `true` | 発話中に暫定字幕を表示（UX最重要） |
| `smart_format` | `true` | "three dollars" → "$3" など |
| `punctuate` | `true` | 句読点・大文字化 |
| `diarize` | `false` | MVPでは話者分離オフ。Phase C（11月）で検討 |
| `endpointing` | `300` | 300ms無音で文確定 |
| `utterance_end_ms` | `1000` | 1秒無音で UtteranceEnd 発火 |
| `vad_events` | `true` | SpeechStarted イベント受信 |
| `filler_words` | `false` | "um" "uh" を落とす |

### 受信メッセージの型

```json
// 1. Results（一番多い）
{
  "type": "Results",
  "is_final": true,
  "speech_final": true,
  "start": 0.0,
  "duration": 0.5,
  "channel": {
    "alternatives": [{
      "transcript": "hello world",
      "confidence": 0.95,
      "words": [{
        "word": "hello",
        "start": 0.0,
        "end": 0.3,
        "confidence": 0.98,
        "speaker": 0
      }]
    }]
  }
}

// 2. SpeechStarted
{ "type": "SpeechStarted", "timestamp": 1.23 }

// 3. UtteranceEnd
{ "type": "UtteranceEnd", "last_word_end": 3.45 }

// 4. Metadata
{ "type": "Metadata", "request_id": "uuid", "duration": 10.5 }
```

### 送信メッセージ

```json
// KeepAlive（5-10秒間隔）
{ "type": "KeepAlive" }

// CloseStream（終了時）
{ "type": "CloseStream" }
```

音声データは**バイナリフレーム**で送る（JSON不要）。

---

## 7. Swift実装コード

### 7.1 メッセージ型

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

### 7.2 トークンプロバイダ

```swift
// Services/DeepgramTokenProvider.swift
import Foundation

protocol DeepgramTokenProviding {
    func fetchShortLivedToken() async throws -> String
}

enum TokenError: LocalizedError {
    case networkFailure
    case unauthorized
    case budgetExceeded
    case dailyCapExceeded
    case featureDisabled
    case server(Int)
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:     return "ネットワークに接続できません"
        case .unauthorized:       return "ログインが必要です"
        case .budgetExceeded:     return "今月のリアルタイム字幕ご利用上限に達しました"
        case .dailyCapExceeded:   return "本日のリアルタイム字幕ご利用上限に達しました（2時間）"
        case .featureDisabled:    return "リアルタイム字幕は現在メンテナンス中です"
        case .server(let code):   return "サーバーエラー (\(code))"
        }
    }
}

final class EdgeFunctionTokenProvider: DeepgramTokenProviding {
    private let endpoint: URL
    private let session: URLSession
    private let accessTokenProvider: () async throws -> String
    
    init(endpoint: URL,
         session: URLSession = .shared,
         accessTokenProvider: @escaping () async throws -> String) {
        self.endpoint = endpoint
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }
    
    func fetchShortLivedToken() async throws -> String {
        let accessToken = try await accessTokenProvider()
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw TokenError.networkFailure
        }
        switch http.statusCode {
        case 200:
            struct Ok: Decodable { let token: String }
            return try JSONDecoder().decode(Ok.self, from: data).token
        case 401:  throw TokenError.unauthorized
        case 402:  throw TokenError.budgetExceeded
        case 429:  throw TokenError.dailyCapExceeded
        case 503:  throw TokenError.featureDisabled
        default:   throw TokenError.server(http.statusCode)
        }
    }
}
```

### 7.3 本体サービス

```swift
// Services/DeepgramLiveService.swift
import Foundation
import AVFoundation
import Combine
import Starscream

@MainActor
final class DeepgramLiveService: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var segments: [LiveCaptionSegment] = []
    @Published private(set) var interimText: String = ""
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: Error?
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed
    }
    
    // MARK: - Private
    
    private let audioEngine = AVAudioEngine()
    private var socket: WebSocket?
    private var keepAliveTimer: Timer?
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 3
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
    
    // MARK: - Public
    
    func start() async throws {
        guard connectionState == .disconnected else { return }
        connectionState = .connecting
        
        let token: String
        do {
            token = try await tokenProvider.fetchShortLivedToken()
        } catch {
            connectionState = .failed
            lastError = error
            throw error
        }
        
        try await connectSocket(token: token)
        try startAudioEngine()
        startKeepAlive()
    }
    
    func stop() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
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
            .init(name: "model",            value: "nova-3"),
            .init(name: "language",         value: "en"),
            .init(name: "encoding",         value: "linear16"),
            .init(name: "sample_rate",      value: "16000"),
            .init(name: "channels",         value: "1"),
            .init(name: "interim_results",  value: "true"),
            .init(name: "smart_format",     value: "true"),
            .init(name: "punctuate",        value: "true"),
            .init(name: "diarize",          value: "false"),
            .init(name: "endpointing",      value: "300"),
            .init(name: "utterance_end_ms", value: "1000"),
            .init(name: "vad_events",       value: "true"),
            .init(name: "filler_words",     value: "false"),
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
        
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "DeepgramLiveService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "failed to build output format"])
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "DeepgramLiveService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "failed to build converter"])
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }
            guard let converted = Self.convert(buffer: buffer, using: converter, to: outputFormat) else { return }
            if let data = Self.pcmBufferToData(converted) {
                self.socket?.write(data: data)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private static func convert(buffer: AVAudioPCMBuffer,
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
    
    private static func pcmBufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        let channels = buffer.audioBufferList.pointee.mBuffers
        guard let mData = channels.mData else { return nil }
        return Data(bytes: mData, count: Int(channels.mDataByteSize))
    }
    
    // MARK: - Keep-Alive
    
    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
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
                interimText = ""
            } else {
                interimText = alt.transcript
            }
        case .metadata, .speechStarted, .utteranceEnd:
            break
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
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await self?.start()
        }
    }
}

// MARK: - WebSocketDelegate

extension DeepgramLiveService: WebSocketDelegate {
    nonisolated func didReceive(event: WebSocketEvent, client: WebSocket) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch event {
            case .connected:
                self.connectionState = .connected
                self.reconnectAttempt = 0
            case .text(let text):
                guard let data = text.data(using: .utf8) else { return }
                do {
                    let msg = try self.decoder.decode(DeepgramMessage.self, from: data)
                    self.handle(message: msg)
                } catch {
                    self.lastError = error
                }
            case .disconnected(let reason, let code):
                self.lastError = NSError(
                    domain: "DeepgramLiveService", code: Int(code),
                    userInfo: [NSLocalizedDescriptionKey: "socket closed: \(reason)"])
                self.attemptReconnect()
            case .error(let err):
                self.lastError = err
                self.attemptReconnect()
            case .cancelled:
                self.connectionState = .disconnected
            default:
                break
            }
        }
    }
}
```

### 7.4 SwiftUI ビュー

```swift
// Views/LiveCaptionView.swift
import SwiftUI

struct LiveCaptionView: View {
    @StateObject private var service: DeepgramLiveService
    @State private var showBetaDialog = false
    
    init(service: DeepgramLiveService) {
        _service = StateObject(wrappedValue: service)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(service.segments) { segment in
                        Text(segment.text)
                            .font(.system(size: 18))
                            .foregroundStyle(.primary)
                    }
                    if !service.interimText.isEmpty {
                        Text(service.interimText)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            statusBar
        }
        .padding()
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
        .task {
            do { try await service.start() } catch { /* ハンドリング */ }
        }
        .onDisappear { service.stop() }
    }
    
    private var header: some View {
        HStack {
            Text("Live Captions")
                .font(.headline)
            BetaBadge()
            Spacer()
        }
    }
    
    private var statusBar: some View {
        HStack {
            connectionIndicator
            Spacer()
            if let err = service.lastError {
                Text(err.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
    
    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color(for: service.connectionState))
                .frame(width: 8, height: 8)
            Text(label(for: service.connectionState))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func color(for state: DeepgramLiveService.ConnectionState) -> Color {
        switch state {
        case .connected:      return .green
        case .connecting:     return .yellow
        case .reconnecting:   return .orange
        case .failed:         return .red
        case .disconnected:   return .gray
        }
    }
    
    private func label(for state: DeepgramLiveService.ConnectionState) -> String {
        switch state {
        case .connected:               return "Connected"
        case .connecting:              return "Connecting..."
        case .reconnecting(let n):     return "Reconnecting (\(n))"
        case .failed:                  return "Failed"
        case .disconnected:            return "Disconnected"
        }
    }
    
    private func openFeedbackForm() {
        // TODO: Feedback画面へ遷移
    }
}

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

---

## 8. WhisperKitフォールバック

**方針:** MVP（6/1公開）では**シームレス切替は見送り**、`ネットワーク無し → エラー表示してWhisperKitへ手動切替`で許容する。完全自動切替はPhase B（7月）で実装。

理由: 状態遷移が複雑（6-8パターン）で、短期で品質担保が難しい。BETAラベルを明示しているので「ネット必須」と伝える前提でOK。

### MVP版の切替ロジック（シンプル）

```swift
@MainActor
final class TranscriptionCoordinator: ObservableObject {
    enum Mode: Equatable {
        case deepgram
        case whisperKit
    }
    
    @Published private(set) var mode: Mode = .deepgram
    
    private let network: NetworkMonitor        // 既存
    private let deepgram: DeepgramLiveService
    private let whisperKit: WhisperKitLiveService  // 既存
    
    func start() async throws {
        if !network.isOnline || UserDefaults.standard.bool(forKey: "ferpa_strict_mode") {
            mode = .whisperKit
            try await whisperKit.start()
            return
        }
        mode = .deepgram
        do {
            try await deepgram.start()
        } catch {
            // Deepgram失敗時はWhisperKitへ
            mode = .whisperKit
            try await whisperKit.start()
        }
    }
}
```

### Phase B（7月）で追加する動的切替
- 録音中のネットワーク切断検知
- バッファの欠損なし切替
- UIの字幕エンジン識別（または非識別）
- 再接続時にDeepgramへ戻す判断

---

## 9. BETAラベル UX

3箇所で明示する:

1. **In-app**: リアルタイム字幕ボタン横に `BETA` バッジ（黄色）
2. **初回起動時ダイアログ**: 上記コード参照。「実験機能」「不安定な場合あり」「6/1まで無料」
3. **App Store リリースノート**:
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

## 10. コスト監視と安全弁

### 残高
- フリークレジット $200 = Nova-3 Monolingual で **約433時間分**
- $0.0077/分 = $0.46/時間

### 安全弁
1. **Edge Function残高チェック**: $100以下で402を返す → クライアントはWhisperKitへ
2. **日次上限**: 1ユーザー2時間/日、429で拒否
3. **Cron監視**: 毎日UTC00:00に残高チェック、$150で警告メール、$100で機能自動停止
4. **Feature Flag**: `realtime_captions_beta = false` で即座に全停止

### 使用量の加算
セッション終了時にMetadataメッセージの `duration` を `user_daily_realtime_usage.minutes_today` に加算（実装はクライアント→Edge Function POST推奨）。

---

## 11. エラーハンドリングマトリクス

| 発生シーン | エラー | UX | 対応 |
|----------|-------|-----|------|
| 起動時: Edge Function 401 | unauthorized | 「ログインが必要です」 | ログイン画面へ |
| 起動時: Edge Function 402 | budgetExceeded | 「今月の上限に達しました」 | WhisperKitへ切替 |
| 起動時: Edge Function 429 | dailyCapExceeded | 「本日2時間の上限に達しました」 | WhisperKitへ切替 |
| 起動時: Edge Function 503 | featureDisabled | 「メンテナンス中」 | WhisperKitへ切替 |
| 起動時: WebSocketタイムアウト | socket timeout | 「接続できません」 | 2s/4s/8sで3回再接続 → WhisperKit |
| 録音中: 401再発 | token expired | 無音表示 | トークン再取得 → 再接続 |
| 録音中: 1011 | サーバーエラー | 無音表示 | 即再接続 |
| 録音中: 1008 | 形式不一致 | 無音表示 | 再接続しない。ログ収集してバグ修正 |
| 録音中: 10秒無音切断 | idle disconnect | 無音表示 | KeepAliveで予防、切れたら再接続 |
| 録音中: ネットワーク喪失 | network lost | トースト「オフラインに切替」 | WhisperKitへ自動切替 |
| JSON decode失敗 | parse error | （ユーザーには見せない） | そのメッセージだけ無視 |

---

## 12. テスト戦略

### 単体テスト

```swift
// Tests/DeepgramMessageTests.swift
import XCTest
@testable import lecsy

final class DeepgramMessageTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    func test_decode_results_final() throws {
        let json = """
        {
          "type": "Results",
          "channel_index": [0],
          "duration": 0.5,
          "start": 0.0,
          "is_final": true,
          "speech_final": true,
          "channel": {
            "alternatives": [{
              "transcript": "hello world",
              "confidence": 0.95,
              "words": []
            }]
          }
        }
        """.data(using: .utf8)!
        let msg = try decoder.decode(DeepgramMessage.self, from: json)
        if case .results(let r) = msg {
            XCTAssertTrue(r.isFinal)
            XCTAssertEqual(r.channel.alternatives.first?.transcript, "hello world")
        } else {
            XCTFail("expected .results")
        }
    }
    
    func test_decode_speech_started() throws {
        let json = #"{"type":"SpeechStarted","timestamp":1.23}"#.data(using: .utf8)!
        let msg = try decoder.decode(DeepgramMessage.self, from: json)
        if case .speechStarted(let s) = msg {
            XCTAssertEqual(s.timestamp, 1.23)
        } else {
            XCTFail("expected .speechStarted")
        }
    }
    
    func test_decode_unknown_type_throws() {
        let json = #"{"type":"Unknown"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(DeepgramMessage.self, from: json))
    }
}
```

### 実機テスト（α段階）

| シナリオ | 期待動作 | 合格基準 |
|---------|---------|---------|
| 5分連続録音 | 字幕が順次表示 | 切断なし、最後まで字幕取得 |
| 10分連続録音 | 切断なし | 接続維持、WER <12% |
| 30分沈黙後に発話 | KeepAliveで接続維持 | 字幕出る |
| 画面ロック中録音 | 継続 | バックグラウンドで字幕取得 |
| 着信→切断→復帰 | 録音一時停止→再開 | 再接続成功 |
| 機内モードON | エラー表示 | WhisperKitへ切替（MVP段階は手動） |
| 教室Wi-Fi（低帯域） | 遅延あるが動く | p95 <1000ms |

### 品質ゲート（β全公開前）

- [ ] 10時間連続録音でクラッシュ0
- [ ] 切断後の自動再接続成功率 >95%
- [ ] 英語講義サンプル10本でWER <12%
- [ ] レイテンシ p50 <400ms, p95 <800ms
- [ ] バッテリー消費 <20%/時間（iPhone 15 Pro、Wi-Fi、画面標準輝度）

---

## 13. よくあるハマりどころ

1. **AVAudioSession.Category を `.record` にするとBluetooth出力が死ぬ**  
   → `.playAndRecord` + `.allowBluetooth` が正解

2. **inputNode.inputFormat のsampleRateは端末依存**  
   → 必ず AVAudioConverter で 16kHz に正規化

3. **Starscreamの `didReceive` はnon-mainスレッド**  
   → `Task { @MainActor in ... }` でUIアクセス保護

4. **KeepAliveを音声データとして送ると切られる**（RFC-6455違反）  
   → 必ず `write(string:)` で制御フレームとして送る

5. **WebSocket切断時に `audioEngine.stop()` を忘れるとマイク握りっぱなし**  
   → 必ず対で呼ぶ

6. **バックグラウンド録音にはInfo.plistに `UIBackgroundModes: audio` 必須**

7. **Deepgramの10秒アイドル切断**  
   → KeepAliveは5-10秒間隔

8. **interim_results の transcript は途中で短くなることがある**（確定前の訂正で）  
   → UIは「最新のinterimで上書き」、確定時のみsegments配列に追加

9. **iOS Simulatorではマイクが動かないことがある**  
   → 実機でテスト。Simulator Menu → I/O → Audio Input も確認

10. **`Token YOUR_KEY` のコピー時に末尾改行が混入**  
    → `.trimmingCharacters(in: .whitespacesAndNewlines)` で防御

---

## 14. セキュリティ

| ❌ やってはいけない | ✅ 正しいやり方 |
|-----------------|--------------|
| APIキーをiOSバイナリに埋め込む | Edge Function経由で短寿命token発行 |
| APIキーをGitHubにコミット | `.gitignore` 徹底、シークレットはSupabaseに |
| 開発キーと本番キーを同じProject | `lecsy-dev` と `lecsy-prod` でProject分離 |
| Scope「All」のキーを使う | 最小権限（`usage:write` のみ等） |
| expiration「Never」のキーを本番運用 | 90日でローテーション |
| 管理者キーを個人PCに置きっぱなし | 1Passwordで管理、都度コピー |

---

## 15. 動作確認チェックリスト

### Deepgram側
- [ ] Projectを `lecsy-dev` にリネーム
- [ ] `dev-local` キー発行、1Password保存
- [ ] `admin-for-edge` キー発行、Supabase Secretsに登録
- [ ] Project ID を `DEEPGRAM_PROJECT_ID` シークレットに登録
- [ ] 残高 $200.00 をAPI経由で確認

### Supabase側
- [ ] `DEEPGRAM_ADMIN_KEY` / `DEEPGRAM_PROJECT_ID` 登録済
- [ ] `user_daily_realtime_usage` テーブル作成
- [ ] `feature_flags` テーブル作成、`realtime_captions_beta = true` 投入
- [ ] `deepgram-token` Edge Function デプロイ
- [ ] `deepgram-balance-check` Edge Function デプロイ
- [ ] cron `0 0 * * *` で balance-check 登録
- [ ] curlで401/200両方確認

### iOS側
- [ ] Starscream SPM追加、`import Starscream` が通る
- [ ] Info.plist: `NSMicrophoneUsageDescription` 追加
- [ ] Info.plist: `UIBackgroundModes: audio` 追加
- [ ] Capabilities: Background Modes > Audio 有効化
- [ ] xcconfig: `DEEPGRAM_TOKEN_ENDPOINT` 追加
- [ ] `DeepgramMessage.swift` 追加 + 単体テスト通過
- [ ] `EdgeFunctionTokenProvider` 実装
- [ ] `DeepgramLiveService` 実装
- [ ] `LiveCaptionView` 実装

### 動作確認
- [ ] スモークテスト: 字幕がコンソールに流れる
- [ ] 5分連続で切断されない
- [ ] Deepgram Usage タブで使用量増加を確認
- [ ] Edge Function経由（非認証で401、認証で200）
- [ ] BETAバッジと初回ダイアログが表示される

---

## 補足: 参考リンク

- Deepgram Pricing: https://deepgram.com/pricing
- Deepgram Live Streaming Docs: https://developers.deepgram.com/docs/live-streaming-audio
- Deepgram WebSocket Protocol: https://developers.deepgram.com/docs/lower-level-websockets
- Deepgram API Reference (listen-streaming): https://developers.deepgram.com/reference/speech-to-text/listen-streaming
- Deepgram iOS Blog Tutorial: https://deepgram.com/learn/ios-live-transcription
- Starscream: https://github.com/daltoniam/Starscream
- Sample iOS App: https://github.com/deepgram-devs/deepgram-live-transcripts-ios

---

*このガイドはlecsyプロジェクト用にキュレート済み。他ファイル参照なしで完結。*
