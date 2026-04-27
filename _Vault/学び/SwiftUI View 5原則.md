# SwiftUI View 5原則 — 肥大化を防ぐ

> 出典: [[NotebookLM_学習/⑥ iOS Swift]] / Paul Hudson, Sean Allen

## 原則

複雑な UI を持つ lecsy（録音 / 音声認識 / レクチャー詳細）では
**Massive View（肥大化した View）**を防ぐことが最優先。

## 5原則

### 1. 独立したパーツをプロパティに切り出す
```swift
// ❌ Bad
var body: some View {
    VStack {
        HStack { /* toolbar 20行 */ }
        List { /* list 50行 */ }
        HStack { /* footer 15行 */ }
    }
}

// ✅ Good
var body: some View {
    VStack { toolbar; list; footer }
}
private var toolbar: some View { /* ... */ }
private var list: some View { /* ... */ }
private var footer: some View { /* ... */ }
```

### 2. View を小さなサブビューに分割
- `@ViewBuilder` を多用するのではなく
- **再利用可能な小さな struct として View を切り出す**
- コンポジション（構成）によって UI を構築

### 3. アクションコードを body から排除
```swift
// ❌ Bad
Button("Save") {
    // 20行のロジック
}

// ✅ Good
Button("Save", action: save)

private func save() { /* 20行 */ }
```

### 4. スタイルと View 拡張を活用
共通のテキストスタイルやボタンデザインは、
**`ButtonStyle` プロトコルや View の `extension`** にまとめる。

```swift
struct PrimaryButtonStyle: ButtonStyle { /* ... */ }
extension View { func cardStyle() -> some View { /* ... */ } }
```

### 5. View を「受動的」に保ち、ロジックは View Model へ
- **View**: データの表示 + ユーザー入力の受け付けのみ
- **View Model**: データの加工 + 表示条件の判定（MVVM）

## lecsy での適用候補

- `LectureDetailView.swift` — body が長い → サブビュー分割
- `SummaryService.swift` — ロジックを View から分離
- 録音ボタン → 独立した `RecordButton` struct + `RecordButtonStyle`

## 関連

- [[Swift async await 使い所と落とし穴]]
- [[SwiftUI 状態管理の使い分け]]
