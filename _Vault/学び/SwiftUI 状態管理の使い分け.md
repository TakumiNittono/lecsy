# SwiftUI 状態管理の使い分け

> 出典: [[NotebookLM_学習/⑥ iOS Swift]] / Paul Hudson, Sean Allen

## プロパティラッパー選択基準

| ラッパー | 使い所 | 所有者 | 例 |
|---|---|---|---|
| `@State` | そのView所有のシンプル・プライベート状態 | View 自身 | `@State private var isEditing = false` |
| `@StateObject` | **View Model の初期化（所有）** | View 自身 | `@StateObject var vm = LectureViewModel()` |
| `@ObservedObject` | **親から渡された View Model の参照** | 親 View | `@ObservedObject var vm: LectureViewModel` |
| `@EnvironmentObject` | アプリ全体/階層で共有データ | App | `@EnvironmentObject var settings: Settings` |
| `@Observable` (iOS 17+) | 新マクロ、必要なプロパティのみ追跡 | View | `@Observable class VM { }` |

## 重要ルール

### @State は必ず private
```swift
@State private var count = 0  // ✅
@State var count = 0           // ❌ 外部から書き換え可能
```

### @StateObject vs @ObservedObject
- **View が View Model を作る**: `@StateObject`
- **親から受け取る**: `@ObservedObject`
- 間違うと View 再描画で View Model が**毎回作り直される**バグ

### @Observable（iOS 17+）の利点
- 従来の `ObservableObject` + `@Published` を置き換え
- **必要なプロパティのみ追跡** → 不必要な再描画を抑制
- パフォーマンス向上

```swift
// iOS 16 以前
class VM: ObservableObject {
    @Published var lectures: [Lecture] = []
}

// iOS 17+
@Observable
class VM {
    var lectures: [Lecture] = []
}
```

## lecsy の判断指針

- **シンプルな UI 状態**（展開/折りたたみ、入力中フラグ等）→ `@State private`
- **画面1つの状態を束ねる VM** → `@StateObject`
- **サブ View に渡す VM** → `@ObservedObject`
- **認証ユーザー、設定、課金状態** → `@EnvironmentObject`
- **iOS 17+ 前提なら全部** `@Observable` に移行検討

## 関連

- [[SwiftUI View 5原則]]
- [[Swift async await 使い所と落とし穴]]
