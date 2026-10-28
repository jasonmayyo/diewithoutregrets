//
//  MonsterNudges.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 2): a single persona-voiced evening re-engagement nudge.
//  Only schedules when notifications are ALREADY authorized (never prompts), and
//  studying pushes it to tomorrow — so it fires on quiet days, not study days.
//  "He's a monster, not a marketer": one nudge, not spam. See Docs/TutorMonsterPlan.md §7.
//

import Foundation
import UserNotifications

enum MonsterNudges {
    private static let id = "sg_monster_nudge"
    private static let hour = 19   // 7pm local

    /// Queue the next nudge if none is pending (call on foreground).
    static func ensureScheduled(persona: MonsterPersona) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            center.getPendingNotificationRequests { requests in
                guard !requests.contains(where: { $0.identifier == id }) else { return }
                schedule(at: nextFireDate(from: Date()), persona: persona)
            }
        }
    }

    /// After a study session, push the nudge to tomorrow evening.
    static func rescheduleAfterStudy(persona: MonsterPersona) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            cancel()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            schedule(at: fireDate(on: tomorrow), persona: persona)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func schedule(at date: Date, persona: MonsterPersona) {
        let line = MonsterScript.nudge(persona: persona)
        let content = UNMutableNotificationContent()
        content.title = line.title
        content.body = line.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func nextFireDate(from now: Date) -> Date {
        let today = fireDate(on: now)
        if today > now { return today }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return fireDate(on: tomorrow)
    }

    private static func fireDate(on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}
