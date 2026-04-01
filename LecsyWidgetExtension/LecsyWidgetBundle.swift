//
//  LecsyWidgetBundle.swift
//  LecsyWidget
//
//  Created on 2026/01/27.
//

import WidgetKit
import SwiftUI

@main
struct LecsyWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activityのみを登録（通常のWidgetは不要）
        LecsyWidgetLiveActivity()
    }
}
