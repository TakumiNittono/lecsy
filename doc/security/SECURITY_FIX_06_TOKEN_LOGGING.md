# セキュリティ修正 #6: トークン情報のログ出力無効化

**重要度**: 高  
**対象ファイル**: 
- `lecsy/Services/AuthService.swift`
- `lecsy/Services/SyncService.swift`
- `supabase/functions/save-transcript/index.ts`

**推定作業時間**: 15分

---

## 現状の問題

トークン情報がログに出力されており、デバイスログやクラッシュレポートに機密情報が残る可能性があります。

### AuthService.swift (227-228行目)
```swift
print("   - Access Token: \(accessToken.prefix(20))...")
print("   - Refresh Token: \(refreshToken.prefix(20))...")
```

### SyncService.swift (107-108行目)
```swift
print("📤 SyncService: Access Token (first 50 chars): \(accessToken.prefix(50))...")
print("📤 SyncService: Access Token length: \(accessToken.count)")
```

### save-transcript/index.ts (56行目)
```typescript
console.log("JWT token (first 50 chars):", token.substring(0, 50));
```

---

## 修正手順

### Step 1: Swiftプロジェクトにログユーティリティを追加

新規ファイル: `lecsy/Utils/Logger.swift`

```swift
//
//  Logger.swift
//  lecsy
//
//  セキュアなログユーティリティ
//

import Foundation
import os.log

/// アプリケーションログカテゴリ
enum LogCategory: String {
    case auth = "Auth"
    case sync = "Sync"
    case recording = "Recording"
    case general = "General"
}

/// セキュアなログユーティリティ
struct AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lecsy.app"
    
    /// デバッグログ（DEBUGビルドのみ出力）
    static func debug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.debug("🔍 \(message)")
        #endif
    }
    
    /// 情報ログ
    static func info(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.info("ℹ️ \(message)")
        #endif
    }
    
    /// 警告ログ
    static func warning(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.warning("⚠️ \(message)")
    }
    
    /// エラーログ
    static func error(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ \(message)")
    }
    
    /// 機密情報をマスクする
    static func maskSensitive(_ value: String, visibleChars: Int = 4) -> String {
        guard value.count > visibleChars else {
            return String(repeating: "*", count: value.count)
        }
        let visible = value.prefix(visibleChars)
        return "\(visible)***[length:\(value.count)]"
    }
    
    /// トークン情報のログ（DEBUGビルドのみ、マスク付き）
    static func logToken(_ label: String, token: String?, category: LogCategory = .auth) {
        #if DEBUG
        if let token = token {
            debug("\(label): \(maskSensitive(token, visibleChars: 8))", category: category)
        } else {
            debug("\(label): nil", category: category)
        }
        #endif
    }
}
```

---

### Step 2: AuthService.swift の修正

**変更前** (227-228行目):
```swift
print("🔐 AuthService: トークン取得成功")
print("   - Access Token: \(accessToken.prefix(20))...")
print("   - Refresh Token: \(refreshToken.prefix(20))...")
print("   - Expires In: \(expiresIn)")
```

**変更後**:
```swift
AppLogger.info("トークン取得成功", category: .auth)
AppLogger.logToken("Access Token", token: accessToken, category: .auth)
AppLogger.logToken("Refresh Token", token: refreshToken, category: .auth)
AppLogger.debug("Expires In: \(expiresIn)", category: .auth)
```

**その他の変更箇所**:

```swift
// 94行目
// 変更前
print("✅ AuthService: セッション確認成功 - User ID: \(session.user.id)")
// 変更後
AppLogger.info("セッション確認成功 - User ID: \(session.user.id)", category: .auth)

// 107行目
// 変更前  
print("   - Access Token: \(accessToken.prefix(20))...")
// 変更後
AppLogger.logToken("Access Token", token: accessToken, category: .auth)
```

---

### Step 3: SyncService.swift の修正

**変更前** (107-122行目付近):
```swift
print("📤 SyncService: Access Token (first 50 chars): \(accessToken.prefix(50))...")
print("📤 SyncService: Access Token length: \(accessToken.count)")
// ...
print("📤 SyncService: Authorization header: \(authHeader.prefix(50))...")
```

**変更後**:
```swift
AppLogger.logToken("Access Token", token: accessToken, category: .sync)
// ...
AppLogger.debug("Authorization header configured", category: .sync)
```

---

### Step 4: save-transcript/index.ts の修正

**変更前**:
```typescript
// 29-34行目
console.log("Request headers:", Object.fromEntries(req.headers.entries()));

// 34-36行目
console.log("Authorization header:", authHeader ? `${authHeader.substring(0, 50)}...` : "missing");
console.log("Authorization header length:", authHeader ? authHeader.length : 0);

// 56行目
console.log("JWT token (first 50 chars):", token.substring(0, 50));
console.log("JWT token length:", token.length);

// 62-63行目
console.log("Supabase URL:", supabaseUrl);
console.log("Supabase Anon Key (first 20 chars):", supabaseAnonKey ? `${supabaseAnonKey.substring(0, 20)}...` : "missing");
```

**変更後**:
```typescript
// 環境変数でデバッグモードを制御
const DEBUG_MODE = Deno.env.get("DEBUG") === "true";

function debugLog(...args: unknown[]): void {
  if (DEBUG_MODE) {
    console.log("[DEBUG]", ...args);
  }
}

function maskToken(token: string, visibleChars: number = 8): string {
  if (token.length <= visibleChars) {
    return "***";
  }
  return `${token.substring(0, visibleChars)}***[length:${token.length}]`;
}

// 使用例
debugLog("Request received");

// 認証ヘッダーの存在確認のみログ
console.log("Authorization header present:", !!authHeader);

// トークン情報はデバッグモードのみ、マスク付きで出力
debugLog("JWT token:", maskToken(token));

// 環境変数の存在確認のみ
console.log("Supabase URL configured:", !!supabaseUrl);
console.log("Supabase Anon Key configured:", !!supabaseAnonKey);
```

---

## 完全な修正後のコード（save-transcript/index.ts の冒頭部分）

```typescript
// supabase/functions/save-transcript/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 環境変数でデバッグモードを制御
const DEBUG_MODE = Deno.env.get("DEBUG") === "true";

function debugLog(...args: unknown[]): void {
  if (DEBUG_MODE) {
    console.log("[DEBUG]", ...args);
  }
}

function maskToken(token: string, visibleChars: number = 8): string {
  if (token.length <= visibleChars) {
    return "***";
  }
  return `${token.substring(0, visibleChars)}***[length:${token.length}]`;
}

interface SaveTranscriptRequest {
  title: string;
  content: string;
  created_at: string;
  duration?: number;
  language?: string;
  app_version?: string;
}

serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    debugLog("Request received");
    
    // 認証チェック
    const authHeader = req.headers.get("Authorization");
    console.log("Authorization header present:", !!authHeader);
    
    if (!authHeader) {
      console.error("Authorization header is missing");
      return new Response(JSON.stringify({ error: "Unauthorized", code: "NO_AUTH_HEADER" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!authHeader.startsWith("Bearer ")) {
      console.error("Invalid authorization format");
      return new Response(JSON.stringify({ error: "Unauthorized", code: "INVALID_AUTH_FORMAT" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const token = authHeader.substring(7);
    debugLog("JWT token:", maskToken(token));

    // Supabaseクライアント
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    
    console.log("Supabase URL configured:", !!supabaseUrl);
    console.log("Supabase Anon Key configured:", !!supabaseAnonKey);
    
    const supabase = createClient(
      supabaseUrl!,
      supabaseAnonKey!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    console.log("User authenticated:", !!user);
    
    if (authError) {
      console.error("Auth error:", authError.message);
      return new Response(
        JSON.stringify({ 
          error: "Unauthorized", 
          code: "AUTH_ERROR",
          message: "Authentication failed"
        }), 
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // ... 以下は同じ
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : "Unknown error");
    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        code: "INTERNAL_ERROR"
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

---

## 確認チェックリスト

- [ ] `Logger.swift` ユーティリティを作成
- [ ] `AuthService.swift` のログ出力を修正
- [ ] `SyncService.swift` のログ出力を修正
- [ ] `save-transcript/index.ts` のログ出力を修正
- [ ] DEBUGビルドでログが出力されることを確認
- [ ] Releaseビルドで機密ログが出力されないことを確認
- [ ] 本番環境で `DEBUG=true` が設定されていないことを確認

---

## 補足: Xcodeでのビルド設定確認

1. Xcodeでプロジェクトを開く
2. Build Settings > Swift Compiler - Custom Flags
3. `DEBUG` フラグが Debug 設定でのみ定義されていることを確認

```
Other Swift Flags:
  Debug: -DDEBUG
  Release: (空)
```

---

## 関連ドキュメント

- [Apple - Logging](https://developer.apple.com/documentation/os/logging)
- [OWASP - Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
