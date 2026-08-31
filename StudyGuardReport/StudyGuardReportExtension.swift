//
//  StudyGuardReportExtension.swift
//  StudyGuardReport
//
//  DeviceActivity REPORT extension: the only sanctioned way to show
//  per-app usage numbers. The host app embeds DeviceActivityReport views;
//  this extension receives the usage data in a sandboxed process and
//  renders the pixels. Usage data never crosses into the app process.
//

import DeviceActivity
import SwiftUI

@main
struct StudyGuardReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TopOffendersReport { offenders in
            TopOffendersView(offenders: offenders)
        }
        OnboardingDiagnosisReport { verdict in
            OnboardingDiagnosisView(verdict: verdict)
        }
    }
}
