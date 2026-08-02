//
//  MonsterLiveActivity.swift
//  MonsterWidgetExtension
//
//  The always-on monster mascot Live Activity. Shows only the mascot in the
//  Dynamic Island (no timer, no text). The image is swapped by the app via
//  MonsterActivityManager, which cycles through the five mascot frames.
//
//  Why still images and not Lottie: the Dynamic Island is rendered by
//  WidgetKit, which draws static snapshots and cannot run an animation loop.
//  The sense of life comes from the app pushing a new frame via
//  Activity.update().
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MonsterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MonsterLiveActivityAttributes.self) { context in
            // Lock screen / banner presentation: the full mascot.
            VStack {
                monsterImage(context.state.imageName, height: 96)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .activityBackgroundTint(Color(red: 0x1B / 255, green: 0x0E / 255, blue: 0x0A / 255)) // SGTheme.night
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press) presentation
                DynamicIslandExpandedRegion(.center) {
                    monsterImage(context.state.imageName, height: 64)
                        .padding(.vertical, 4)
                }
            } compactLeading: {
                monsterCompact(context.state.imageName)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                monsterCompact(context.state.imageName)
            }
            .keylineTint(Color.white)
        }
    }

    /// Renders the mascot with a gentle cross-fade whenever the frame changes.
    /// The `.id` forces SwiftUI to treat each frame as new content so the
    /// system animates the transition on Live Activity updates.
    @ViewBuilder
    private func monsterImage(_ name: String, height: CGFloat) -> some View {
        Image(name)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .id(name)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    /// Head-and-face crop for the tiny compact / minimal presentations. The
    /// compact region is only ~30pt tall and rendered through a dimming
    /// "vibrant" material, so scaling the full body down reads as a blob.
    /// Instead the full image fills a small frame top-aligned and clipped, so
    /// only the (recognizable) head and face show at the tiny size.
    @ViewBuilder
    private func monsterCompact(_ name: String) -> some View {
        Image(name)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 30, alignment: .top)
            .clipped()
            .id(name)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }
}

// MARK: - Previews

extension MonsterLiveActivityAttributes {
    fileprivate static var preview: MonsterLiveActivityAttributes {
        MonsterLiveActivityAttributes()
    }
}

extension MonsterLiveActivityAttributes.ContentState {
    fileprivate static var happy: MonsterLiveActivityAttributes.ContentState {
        MonsterLiveActivityAttributes.ContentState(imageName: "1")
    }
    fileprivate static var clipboard: MonsterLiveActivityAttributes.ContentState {
        MonsterLiveActivityAttributes.ContentState(imageName: "5")
    }
}

#Preview("Monster Lock Screen", as: .content, using: MonsterLiveActivityAttributes.preview) {
    MonsterLiveActivity()
} contentStates: {
    MonsterLiveActivityAttributes.ContentState.happy
    MonsterLiveActivityAttributes.ContentState.clipboard
}

#Preview("Monster Compact", as: .dynamicIsland(.compact), using: MonsterLiveActivityAttributes.preview) {
    MonsterLiveActivity()
} contentStates: {
    MonsterLiveActivityAttributes.ContentState.happy
}

#Preview("Monster Expanded", as: .dynamicIsland(.expanded), using: MonsterLiveActivityAttributes.preview) {
    MonsterLiveActivity()
} contentStates: {
    MonsterLiveActivityAttributes.ContentState.happy
}
