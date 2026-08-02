//
//  MonsterWidgetBundle.swift
//  MonsterWidgetExtension
//

import WidgetKit
import SwiftUI

@main
struct MonsterWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Always-on monster mascot in the Dynamic Island
        MonsterLiveActivity()
    }
}
