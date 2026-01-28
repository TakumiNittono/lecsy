//
//  LecsyWidgetAttributes.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation
import ActivityKit

/// Live Activities用の属性定義
struct LecsyWidgetAttributes: ActivityAttributes {
    /// 動的に更新されるコンテンツ状態
    public struct ContentState: Codable, Hashable {
        /// 録音経過時間（秒）
        var recordingDuration: TimeInterval
        /// 録音中かどうか
        var isRecording: Bool
    }
    
    /// 静的な属性（講義タイトルなど）
    var lectureTitle: String
}

// MARK: - Preview Extensions
extension LecsyWidgetAttributes {
    static var preview: LecsyWidgetAttributes {
        LecsyWidgetAttributes(lectureTitle: "経済学入門 第1回")
    }
}

extension LecsyWidgetAttributes.ContentState {
    static var preview: LecsyWidgetAttributes.ContentState {
        LecsyWidgetAttributes.ContentState(
            recordingDuration: 3661.0, // 1時間1分1秒
            isRecording: true
        )
    }
}
