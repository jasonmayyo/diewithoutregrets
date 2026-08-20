//
//  QuizV2StreakView.swift
//  diewithoutregrets
//
//  The unlock celebration, redesigned as a streak poster (reference: the
//  approved cream sunburst mock). Shown after every winning quiz run; the
//  grant already happened at the final commit, this screen is the receipt
//  plus the habit loop: torch monster, day counter, lit week, milestone.
//
//  Streak semantics: consecutive calendar days with at least one earned
//  unlock. Multiple unlocks in one day count once; a missed day resets.
//

import SwiftUI

// MARK: - Streak ledger

enum QV2Streak {
    private static let countKey = "sg_streakCount"
    private static let lastDayKey = "sg_streakLastDay"

    static var count: Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    /// The streak as it should be DISPLAYED right now: the stored count if
    /// the last success was today or yesterday (still alive), else 0 (a
    /// missed day broke it; recordSuccess will restart at 1). The home
    /// screen and the celebration's roll-up start read this, never `count`.
    static func current(now: Date = Date()) -> Int {
        let d = UserDefaults.standard
        let streak = d.integer(forKey: countKey)
        guard streak > 0 else { return 0 }

        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let last = Date(timeIntervalSinceReferenceDate: d.double(forKey: lastDayKey))
        if cal.isDate(last, inSameDayAs: today) { return streak }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(last, inSameDayAs: yesterday) { return streak }
        return 0
    }

    /// Records a successful unlock and returns the updated streak.
    @discardableResult
    static func recordSuccess(now: Date = Date()) -> Int {
        let d = UserDefaults.standard
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let last = Date(timeIntervalSinceReferenceDate: d.double(forKey: lastDayKey))
        var streak = d.integer(forKey: countKey)

        if streak > 0, cal.isDate(last, inSameDayAs: today) {
            // Already counted today.
        } else if streak > 0,
                  let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  cal.isDate(last, inSameDayAs: yesterday) {
            streak += 1
        } else {
            streak = 1
        }

        d.set(streak, forKey: countKey)
        d.set(today.timeIntervalSinceReferenceDate, forKey: lastDayKey)
        return streak
    }

    /// Creator toolkit: pin the streak to an exact value, stamped today so
    /// it displays immediately. Zero clears the ledger entirely.
    static func creatorSet(_ value: Int, now: Date = Date()) {
        let d = UserDefaults.standard
        if value <= 0 {
            d.removeObject(forKey: countKey)
            d.removeObject(forKey: lastDayKey)
        } else {
            d.set(value, forKey: countKey)
            d.set(Calendar.current.startOfDay(for: now).timeIntervalSinceReferenceDate,
                  forKey: lastDayKey)
        }
    }

    /// Monday-first flags for the current week: true = day is covered by
    /// the streak (today and the streak's tail into this week).
    static func litWeekdays(streak: Int, now: Date = Date()) -> [Bool] {
        let cal = Calendar.current
        let todayIdx = (cal.component(.weekday, from: now) + 5) % 7
        let firstLit = max(0, todayIdx - (streak - 1))
        return (0..<7).map { streak > 0 && $0 >= firstLit && $0 <= todayIdx }
    }
}

// MARK: - Screen

struct QuizV2StreakView: View {
    let streak: Int
    /// The streak as it read BEFORE this unlock (0 on the first day), so
    /// the numeral can roll up to the new count on entry.
    var previousStreak: Int? = nil
    let onClose: () -> Void

    private let weekLetters = ["M", "T", "W", "T", "F", "S", "S"]

    /// Entry choreography: everything keys off one flag with staggered
    /// delays; the numeral rolls separately so numericText can count.
    @State private var appear = false
    @State private var shownStreak = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The count the numeral starts on. Never equal to `streak` unless the
    /// unlock didn't move the ledger (second unlock the same day).
    private var rollStart: Int {
        min(previousStreak ?? max(0, streak - 1), streak)
    }

    var body: some View {
        ZStack {
            QV2SunburstBackground(
                base: QV2.cream,
                ray: QV2.creamRay,
                center: UnitPoint(x: 0.5, y: 0.26)
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                closeRow

                Image("monster-torch")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .padding(.top, 2)
                    .scaleEffect(appear ? 1 : 0.6)
                    .opacity(appear ? 1 : 0)
                    .animation(SGTheme.springPop, value: appear)

                QV2OutlinedText(
                    text: "\(shownStreak)",
                    size: 58,
                    fill: QV2.text,
                    outline: .white
                )
                .padding(.top, 8)
                .scaleEffect(shownStreak == streak && streak > rollStart ? 1 : 0.94)
                .animation(SGTheme.springPop, value: shownStreak)

                Text(streak == 1 ? "Day Streak!" : "Days Streak!")
                    .font(QV2.font(26, .bold))
                    .foregroundColor(QV2.text)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: appear)

                weekRow
                    .padding(.top, 16)

                encouragementCard
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 18)
                    .animation(SGTheme.spring.delay(0.55), value: appear)

                Spacer(minLength: 12)

                rewardsSheet
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 40)
                    .animation(SGTheme.spring.delay(0.7), value: appear)
            }
        }
        .onAppear(perform: runEntrance)
    }

    private func runEntrance() {
        guard !appear else { return }

        if reduceMotion {
            appear = true
            shownStreak = streak
            return
        }

        shownStreak = rollStart
        appear = true

        // The roll lands after the mascot pop, before the card slides in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(SGTheme.springPop) { shownStreak = streak }
            if streak > rollStart { SGTheme.gain() }
        }
    }

    // MARK: Pieces

    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(QV2.creamDeep)
                        .frame(width: 44, height: 44)
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(QV2.text)
                }
            }
            .buttonStyle(SGPressStyle())
            .accessibilityLabel("Continue to my apps")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var weekRow: some View {
        HStack(spacing: 9) {
            let lit = QV2Streak.litWeekdays(streak: streak)
            ForEach(0..<7, id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(QV2.creamDeep)
                        .frame(width: 40, height: 40)
                    if lit[i] {
                        Image("sticker-fire")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .scaleEffect(appear ? 1 : 0.01)
                            // Fires land left to right after the numeral
                            // roll (0.45), today's last.
                            .animation(
                                SGTheme.springPop.delay(0.5 + Double(i) * 0.08),
                                value: appear
                            )
                    } else {
                        Text(weekLetters[i])
                            .font(QV2.font(17, .bold))
                            .foregroundColor(QV2.text)
                    }
                }
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.25).delay(0.25 + Double(i) * 0.03), value: appear)
            }
        }
    }

    private var encouragementCard: some View {
        VStack(spacing: 8) {
            Image("sticker-fire")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .background(
                    RadialGradient(
                        colors: [QV2.cardOrangeGlow.opacity(0.65), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                    .frame(width: 120, height: 120)
                )

            Text("Keep at it!\nWe're just getting started!")
                .font(QV2.font(16, .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(QV2.cardOrange)
        )
    }

    private var rewardsSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Challenges and Rewards")
                .font(QV2.font(20, .bold))
                .foregroundColor(QV2.text)

            milestoneCard

            QV2CTAButton(title: "UNLOCK MY APPS", action: onClose)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var milestoneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7 Days Milestone")
                    .font(QV2.font(17, .bold))
                    .foregroundColor(QV2.text)
                Spacer()
                Text("\(min(streak, 7))/7")
                    .font(QV2.font(17, .bold))
                    .foregroundColor(QV2.text)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(QV2.track)
                        .frame(height: 12)

                    Capsule()
                        .fill(QV2.cardOrange)
                        .frame(
                            width: max(12, geo.size.width * CGFloat(min(streak, 14)) / 14),
                            height: 12
                        )

                    QV2CalendarBadge(day: 7)
                        .position(x: geo.size.width * 0.5, y: 6)
                    QV2CalendarBadge(day: 14)
                        .position(x: geo.size.width - 11, y: 6)
                }
            }
            .frame(height: 22)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(QV2.track, lineWidth: 1.5)
        )
    }
}

// MARK: - Tiny calendar milestone badge

private struct QV2CalendarBadge: View {
    let day: Int

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(QV2.red)
                .frame(height: 6)
            Text("\(day)")
                .font(QV2.font(10, .bold))
                .foregroundColor(QV2.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(QV2.chrome, lineWidth: 1)
        )
    }
}

// MARK: - Outlined numeral

/// Fat charcoal digits with a thick white outline (poster style): the
/// outline is the same text stamped at 8 offsets behind the fill.
struct QV2OutlinedText: View {
    let text: String
    let size: CGFloat
    var fill: Color = QV2.text
    var outline: Color = .white
    var width: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                Text(text)
                    .font(QV2.font(size, .heavy))
                    .foregroundColor(outline)
                    .contentTransition(.numericText(countsDown: false))
                    .offset(
                        x: Foundation.cos(angle) * width,
                        y: Foundation.sin(angle) * width
                    )
            }
            Text(text)
                .font(QV2.font(size, .heavy))
                .foregroundColor(fill)
                .contentTransition(.numericText(countsDown: false))
        }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
    }
}

// MARK: - Previews

#Preview("Streak 1") {
    QuizV2StreakView(streak: 1, previousStreak: 0, onClose: {})
}

#Preview("Streak 5") {
    QuizV2StreakView(streak: 5, previousStreak: 4, onClose: {})
}
