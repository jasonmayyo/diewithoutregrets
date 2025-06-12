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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: isSelected ?
                                    [Color(hex: 0x3FA4AE), Color(hex: 0x2BC391)] :
                                    [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: type.systemImageName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color(hex: 0x184449))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(Color(hex: 0x184449))
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: 0x2BC391))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(
                        color: isSelected ?
                            Color(hex: 0x2BC391).opacity(0.2) :
                            Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ?
                            Color(hex: 0x2BC391).opacity(0.3) :
                            Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
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
        .background(Color(hex: 0xF8F9FA))
    }
} 
