# バックグラウンド録音設定ガイド

## ⚠️ ロック画面で録音が動作しない場合

ロック画面時に音声が取れない場合は、以下の設定を確認してください。

---

## 📝 Info.plistの設定（必須）

Xcodeのプロジェクト設定で、以下の設定を追加してください：

### 1. UIBackgroundModes の設定

1. **Xcodeでプロジェクトを開く**
2. **プロジェクトナビゲーターでプロジェクトを選択**
3. **Target「lecsy」を選択**
4. **「Signing & Capabilities」タブを開く**
5. **「+ Capability」ボタンをクリック**
6. **「Background Modes」を追加**
7. **「Audio, AirPlay, and Picture in Picture」にチェックを入れる**

または、Infoタブで直接設定：

1. **「Info」タブを開く**
2. **「Custom iOS Target Properties」セクションで「+」ボタンをクリック**
3. **キー名**: `UIBackgroundModes`
4. **タイプ**: `Array`
5. **値**: `audio` を追加

### 2. NSMicrophoneUsageDescription の設定

1. **「Info」タブで「+」ボタンをクリック**
2. **キー名**: `NSMicrophoneUsageDescription`（または「Privacy - Microphone Usage Description」）
3. **タイプ**: `String`
4. **値**: `講義の音声を録音して文字起こしするためにマイクへのアクセスが必要です。`

### 3. NSSupportsLiveActivities の設定（既に設定済みの可能性あり）

1. **「Info」タブで「+」ボタンをクリック**
2. **キー名**: `NSSupportsLiveActivities`
3. **タイプ**: `Boolean`
4. **値**: `YES`

---

## 🔧 コード側の設定確認

### RecordingService.swift の設定

以下の設定が正しく行われているか確認してください：

1. **AVAudioSession カテゴリ**: `.playAndRecord`
2. **オプション**: `.defaultToSpeaker`, `.allowBluetooth`
3. **バックグラウンドタスク**: `UIApplication.beginBackgroundTask()`
4. **タイマー**: `RunLoop.current.add(timer, forMode: .common)` でバックグラウンドでも動作

---

## ✅ 動作確認方法

### 1. 録音開始後の確認

1. アプリで録音を開始
2. ホームボタンを押す（または画面をスワイプアップ）
3. ロック画面にする
4. 数秒待つ
5. アプリに戻る
6. 録音が継続しているか確認

### 2. ログで確認

Xcodeのコンソールで以下のログを確認：

```
🔴 オーディオセッション設定成功（バックグラウンド録音有効）
🔴 バックグラウンドタスクを更新しました
```

### 3. Live Activityで確認

ロック画面にLive Activityが表示され、時間が更新され続けていれば、録音は動作しています。

---

## 🐛 トラブルシューティング

### 問題1: ロック画面で録音が停止する

**原因**: `UIBackgroundModes`に`audio`が設定されていない

**解決方法**:
1. Xcodeで「Signing & Capabilities」タブを開く
2. 「Background Modes」を追加
3. 「Audio, AirPlay, and Picture in Picture」にチェック

### 問題2: 録音は継続するが音声が取れない

**原因**: AVAudioSessionの設定が不適切

**解決方法**:
1. `.playAndRecord`カテゴリが設定されているか確認
2. `.allowBluetoothA2DP`オプションを削除（録音には不要）
3. `setActive(true, options: [])`でアクティブ化

### 問題3: バックグラウンドタスクが期限切れになる

**原因**: バックグラウンドタスクの更新が不十分

**解決方法**:
- 現在の実装では30秒ごとに自動更新されるようになっています
- それでも問題がある場合は、更新間隔を短くする

---

## 📚 参考資料

- [Apple Developer: Background Modes](https://developer.apple.com/documentation/backgroundtasks)
- [Apple Developer: AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Apple Developer: Recording Audio](https://developer.apple.com/documentation/avfaudio/avaudiorecorder)

---

**最終更新**: 2026年1月27日
