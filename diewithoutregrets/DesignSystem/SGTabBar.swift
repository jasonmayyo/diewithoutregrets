//
//  SGTabBar.swift
//  diewithoutregrets
//
//  Floating pill dock replacing the system tab bar chrome. Overlaid via
//  safeAreaInset so the TabView (and its per-tab navigation state) stays
//  intact underneath. Icon-only — no labels — with a soft mint bubble
//  behind the selected tab.
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

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(SGTheme.ink)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        )
        // Match the width of the home-screen cards/pills.
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.bottom, 4)
    }

    private func tabButton(_ item: SGTabItem) -> some View {
        let selected = selection == item.id
        return Button {
            selection = item.id
        } label: {
            Group {
                if let asset = item.asset {
                    Image(asset)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .semibold))
                }
            }
            .foregroundColor(selected ? SGTheme.mint : SGTheme.paperTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? SGTheme.mint.opacity(0.14) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .animation(SGTheme.springFast, value: selection)
    }
}
