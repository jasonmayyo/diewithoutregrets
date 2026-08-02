//
//  SGGallery.swift
//  diewithoutregrets
//
//  DEBUG-only component gallery: the single visual reference for every
//  design-system token and component (Secure's ComponentGalleryView
//  pattern). If a control isn't in here, it isn't canonical.
//

#if DEBUG
import SwiftUI

struct SGGalleryView: View {
    @State private var fieldText = ""
    @State private var progress: Double = 0.4
    @State private var pickerSelection = 1
    @State private var optionSelection = 0
    @State private var riseShown = false

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.sectionSpacing) {
                    section("Buttons (SGButton)") {
                        SGButton(title: "Study to unlock", icon: "rectangle.stack.fill") {}
                        SGButton(title: "Unlock my apps", variant: .ember) {}
                        VStack(spacing: 10) {
                            SGButton(title: "I'm ready", variant: .white) {}
                            SGButton(title: "Study to unlock", icon: "rectangle.stack.fill", variant: .alarm) {}
                        }
                        .padding(12)
                        .background(SGTheme.night, in: RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
                        SGButton(title: "Not now", variant: .ghost) {}
                        SGButton(title: "Skip for now", variant: .text) {}
                        SGButton(title: "Disabled", enabled: false) {}
                        SGButton(title: "Restoring...", loading: true) {}
                    }

                    section("Haptic grammar") {
                        hapticRow("tick (light)") { SGTheme.tick() }
                        hapticRow("gain (soft)") { SGTheme.gain() }
                        hapticRow("lock (rigid)") { SGTheme.lock() }
                        hapticRow("beat (medium)") { SGTheme.beat() }
                        hapticRow("climax (heavy)") { SGTheme.climax() }
                        hapticRow("lockSlam") { SGTheme.lockSlam() }
                        hapticRow("correctBurst") { SGTheme.correctBurst() }
                        hapticRow("wrongBuzz") { SGTheme.wrongBuzz() }
                        hapticRow("celebrationLanding") { SGTheme.celebrationLanding() }
                    }

                    section("Cards") {
                        SGCard {
                            Text("SGCard (shadowed)")
                                .font(SGTheme.cardTitle)
                                .foregroundColor(SGTheme.paper)
                        }
                        SGCard(shadowed: false) {
                            Text("SGCard flat (rows in lists)")
                                .font(SGTheme.cardTitle)
                                .foregroundColor(SGTheme.paper)
                        }
                        SGCard(shadowed: false, dashed: SGTheme.mint) {
                            Text("SGCard dashed (checklist)")
                                .font(SGTheme.cardTitle)
                                .foregroundColor(SGTheme.paper)
                        }
                    }

                    section("Rows & tiles") {
                        SGListRow(title: "Usage interval",
                                  subtitle: "15 minutes before they lock",
                                  icon: "timer") {}
                        SGPickerRow(title: "15 minutes", selected: pickerSelection == 0) { pickerSelection = 0 }
                        SGPickerRow(title: "30 minutes", selected: pickerSelection == 1) { pickerSelection = 1 }
                        HStack(spacing: 10) {
                            SGOptionTile(title: "Flashcards", icon: "rectangle.stack.fill",
                                         selected: optionSelection == 0) { optionSelection = 0 }
                            SGOptionTile(title: "True Focus", icon: "eye.fill",
                                         selected: optionSelection == 1) { optionSelection = 1 }
                        }
                        HStack(spacing: 10) {
                            SGChip(text: "12 apps", icon: "apps.iphone") {}
                            SGChip(text: "15m", icon: "timer") {}
                        }
                    }

                    section("Field & progress") {
                        SGField(placeholder: "Question", text: $fieldText)
                        SGProgressBar(progress: progress)
                        SGProgressBar(progress: progress, thin: true)
                        SGButton(title: "Advance progress", variant: .ghost) {
                            progress = progress >= 1 ? 0.1 : progress + 0.3
                        }
                    }

                    section("Quiz kit") {
                        QuizProgressBar(results: [true, true, false, nil, nil], currentIndex: 3)
                        QuizPraiseCapsule(text: "Nice one!", showsWhy: true)
                        QuizAnswerTile(text: "Selected (tap to confirm)", state: .selected, confirmHint: true)
                        QuizAnswerTile(text: "Revealed correct", state: .revealedCorrect)
                        QuizAnswerTile(text: "Revealed wrong", state: .revealedWrong)
                    }

                    section("Type scale") {
                        Group {
                            Text("96").font(SGTheme.heroDigit) + Text("\u{2009}m").font(SGTheme.heroUnit).foregroundColor(SGTheme.paperSecondary)
                        }
                        Text("Screen title").font(SGTheme.screenTitle)
                        Text("Step title").font(SGTheme.stepTitle)
                        Text("Sheet title").font(SGTheme.sheetTitle)
                        Text("Card title").font(SGTheme.cardTitle)
                        Text("Row label").font(SGTheme.rowLabel)
                        Text("Body copy for paragraphs.").font(SGTheme.body).foregroundColor(SGTheme.paperSecondary)
                        Text("Caption").font(SGTheme.caption).foregroundColor(SGTheme.paperSecondary)
                        SGMicroLabel(text: "Micro label")
                    }
                    .foregroundColor(SGTheme.paper)

                    section("Palette") {
                        swatchRow([("mintDeep", SGTheme.mintDeep), ("mint", SGTheme.mint),
                                   ("mintSoft", SGTheme.mintSoft), ("mintTint", SGTheme.mintTint)])
                        swatchRow([("emberDeep", SGTheme.emberDeep), ("ember", SGTheme.ember),
                                   ("emberSoft", SGTheme.emberSoft), ("emberTint", SGTheme.emberTint)])
                        swatchRow([("night", SGTheme.night), ("teal", SGTheme.teal),
                                   ("amber", SGTheme.amber), ("sun", SGTheme.sun)])
                    }

                    section("Entrance (sgRiseIn)") {
                        SGCard {
                            Text("Rises on appear")
                                .font(SGTheme.cardTitle)
                                .foregroundColor(SGTheme.paper)
                        }
                        .sgRiseIn(riseShown, delay: 0.1)
                        SGButton(title: "Replay", variant: .ghost) {
                            riseShown = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { riseShown = true }
                        }
                    }
                }
                .padding(SGTheme.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Design Gallery")
        .onAppear { riseShown = true }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SGMicroLabel(text: title, color: SGTheme.mintDeep)
            content()
        }
    }

    private func hapticRow(_ name: String, fire: @escaping () -> Void) -> some View {
        Button(action: fire) {
            HStack {
                Text(name)
                    .font(SGTheme.rowLabel)
                    .foregroundColor(SGTheme.paper)
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SGTheme.mint)
            }
            .padding(.horizontal, SGTheme.cardPadding)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
            )
        }
        .buttonStyle(SGPressStyle())
    }

    private func swatchRow(_ swatches: [(String, Color)]) -> some View {
        HStack(spacing: 8) {
            ForEach(swatches, id: \.0) { name, color in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(SGTheme.hairline, lineWidth: 1)
                        )
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(SGTheme.paperSecondary)
                }
            }
        }
    }
}

#Preview("Gallery") {
    NavigationStack { SGGalleryView() }
}
#endif
