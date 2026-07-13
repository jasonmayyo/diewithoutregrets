//
//  SGComponents.swift
//  diewithoutregrets
//
//  Reusable Meadow building blocks. Every interactive element gets
//  press-scale + a light haptic; surfaces pair a hairline with a soft shadow.
//

import SwiftUI

// MARK: - Button styles

/// Press-scale + haptic, shared by all SG buttons.
struct SGPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(SGTheme.springFast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { SGTheme.tapHaptic() }
            }
    }
}

/// Primary action: mint capsule, white label.
struct SGPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = SGTheme.mint
    var labelColor: Color = .white
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(labelColor)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(tint, in: Capsule(style: .continuous))
        }
        .buttonStyle(SGPressStyle())
    }
}

/// Secondary action: transparent, hairline capsule, paper label.
struct SGGhostButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(SGTheme.paper)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Capsule(style: .continuous)
                    .fill(SGTheme.glaze(0.06))
                    .overlay(Capsule(style: .continuous).strokeBorder(SGTheme.hairline, lineWidth: 1))
            )
        }
        .buttonStyle(SGPressStyle())
    }
}

// MARK: - Surfaces

/// The standard card: raised surface + hairline + soft ambient shadow.
struct SGCard<Content: View>: View {
    var padding: CGFloat = SGTheme.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: SGTheme.cardShadow, radius: 12, y: 4)
            )
    }
}

/// Uppercase tracked micro-label ("STUDY GUARD ON").
struct SGMicroLabel: View {
    let text: String
    var color: Color = SGTheme.paperSecondary

    var body: some View {
        Text(text.uppercased())
            .font(SGTheme.micro)
            .tracking(1.5)
            .foregroundColor(color)
    }
}

/// Settings/list row: title + optional subtitle + chevron, on an ink card.
struct SGListRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconTint: Color = SGTheme.mint
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconTint)
                        .frame(width: 34, height: 34)
                        .background(iconTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                    if let subtitle {
                        Text(subtitle)
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)
                    }
                }
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SGTheme.mint)
                }
            }
            .padding(SGTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SGPressStyle())
    }
}

/// Small pill chip (e.g. "12 apps", "15 min").
struct SGChip: View {
    let text: String
    var icon: String? = nil
    var tint: Color = SGTheme.paper
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(tint)
            .padding(.vertical, 11)
            .padding(.horizontal, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(SGTheme.glaze(0.06))
                    .overlay(Capsule(style: .continuous).strokeBorder(SGTheme.hairline, lineWidth: 1))
            )
        }
        .buttonStyle(SGPressStyle())
    }
}

/// Screen header used by the main tabs: eyebrow micro-label over a big
/// rounded display title, with room for one trailing action.
struct SGScreenHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    init(eyebrow: String, title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                SGMicroLabel(text: eyebrow)
                Text(title)
                    .font(SGTheme.display(34))
                    .foregroundColor(SGTheme.paper)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

/// Meadow picker row: leading check circle + title on a raised tile with a
/// mint border when selected. The one row shape for every option-list sheet.
struct SGPickerRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selected ? SGTheme.mint.opacity(0.15) : SGTheme.glaze(0.06))
                        .frame(width: 30, height: 30)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(SGTheme.mintDeep)
                    }
                }

                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Spacer()
            }
            .padding(.horizontal, SGTheme.cardPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(selected ? SGTheme.mint.opacity(0.5) : SGTheme.hairline,
                                          lineWidth: selected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(SGTheme.springFast, value: selected)
    }
}

/// Selectable option tile (icon over label) — segmented choices like the
/// unlock method picker.
struct SGOptionTile: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selected ? SGTheme.mint : SGTheme.paperSecondary)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SGTheme.paper)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(selected ? SGTheme.mint.opacity(0.12) : SGTheme.inkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .strokeBorder(selected ? SGTheme.mint : SGTheme.hairline,
                                  lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(SGTheme.springFast, value: selected)
    }
}

// MARK: - Sheet chrome

/// Uniform Meadow sheet chrome: continuous rounded corners, no system
/// grabber. Every sheet applies this to its own root so all entry points
/// look identical.
extension View {
    func sgSheetChrome() -> some View {
        presentationCornerRadius(SGTheme.sheetRadius)
            .presentationDragIndicator(.hidden)
    }
}

/// Sheet header: rounded display title, optional caption underneath, and an
/// optional round close button — replaces navigation-bar chrome in sheets.
struct SGSheetHeader: View {
    let title: String
    var subtitle: String? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SGTheme.display(24))
                    .foregroundColor(SGTheme.paper)
                if let subtitle {
                    Text(subtitle)
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if let onClose {
                // 32pt visual circle inside a 44pt tap target (HIG minimum).
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(SGTheme.paperSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(SGTheme.glaze(0.06)))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SGPressStyle())
                .accessibilityLabel("Close")
            }
        }
    }
}

/// Self-sizing sheet scaffold: measures its content and pins the detent to
/// exactly that height, so nothing ever clips at the bottom — content taller
/// than the screen scrolls instead of cutting off.
///
/// Pass `estimatedHeight` close to the sheet's real content height: it's the
/// detent used for the first frame, before measurement lands, so a good
/// estimate keeps the present animation jump-free.
struct SGFittedSheet<Content: View>: View {
    var estimatedHeight: CGFloat = 480
    @State private var measuredHeight: CGFloat?
    @State private var bottomInset: CGFloat = 0
    @ViewBuilder var content: Content

    private var contentHeight: CGFloat { measuredHeight ?? estimatedHeight }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newValue in
                    measuredHeight = newValue
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.bottom
        } action: { newValue in
            bottomInset = newValue
        }
        .background(SGTheme.ink)
        .presentationDetents([.height(contentHeight + bottomInset)])
        .sgSheetChrome()
    }
}
