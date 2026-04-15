# Deepgram セットアップ手順書

作成日: 2026-04-13
関連: [[Deepgramリアルタイム字幕実装]] / [[iOSアプリ設計]] / [[ローンチ戦略_6月1日無料開放]]

---

## この文書の目的

Deepgram を lecsy に統合するための**環境構築とアカウント準備**の手順書。コード実装は [[Deepgramリアルタイム字幕実装]] に分離。この文書は「**何をインストール・設定すれば、コードを書き始められるか**」に特化。

所要時間: 通しで **60-90分**（初回、待機時間除く）。

---

## 0. 全体フロー（俯瞰）

```
┌─ Phase 1: Deepgramアカウント ────┐   15分
│  1.1 サインアップ                │
│  1.2 Project作成                 │
│  1.3 APIキー発行                 │
│  1.4 残高確認（$200確認）         │
└──────────────────────────────────┘
            ↓
┌─ Phase 2: Supabase側の準備 ─────┐    20分
│  2.1 シークレット登録             │
│  2.2 Edge Function作成            │
│  2.3 デプロイ                    │
│  2.4 curlで疎通確認              │
└──────────────────────────────────┘
            ↓
┌─ Phase 3: iOS Xcode側の準備 ─────┐   20分
│  3.1 Starscream SPM追加           │
│  3.2 Info.plist編集              │
│  3.3 Background Mode有効化        │
│  3.4 xcconfig更新                 │
└──────────────────────────────────┘
            ↓
┌─ Phase 4: 動作確認 ──────────────┐   15分
│  4.1 最小サンプルで字幕を出す     │
│  4.2 残高消費が記録されるか確認   │
│  4.3 Edge Function経由に切替     │
└──────────────────────────────────┘
```

---

## Phase 1: Deepgramアカウント作成

### 1.1 サインアップ

**URL**: https://console.deepgram.com/signup

**必要情報:**
- メールアドレス（lecsy開発用アドレス推奨。後から共同開発者を追加する時のため**個人メールは避ける**）
- パスワード
- 名前（請求書/領収書に載る）
- **クレジットカード不要**

**選ぶプラン**: **Pay As You Go** を選択。
- Free/Starter/Growth 等の表記がUIで出るが、初期は Pay As You Go 一択
- $200 フリークレジットが自動付与される

### 1.2 Project作成

Deepgram では「アカウント」の下に複数の「Project」を持てる。Project単位でAPIキー・残高・使用量が分離される。

**推奨構成:**

| Project名 | 用途 | APIキーのスコープ |
|-----------|------|----------------|
| `lecsy-dev` | 開発・テスト | `usage:write`（音声送信）+ `keys:write`（短寿命トークン発行用） |
| `lecsy-prod` | 本番 | `usage:write` のみ。Edge Function側で管理者キーを別途保持 |

**作成手順:**
1. Dashboard → **Projects** → **Create a New Project**
2. 名前: `lecsy-dev`
3. Create

本番プロジェクトは5月末、課金開始直前に作成する（フリークレジットを開発で使い切ってから本番へ）。

### 1.3 APIキー発行

**2種類のキーを作る:**

#### キー① 開発用（直接叩く）

- Project `lecsy-dev` → **API Keys** → **Create a New API Key**
- 名前: `dev-local`
- Scope: `usage:write` のみチェック（最小権限原則）
- **Expiration**: `Never` でOK（開発用）
- 発行されたキーを **1Passwordなど安全な場所に保存**。Dashboardで再表示不可。

#### キー② 管理者キー（Edge Functionから短寿命トークン発行用）

- Project `lecsy-dev` → **API Keys** → **Create a New API Key**
- 名前: `admin-for-edge`
- Scope: `keys:write` + `usage:read` + `billing:read` にチェック
- **Expiration**: `Never`
- 保存。このキーは**Supabaseシークレットにのみ**入れる。iOSバイナリには絶対に入れない。

### 1.4 残高確認

Dashboard上部に「$200.00 credit」と表示されていること。
または API で確認:

```bash
curl -H "Authorization: Token YOUR_ADMIN_KEY" \
  https://api.deepgram.com/v1/projects
```

`projects[0].id` を控える（Edge Functionで使う）。

```bash
curl -H "Authorization: Token YOUR_ADMIN_KEY" \
  https://api.deepgram.com/v1/projects/PROJECT_ID/balances
```

`amount: 200.00` が確認できればOK。

---

## Phase 2: Supabase側の準備

### 2.1 シークレット登録

```bash
cd /path/to/lecsy/supabase

# 管理者キー（Edge Function専用）
supabase secrets set DEEPGRAM_ADMIN_KEY="YOUR_ADMIN_KEY"

# Project ID
supabase secrets set DEEPGRAM_PROJECT_ID="YOUR_PROJECT_ID"

# 確認
supabase secrets list
```

**絶対にしてはいけないこと:**
- `.env.local` や GitHub に管理者キーをコミット
- iOS の xcconfig に管理者キーを入れる
- Slack・メールでキーを共有（都度 `supabase secrets set` で再発行）

### 2.2 Edge Function の scaffolding

```bash
supabase functions new deepgram-token
```

生成される `supabase/functions/deepgram-token/index.ts` を以下で置き換え:

```typescript
import { createClient } from 'jsr:@supabase/supabase-js@2';

const DEEPGRAM_ADMIN_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY')!;
const DEEPGRAM_PROJECT_ID = Deno.env.get('DEEPGRAM_PROJECT_ID')!;

Deno.serve(async (req) => {
  // 1. ユーザー認証
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response('Unauthorized', { status: 401 });
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });
  
  // 2. 残高チェック
  const balanceRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/balances`,
    { headers: { Authorization: `Token ${DEEPGRAM_ADMIN_KEY}` } }
  );
  const balanceJson = await balanceRes.json();
  const balance = balanceJson.balances?.[0]?.amount ?? 0;
  if (balance < 100) {
    return Response.json({ error: 'budget_exceeded' }, { status: 402 });
  }
  
  // 3. ユーザー日次上限チェック（2時間/日）
  const { data: usageRow } = await supabase
    .from('user_daily_realtime_usage')
    .select('minutes_today')
    .eq('user_id', user.id)
    .maybeSingle();
  if ((usageRow?.minutes_today ?? 0) > 120) {
    return Response.json({ error: 'daily_cap' }, { status: 429 });
  }
  
  // 4. 短寿命トークン発行
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
  
  return Response.json({ token: key });
});
```

### 2.3 使用量追跡テーブル

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_user_daily_realtime_usage.sql

create table public.user_daily_realtime_usage (
  user_id      uuid references auth.users(id) on delete cascade,
  usage_date   date not null default current_date,
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

マイグレーション適用:

```bash
supabase db push
```

### 2.4 Edge Function デプロイ

```bash
supabase functions deploy deepgram-token
```

**疎通確認:**

```bash
# 未認証（401が返るはず）
curl -i https://YOUR_PROJECT_REF.supabase.co/functions/v1/deepgram-token

# 認証あり（200 + token が返るはず）
curl -i \
  -H "Authorization: Bearer YOUR_USER_ACCESS_TOKEN" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/deepgram-token
```

---

## Phase 3: iOS Xcode側の準備

### 3.1 Starscream をSwift Package Manager で追加

1. Xcode → プロジェクト選択 → **Package Dependencies** タブ
2. **+** ボタン → 検索バーに以下を貼り付け:
   ```
   https://github.com/daltoniam/Starscream
   ```
3. **Dependency Rule**: `Up to Next Major Version` / `4.0.8` 以降
4. Add Package
5. lecsy のメインターゲットに `Starscream` をリンク

**確認**: `import Starscream` がエラーなく通ること。

### 3.2 Info.plist の編集

以下3項目を追加（既にあれば上書き）:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>講義を録音してリアルタイム字幕を生成するためマイクへのアクセスが必要です。</string>

<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>

<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
</dict>
```

**補足:**
- `NSMicrophoneUsageDescription` が無いとApp Store審査で即リジェクト
- `UIBackgroundModes: audio` が無いと画面ロック中に字幕が止まる
- NSAppTransportSecurity は `wss://api.deepgram.com` がHTTPSなので `false` でOK

### 3.3 Background Mode のCapability有効化

1. プロジェクト選択 → ターゲット → **Signing & Capabilities** タブ
2. **+ Capability** → **Background Modes**
3. **Audio, AirPlay, and Picture in Picture** にチェック

**確認**: `.entitlements` ファイルに `audio` が入っていること。

### 3.4 xcconfig 更新

`Debug.xcconfig` と `Release.xcconfig` に追加:

```
// Debug.xcconfig
DEEPGRAM_TOKEN_ENDPOINT = https://$(SUPABASE_PROJECT_REF).supabase.co/functions/v1/deepgram-token

// Release.xcconfig
DEEPGRAM_TOKEN_ENDPOINT = https://$(SUPABASE_PROJECT_REF).supabase.co/functions/v1/deepgram-token
```

`Info.plist` に参照を追加:

```xml
<key>DEEPGRAM_TOKEN_ENDPOINT</key>
<string>$(DEEPGRAM_TOKEN_ENDPOINT)</string>
```

Swiftから読む:

```swift
extension Bundle {
    var deepgramTokenEndpoint: URL {
        URL(string: object(forInfoDictionaryKey: "DEEPGRAM_TOKEN_ENDPOINT") as! String)!
    }
}
```

**注意**: APIキー本体は**絶対にxcconfigに入れない**。エンドポイントURLだけ。

---

## Phase 4: 動作確認

### 4.1 最小サンプルで字幕を出す（開発用キー直叩き）

**目的**: Deepgram接続の疎通確認。Edge Function経由は次ステップ。

`DeepgramSmokeTest.swift` を新規作成:

```swift
import AVFoundation
import Starscream

final class DeepgramSmokeTest: NSObject, WebSocketDelegate {
    private let apiKey = "YOUR_DEV_LOCAL_KEY" // ★ 後で削除すること
    private let audioEngine = AVAudioEngine()
    private var socket: WebSocket?
    
    func start() {
        let url = URL(string: "wss://api.deepgram.com/v1/listen?model=nova-3&language=en&encoding=linear16&sample_rate=16000&channels=1&interim_results=true&punctuate=true&smart_format=true")!
        var req = URLRequest(url: url)
        req.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        let socket = WebSocket(request: req)
        socket.delegate = self
        socket.connect()
        self.socket = socket
        startAudio()
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        if case .text(let text) = event {
            print("[Deepgram] \(text)")
        }
    }
    
    private func startAudio() {
        let input = audioEngine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        let out = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
        let conv = AVAudioConverter(from: inputFormat, to: out)!
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buf, _ in
            guard let self else { return }
            let cap = AVAudioFrameCount(Double(buf.frameLength) * out.sampleRate / inputFormat.sampleRate) + 1
            let outBuf = AVAudioPCMBuffer(pcmFormat: out, frameCapacity: cap)!
            var err: NSError?
            var fed = false
            conv.convert(to: outBuf, error: &err) { _, s in
                if fed { s.pointee = .noDataNow; return nil }
                fed = true; s.pointee = .haveData; return buf
            }
            let bl = outBuf.audioBufferList.pointee.mBuffers
            self.socket?.write(data: Data(bytes: bl.mData!, count: Int(bl.mDataByteSize)))
        }
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetooth, .defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)
        audioEngine.prepare()
        try? audioEngine.start()
    }
}
```

アプリ起動直後にマイク許可ダイアログを承認 → `DeepgramSmokeTest().start()` → コンソールに `"transcript": "hello..."` が流れれば成功。

**チェック項目:**
- [ ] `.connected` イベントが来る
- [ ] `is_final: false` の interim メッセージが来る
- [ ] `is_final: true` の final メッセージが来る
- [ ] テキストが実際に喋った内容と一致する
- [ ] 5分間連続で切断されない

### 4.2 残高消費が記録されるか確認

スモークテストを5分走らせる → Deepgram Dashboard → **Usage** タブ → 直近の使用量に5分程度が加算されているか確認。

**コスト**: 5分 × $0.0077/分 = **$0.0385** 消費。$200から $199.96に減る程度。

### 4.3 Edge Function経由に切り替え

`DeepgramSmokeTest` の `apiKey` を削除し、[[Deepgramリアルタイム字幕実装]] §4.2 の `EdgeFunctionTokenProvider` 経由に差し替える。

**確認項目:**
- [ ] 未ログイン状態でエラーになる（401）
- [ ] ログイン済みで token が返る
- [ ] 返された token で WebSocket 接続できる
- [ ] 15分後に token が expire する（再取得が必要）

---

## Phase 5: 運用準備（β公開前）

### 5.1 残高監視の cron 設定

Supabase Dashboard → **Database** → **Cron** で以下を設定:

```sql
select cron.schedule(
  'deepgram-balance-check',
  '0 0 * * *', -- 毎日UTC 00:00
  $$
    select net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/deepgram-balance-check',
      headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
    );
  $$
);
```

`deepgram-balance-check` Edge Function は別途作成（[[Deepgramリアルタイム字幕実装]] §7.1）。

### 5.2 アラート通知の設定

残高 $150割れ・$100割れで Slack or メール通知。
とりあえずは自分のメール（`nittonotakumi@gmail.com`）に Resend 経由で送るのが最速。

```typescript
await resend.emails.send({
  from: 'lecsy@notifications.example.com',
  to: 'nittonotakumi@gmail.com',
  subject: `[lecsy] Deepgram balance: $${balance}`,
  text: `Deepgram残高が$${balance}になりました。...`
});
```

### 5.3 Feature Flag

```sql
create table public.feature_flags (
  name    text primary key,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags (name, enabled)
values ('realtime_captions_beta', true);
```

iOS起動時にこのフラグを取得し、`false` ならリアルタイム字幕ボタンを非表示。残高切れ時の緊急停止手段。

---

## 6. チェックリスト（通しで確認）

### Deepgram側
- [ ] `lecsy-dev` Project 作成済
- [ ] `dev-local` キー発行、1Password保存
- [ ] `admin-for-edge` キー発行、Supabaseシークレット登録
- [ ] Project ID を控えた
- [ ] 残高 $200.00 を確認

### Supabase側
- [ ] `DEEPGRAM_ADMIN_KEY` シークレット登録
- [ ] `DEEPGRAM_PROJECT_ID` シークレット登録
- [ ] `user_daily_realtime_usage` テーブル作成
- [ ] `feature_flags` テーブル作成
- [ ] `deepgram-token` Edge Function デプロイ
- [ ] curlで401/200の両方を確認

### Xcode側
- [ ] Starscream SPM追加
- [ ] Info.plist: `NSMicrophoneUsageDescription` 追加
- [ ] Info.plist: `UIBackgroundModes: audio` 追加
- [ ] Signing & Capabilities: Background Modes > Audio 有効化
- [ ] xcconfig: `DEEPGRAM_TOKEN_ENDPOINT` 追加

### 動作確認
- [ ] スモークテストで字幕が出た
- [ ] 5分連続で切断されない
- [ ] Deepgram Usage タブに使用量が記録された
- [ ] Edge Function経由でtoken取得→接続できた
- [ ] 未ログイン時に401が返る

---

## 7. トラブルシューティング

### 接続直後に1006で切断される
- **原因1**: `Authorization` ヘッダの形式ミス。`Token xxx` の前に半角スペース必須
- **原因2**: `encoding` と実際の音声形式が不一致。linear16指定なのに別形式を送っている
- **原因3**: `sample_rate` と実際の音声が不一致

### 接続はできるが何も返ってこない
- **原因1**: 音声データを送っていない（`installTap` が呼ばれていない）
- **原因2**: 音声データが無音（マイク許可が下りていない、iOSシミュレータでマイクが無い）
- **原因3**: KeepAliveが来ない＋10秒無音でサーバー側から切られる

### 10秒後に勝手に切れる
- **原因**: KeepAliveメッセージを送っていない
- **対処**: 5-10秒おきに `{"type":"KeepAlive"}` を `write(string:)` で送る

### interim は来るが final が来ない
- **原因**: `endpointing` が小さすぎる、または発話の終わりに無音が足りない
- **対処**: `endpointing=300` に設定、話し終わった後300ms以上黙る

### iOS Simulatorでマイクが動かない
- Simulator は**ホストMacのマイクを使う**。Mac側のマイク許可を確認
- 最新Xcodeでは Menu → **I/O → Audio Input → Internal Microphone** を選択

### `Token YOUR_KEY` と送っても 401
- キーがコピー時に欠けていないか（末尾の改行が入る事故多い）
- キーが revoke されていないか Dashboard で確認
- キーの Scope に `usage:write` が入っているか

---

## 8. セキュリティ注意点

| ❌ やってはいけない | ✅ 正しいやり方 |
|-----------------|--------------|
| APIキーをiOSバイナリに埋め込む | Edge Function経由で短寿命token発行 |
| APIキーをGitHubにコミット | `.env.local` を `.gitignore` に追加、シークレットはSupabaseに |
| 開発用キーと本番用キーを同じにする | `lecsy-dev` と `lecsy-prod` でProject分離 |
| Scope「All」のキーを使う | 最小権限（`usage:write` のみ等） |
| expiration「Never」のキーを本番で使う | 90日expirationでローテーション |
| 管理者キーを個人PCに置きっぱなし | 1Passwordで管理、使う時だけコピー |

---

## 9. コスト早見表

フリークレジット $200 で何ができるか:

| 使い方 | 消費ペース |
|-------|---------|
| 毎日1時間テスト | $0.46/日 × 49日 = $22.54 → 残 $177 |
| 毎日3時間テスト | $1.38/日 × 49日 = $67.62 → 残 $132 |
| 5人ベータ × 週3回 × 90分 | 67.5時間/週 = $31/週 × 7週 = $217 → **クレジット尽きる** |
| 50人ベータ × 週1回 × 90分 | 75時間/週 = $34.65/週 × 7週 = $242 → **クレジット尽きる** |

→ **ベータ全公開は慎重に**。公開直前に残高 $150 くらい残っていれば安全。開発自分だけなら超余裕。

---

## 10. 次のアクション

1. この文書通りに Phase 1-4 を実行（60-90分）
2. スモークテストで字幕が出たら [[Deepgramリアルタイム字幕実装]] §4.2 の本番クラスに移行
3. β限定公開前に Phase 5 の運用準備を完了

---

*次回更新: 実際にセットアップした時の詰まりどころを §7 に追記*
