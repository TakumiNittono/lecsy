# タイトル同期機能の実装ガイド

## 現状の問題

- iOSアプリでタイトルを変更しても、Web側のタイトルは更新されない
- Webアプリでタイトルを変更しても、iOSアプリに反映されない

## 解決策

### 1. iOSアプリ → Web: タイトル更新機能を追加

iOSアプリでタイトルを変更した場合、既にWebに保存済みの講義のタイトルも更新する。

### 2. Web → iOS: タイトル取得機能を追加

iOSアプリが起動時または手動で、Web側の最新タイトルを取得する。

---

## 実装手順

### Step 1: Edge Functionにタイトル更新エンドポイントを追加

既存の `/api/transcripts/[id]/title` エンドポイントを使用可能。

### Step 2: SyncServiceにタイトル更新メソッドを追加

```swift
func updateTitleOnWeb(lecture: Lecture, newTitle: String) async throws {
    guard let webId = lecture.webTranscriptId else {
        throw SyncError.notSavedToWeb
    }
    
    // Web APIを呼び出してタイトルを更新
    // PATCH /api/transcripts/{id}/title
}
```

### Step 3: LectureDetailViewでタイトル変更時にWebも更新

```swift
.onChange(of: title) { oldValue, newValue in
    var updatedLecture = lecture
    updatedLecture.title = newValue
    store.updateLecture(updatedLecture)
    lecture = updatedLecture
    
    // Webに保存済みの場合は、Web側も更新
    if lecture.savedToWeb {
        Task {
            try? await syncService.updateTitleOnWeb(lecture: lecture, newTitle: newTitle)
        }
    }
}
```

---

## 実装ファイル

1. `lecsy/Services/SyncService.swift` - タイトル更新メソッドを追加
2. `lecsy/Views/Library/LectureDetailView.swift` - タイトル変更時の処理を追加
