//
//  TrackGymWidgetsBundle.swift
//  TrackGymWidgets
//
//  Created by Sergio Comerón on 17/8/25.
//

import WidgetKit
import SwiftUI

@main
struct TrackGymWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TrackGymWidgets()
        TrackGymWidgetsControl()
        TrackGymWidgetsLiveActivity()
    }
}
