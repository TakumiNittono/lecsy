# Swift async/await 使い所と落とし穴

> 出典: [[NotebookLM_学習/⑥ iOS Swift]] / Paul Hudson, Sean Allen, Apple Developer

## 使い所

### 1. ネットワーク通信
従来のクロージャ（Completion Handler）方式を排除:

```swift
// ❌ Bad
func fetchLectures(completion: @escaping (Result<[Lecture], Error>) -> Void) { }

// ✅ Good
func fetchLectures() async throws -> [Lecture] {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Lecture].self, from: data)
}
```

コードが**上から下へ流れるように**記述でき（構造化された並行処理）、可読性が激増。

### 2. View のライフタイム管理
`.task` Modifier を使用:

```swift
List(lectures) { /* ... */ }
    .task {
        lectures = try? await service.fetchLectures()
    }
```

View が表示された時に非同期処理を開始し、**消えた時に自動でキャンセル**。

## 落とし穴と対策

### 1. メインスレッドの更新
非同期処理後の UI 更新は**必ずメインスレッド**で。

```swift
// ❌ Bad: 手動で DispatchQueue.main.async

// ✅ Good: View Model 全体を @MainActor でマーク
@MainActor
class LectureViewModel: ObservableObject {
    @Published var lectures: [Lecture] = []
    func load() async {
        lectures = (try? await service.fetchLectures()) ?? []
    }
}
```

### 2. エラーハンドリングの強制
- completion 方式 = エラーを返し忘れるリスクあり
- `async throws` = **エラーを投げるか値を返すか**が言語レベルで強制
- → クラッシュや「反応なし」を防げる

### 3. OS バージョンの制約
- async/await の本格活用には **iOS 15+** が必要
- 古い OS をサポートする場合、コードが二重化

## lecsy でのリファクタ対象

- `SummaryService.swift` — Supabase 通信を async/await に
- `DeepgramWebSocketClient` — 既に async 対応? 確認
- 全 ViewModel を `@MainActor` マーク
- `DispatchQueue.main.async` を全排除

## 関連

- [[SwiftUI View 5原則]]
- [[SwiftUI 状態管理の使い分け]]
