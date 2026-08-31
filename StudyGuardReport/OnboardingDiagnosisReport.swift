//
//  OnboardingDiagnosisReport.swift
//  StudyGuardReport
//
//  The onboarding verdict's real-usage row: "Your iPhone says 6h 12m a day.
//  That's 14 of your 47 days." The host passes the exam date through the
//  app group (the only data crossing INTO this sandbox); the average comes
//  from the last 7 days of real usage, and the math happens here because
//  usage numbers can never leave the report process.
//
//  Renders nothing when iOS has no data yet (and always in the Simulator) —
//  the host reserves a fixed-height row that just stays blank.
//
//  App-group ID and key are by value: design isolation keeps this extension
//  dependency-free (see TopOffendersReport's header).
//

import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let onboardingDiagnosis = Self("onboardingDiagnosis")
}

// MARK: - Model

struct DiagnosisVerdict {
    /// Average seconds of screen time per day over the queried window.
    let avgDailySeconds: TimeInterval
    /// Days until the exam, from the app group. Nil = deadline season.
    let daysToExam: Int?
    /// Full 24-hour days the phone will eat before the exam, at this rate.
    var phoneDays: Int? {
        guard let daysToExam else { return nil }
        return max(1, Int((avgDailySeconds / 86_400 * Double(daysToExam)).rounded()))
    }
}

// MARK: - Scene

struct OnboardingDiagnosisReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingDiagnosis
    let content: (DiagnosisVerdict?) -> OnboardingDiagnosisView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DiagnosisVerdict? {
        var total: TimeInterval = 0
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                total += segment.totalActivityDuration
            }
        }
        guard total > 0 else { return nil }

        let defaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
        let stamp = defaults?.double(forKey: "sg_onbExamDate") ?? 0
        let daysToExam: Int? = stamp > 0
            ? max(1, Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: stamp))
              ).day ?? 1)
            : nil

        // The filter is a fixed 7-day window; divide by the window, not by
        // segments-with-data, so quiet days pull the average down honestly.
        return DiagnosisVerdict(avgDailySeconds: total / 7, daysToExam: daysToExam)
    }
}

// MARK: - View

struct OnboardingDiagnosisView: View {
    let verdict: DiagnosisVerdict?

    // Night-sky text ramp + ember by value (host renders this row on the
    // night backdrop).
    private let ember = Color(red: 0xFF / 255.0, green: 0x6B / 255.0, blue: 0x5E / 255.0)

    var body: some View {
        if let verdict {
            VStack(spacing: 3) {
                Text("Your iPhone says \(formatted(verdict.avgDailySeconds)) a day.")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let phoneDays = verdict.phoneDays, let days = verdict.daysToExam {
                    Text("That's \(phoneDays) of your \(days) days. Not an estimate.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(ember)
                } else {
                    Text("Measured, not estimated.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(ember)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: seconds) ?? "0m"
    }
}
