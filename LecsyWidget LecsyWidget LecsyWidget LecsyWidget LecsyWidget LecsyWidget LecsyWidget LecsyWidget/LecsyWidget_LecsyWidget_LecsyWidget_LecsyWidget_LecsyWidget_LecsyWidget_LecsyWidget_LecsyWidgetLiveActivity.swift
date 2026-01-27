//
//  LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetLiveActivity.swift
//  LecsyWidget LecsyWidget LecsyWidget LecsyWidget LecsyWidget LecsyWidget LecsyWidget LecsyWidget
//
//  Created by Takuminittono on 2026/01/27.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes {
    fileprivate static var preview: LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes {
        LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes(name: "World")
    }
}

extension LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState {
    fileprivate static var smiley: LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState {
        LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState {
         LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.preview) {
   LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetLiveActivity()
} contentStates: {
    LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState.smiley
    LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidget_LecsyWidgetAttributes.ContentState.starEyes
}
