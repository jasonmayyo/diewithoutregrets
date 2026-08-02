//
//  MonsterLiveActivityAttributes.swift
//  MonsterWidgetExtension
//
//  IMPORTANT: This struct is duplicated in
//  diewithoutregrets/MonsterLiveActivityAttributes.swift because the widget
//  extension is a separate target with no shared framework.
//  Any changes here MUST be mirrored in the app copy.
//

import ActivityKit
import Foundation

struct MonsterLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Name of the mascot imageset to show ("1"..."5"). The asset lives in
        /// this widget bundle.
        var imageName: String

        init(imageName: String) {
            self.imageName = imageName
        }
    }
}
