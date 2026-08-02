//
//  MonsterLiveActivityAttributes.swift
//  diewithoutregrets
//
//  Shared ActivityKit attributes for the always-on monster mascot Live
//  Activity that lives in the Dynamic Island.
//
//  IMPORTANT: This struct is duplicated in
//  MonsterWidget/MonsterLiveActivityAttributes.swift because the widget
//  extension is a separate target with no shared framework.
//  Any changes here MUST be mirrored in the widget copy.
//

import ActivityKit
import Foundation

struct MonsterLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Name of the mascot imageset to show ("1"..."5"). The asset lives in
        /// the widget bundle.
        var imageName: String

        init(imageName: String) {
            self.imageName = imageName
        }
    }
}
