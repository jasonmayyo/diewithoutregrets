//
//  SGTabBar.swift
//  diewithoutregrets
//
//  Floating pill dock replacing the system tab bar chrome. Overlaid via
//  safeAreaInset so the TabView (and its per-tab navigation state) stays
//  intact underneath. Icon-only — no labels — a clear liquid-glass capsule
//  (frosted-material fallback pre-iOS 26) with a soft bubble behind the
//  selected tab. `onDark` flips the dock to its night look for the
//  locked-home scene: smoked glass, white icons.
//

import SwiftUI

struct SGTabItem: Identifiable {
    let id: Int
    let title: String          // accessibility label only
    let icon: String           // SF Symbol name
    var asset: String? = nil   // asset-catalog image overrides `icon`
}

struct SGTabBar: View {
    @Binding var selection: Int
    let items: [SGTabItem]
    /// Night-scene rendering (the locked home): smoked glass, white icons.
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .sgGlassBackground(in: Capsule(style: .continuous), onDark: onDark)
        .sgShadow(SGTheme.shadowFloat)
        // Match the width of the home-screen cards/pills.
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.25), value: onDark)
    }

    private func tabButton(_ item: SGTabItem) -> some View {
        let selected = selection == item.id
        return Button {
            selection = item.id
        } label: {
            Group {
                if let asset = item.asset {
                    // Matches the 24pt SF-symbol tabs so both read the same
                    // optical size.
                    Image(asset)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .semibold))
                }
            }
            .foregroundColor(iconColor(selected: selected))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? bubbleColor : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
        .accessibilityLabel(item.title)
        .animation(SGTheme.springFast, value: selection)
    }

    /// Mint accent on the daylight canvases; plain white on the night scene
    /// (mint against the red-alert world would fight the story).
    private func iconColor(selected: Bool) -> Color {
        if onDark {
            return selected ? SGTheme.nightText : SGTheme.nightTextTertiary
        }
        return selected ? SGTheme.mint : SGTheme.paperTertiary
    }

    private var bubbleColor: Color {
        onDark ? SGTheme.nightRaised : SGTheme.mint.opacity(0.14)
    }
}
