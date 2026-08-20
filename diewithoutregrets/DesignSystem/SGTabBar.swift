//
//  SGTabBar.swift
//  diewithoutregrets
//
//  Full-width anchored dock replacing the system tab bar chrome. Overlaid
//  via safeAreaInset so the TabView (and its per-tab navigation state)
//  stays intact underneath. A slab with rounded top corners runs
//  edge-to-edge into the home-indicator area; each tab is a sticker icon
//  over a small label, with a lighter rounded card behind the selected
//  tab. Unselected stickers sit desaturated and slightly shrunk.
//
//  Three scene styles:
//  - .meadow — the Guard home only: a green gradient sampled from the
//    bottom of the meadow-grass art so the slab reads as part of the hill.
//  - .light — every white canvas (Study/Blocks/Profile): off-white slab,
//    ink labels, mint selection.
//  - .night — the locked home: dark slab, white labels.
//

import SwiftUI

enum SGTabBarStyle {
    case meadow
    case light
    case night
}

struct SGTabItem: Identifiable {
    let id: Int
    let title: String          // label under the sticker
    let icon: String           // asset-catalog sticker image
}

struct SGTabBar: View {
    @Binding var selection: Int
    let items: [SGTabItem]
    var style: SGTabBarStyle = .light

    // Bottom-of-the-grass-art greens (sampled: #3A9144 → #2F7E37) so the
    // meadow slab continues the hill instead of fighting it.
    private static let meadowTop = Color(hex: 0x3A9144)
    private static let meadowBottom = Color(hex: 0x2F7E37)

    var body: some View {
        // Fixed-width tabs clustered at the center (not stretched across
        // the slab) so the group reads at a standard tab-bar density.
        HStack(spacing: 10) {
            ForEach(items) { item in
                SGTabButton(item: item,
                            selected: selection == item.id,
                            style: style) {
                    selection = item.id
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28,
                                   topTrailingRadius: 28,
                                   style: .continuous)
                .fill(slabStyle)
                .overlay(alignment: .top) {
                    // Soft rim along the crest of the slab.
                    UnevenRoundedRectangle(topLeadingRadius: 28,
                                           topTrailingRadius: 28,
                                           style: .continuous)
                        .strokeBorder(rimColor, lineWidth: 1)
                }
                .shadow(color: .black.opacity(style == .light ? 0.08 : 0.18),
                        radius: 14, y: -4)
                // The slab owns the home-indicator area too.
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.easeInOut(duration: 0.25), value: style)
    }

    private var slabStyle: AnyShapeStyle {
        switch style {
        case .meadow:
            return AnyShapeStyle(LinearGradient(colors: [Self.meadowTop, Self.meadowBottom],
                                                startPoint: .top, endPoint: .bottom))
        case .light:
            return AnyShapeStyle(Color(hex: 0xFAFAF8))
        case .night:
            return AnyShapeStyle(SGTheme.night)
        }
    }

    private var rimColor: Color {
        switch style {
        case .meadow: return .white.opacity(0.14)
        case .light: return .black.opacity(0.05)
        case .night: return .white.opacity(0.08)
        }
    }
}

/// One sticker tab: icon over label, highlight card when selected.
private struct SGTabButton: View {
    let item: SGTabItem
    let selected: Bool
    let style: SGTabBarStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(item.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    // Idle stickers go monochrome so the selected one
                    // carries the only color in the dock.
                    .saturation(selected ? 1 : 0)
                    .opacity(selected ? 1 : idleIconOpacity)
                    .scaleEffect(selected ? 1.0 : 0.92)
                Text(item.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? selectedLabel : idleLabel)
            }
            .frame(width: 76)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? highlightColor : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGStickerPressStyle())
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(SGTheme.springFast, value: selected)
    }

    private var selectedLabel: Color {
        switch style {
        case .meadow, .night: return .white
        case .light: return SGTheme.mintDeep
        }
    }

    private var idleLabel: Color {
        switch style {
        case .meadow, .night: return .white.opacity(0.6)
        case .light: return SGTheme.paperTertiary
        }
    }

    private var idleIconOpacity: Double {
        style == .light ? 0.65 : 0.8
    }

    private var highlightColor: Color {
        switch style {
        case .meadow: return .white.opacity(0.18)
        case .light: return SGTheme.mint.opacity(0.13)
        case .night: return .white.opacity(0.1)
        }
    }
}

/// Deeper shrink than SGPressStyle (stickers want a chunkier squash than
/// text buttons) with the same spring and press tick.
private struct SGStickerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(SGTheme.springFast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { SGTheme.tick() }
            }
    }
}
