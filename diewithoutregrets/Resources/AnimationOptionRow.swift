//
//  AnimationOptionRow.swift
//  diewithoutregrets
//
//  Created by Assistant on 2025/01/14.
//

import SwiftUI

struct AnimationOptionRow: View {
    let type: AnimationType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon/Preview area
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? SGTheme.mint.opacity(0.12) : SGTheme.inkHigh)
                        .frame(width: 60, height: 60)

                    Image(systemName: type.systemImageName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? SGTheme.mint : SGTheme.paperSecondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)

                    Text(type.description)
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(SGTheme.mint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(SGTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? SGTheme.mint : SGTheme.hairline,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .animation(SGTheme.springFast, value: isSelected)
        }
        .buttonStyle(SGPressStyle())
    }
}

struct AnimationOptionRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            AnimationOptionRow(
                type: .lockAnimation,
                isSelected: true,
                onSelect: {}
            )
            
            AnimationOptionRow(
                type: .memeVideo,
                isSelected: false,
                onSelect: {}
            )
        }
        .padding()
        .background(SGTheme.ink)
    }
} 
