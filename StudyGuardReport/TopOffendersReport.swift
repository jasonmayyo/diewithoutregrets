//
//  TopOffendersReport.swift
//  StudyGuardReport
//
//  "Top Offenders": today's most-used apps, ranked. Rendered inside the
//  Blocks page's raised card, so the scene draws transparent rows and the
//  host owns the card chrome. Colors are the Meadow tokens by value —
//  SGTheme lives in the app target and design isolation keeps this
//  extension dependency-free.
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    static let topOffenders = Self("Top Offenders")
}

// MARK: - Model

struct Offender: Identifiable {
    let id = UUID()
    let name: String
    let token: ApplicationToken?
    let duration: TimeInterval
    let formattedDuration: String
}

// MARK: - Scene

struct TopOffendersReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .topOffenders
    let content: ([Offender]) -> TopOffendersView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> [Offender] {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll

        // Aggregate per app across all segments/devices, keyed by display
        // name so iPhone + iPad rows for the same app merge.
        var perApp: [String: (token: ApplicationToken?, duration: TimeInterval)] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }
                        let name = app.application.localizedDisplayName ?? "Unknown app"
                        var entry = perApp[name] ?? (app.application.token, 0)
                        entry.duration += duration
                        if entry.token == nil { entry.token = app.application.token }
                        perApp[name] = entry
                    }
                }
            }
        }

        return perApp
            .map { name, v in
                Offender(
                    name: name,
                    token: v.token,
                    duration: v.duration,
                    formattedDuration: v.duration < 60
                        ? "<1m"
                        : (formatter.string(from: v.duration) ?? "0m")
                )
            }
            .sorted { $0.duration > $1.duration }
            .prefix(6)
            .map { $0 }
    }
}

// MARK: - View

struct TopOffendersView: View {
    let offenders: [Offender]

    // MeadowHomeV2 slab language by value (see header): white text on the
    // dark translucent card, progress-fill green for the minutes.
    private let accent = Color(red: 0xDC / 255.0, green: 0xF9 / 255.0, blue: 0xCB / 255.0)
    private let hairline = Color.white.opacity(0.12)

    var body: some View {
        if offenders.isEmpty {
            VStack(spacing: 6) {
                Text("Nothing to report yet")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Today's most used apps will show up here.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(offenders.enumerated()), id: \.element.id) { index, offender in
                    row(rank: index + 1, offender: offender)
                    if index < offenders.count - 1 {
                        Divider()
                            .overlay(hairline)
                            .padding(.leading, 56)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(rank: Int, offender: Offender) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 16, alignment: .center)

            if let token = offender.token {
                Color.clear
                    .frame(width: 28, height: 28)
                    .overlay(Label(token).labelStyle(.iconOnly).scaleEffect(0.95))
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(offender.name.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    )
            }

            Text(offender.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(offender.formattedDuration)
                .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundColor(accent)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}
