//
//  LecsyWidget.swift
//  LecsyWidgetExtension
//
//  Created by Takuminittono on 2026/01/27.
//

import WidgetKit
import SwiftUI

struct LecsyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LecsyWidgetEntry {
        LecsyWidgetEntry(date: Date(), lectureCount: 0, lastLectureTitle: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LecsyWidgetEntry) -> ()) {
        let entry = LecsyWidgetEntry(date: Date(), lectureCount: 3, lastLectureTitle: "Introduction to Economics")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = LecsyWidgetEntry(date: Date(), lectureCount: 0, lastLectureTitle: nil)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct LecsyWidgetEntry: TimelineEntry {
    let date: Date
    let lectureCount: Int
    let lastLectureTitle: String?
}

struct LecsyWidgetEntryView: View {
    var entry: LecsyWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                Text("Lecsy")
                    .font(.headline.weight(.bold))
            }

            Spacer()

            if let title = entry.lastLectureTitle {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Tap to start recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "lecsy://record"))
    }
}

struct LecsyWidget: Widget {
    let kind: String = "LecsyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LecsyWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                LecsyWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LecsyWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Lecsy")
        .description("Quick access to lecture recording.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    LecsyWidget()
} timeline: {
    LecsyWidgetEntry(date: .now, lectureCount: 3, lastLectureTitle: "Introduction to Economics")
    LecsyWidgetEntry(date: .now, lectureCount: 0, lastLectureTitle: nil)
}
