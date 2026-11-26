// BuildExpiry.swift
// Free Apple developer accounts sign test installs for only 7 days; after that the app stops opening
// until it is installed again from Xcode. Apple does not allow changing this, so FitApp does the next best
// thing: it reads the expiry date of its own signing profile, shows the time left in Settings and (if the
// user agrees) sends a reminder notification before it runs out.
//
// App Store and TestFlight builds, and the simulator, have no embedded provisioning profile. There
// `expirationDate` is nil, so the Settings section is hidden and no reminder is scheduled.
//
// This file holds only device/build information (no user data), so it does not use AppState or persistence.

import SwiftUI
import UserNotifications

// MARK: - Expiry logic

enum BuildExpiry {

    private static let oneDayReminderID = "fitapp.build-expiry.1d"
    private static let twoHoursReminderID = "fitapp.build-expiry.2h"

    /// When the signing profile of this install expires, or nil when the build has no embedded profile
    /// (App Store, TestFlight, simulator).
    static var expirationDate: Date? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let data = FileManager.default.contents(atPath: path) else { return nil }

        // The file is a signed blob with an XML property list inside. Cut the plist out of the raw bytes.
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), options: [], in: start.lowerBound..<data.endIndex) else {
            return nil
        }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let date = dictionary["ExpirationDate"] as? Date else { return nil }
        return date
    }

    /// Short human text for the time left: "6 days", "30 hours", "Less than an hour" or "Expired".
    static func remainingDescription(until expiry: Date, now: Date = Date()) -> String {
        let seconds = expiry.timeIntervalSince(now)
        if seconds <= 0 { return "Expired" }
        let hours = Int(seconds / 3600)
        if hours >= 48 { return "\(hours / 24) days" }
        if hours >= 1 { return "\(hours) hours" }
        return "Less than an hour"
    }

    // MARK: Notifications

    static func notificationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asks for notification permission (once) and schedules the reminders. Returns true when allowed.
    static func enableReminders() async -> Bool {
        guard expirationDate != nil else { return false }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { await refreshReminders() }
        return granted
    }

    /// Called every time the app becomes active. When notifications are already allowed it re-plans the
    /// reminders from the CURRENT expiry date, so a fresh install from Xcode moves them forward by itself.
    static func refreshReminders() async {
        guard let expiry = expirationDate else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        center.removePendingNotificationRequests(withIdentifiers: [oneDayReminderID, twoHoursReminderID])

        let plans: [(id: String, lead: TimeInterval, title: String)] = [
            (oneDayReminderID, 24 * 3600, "FitApp expires in about a day"),
            (twoHoursReminderID, 2 * 3600, "FitApp expires in about 2 hours"),
        ]
        for plan in plans {
            let fireDate = expiry.addingTimeInterval(-plan.lead)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = "Connect your iPhone to your Mac and press Run in Xcode to renew this test install. Your data stays on the phone."
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                              from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }
}

// MARK: - Settings section

/// Shows the install expiry in Settings. Hidden completely on builds that do not expire.
struct BuildExpirySettingsSection: View {
    @State private var remindersOn: Bool = false
    @State private var remindersBlocked: Bool = false

    var body: some View {
        if let expiry = BuildExpiry.expirationDate {
            Section {
                HStack {
                    Text("Expires")
                    Spacer()
                    Text(expiry.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("build_expiry_date_value")
                }
                HStack {
                    Text("Time left")
                    Spacer()
                    Text(BuildExpiry.remainingDescription(until: expiry))
                        .foregroundColor(expiry.timeIntervalSinceNow < 24 * 3600 ? .red : .secondary)
                        .accessibilityIdentifier("build_expiry_remaining_value")
                }

                if remindersOn {
                    Label("Reminder is on", systemImage: "bell.fill")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("build_expiry_reminder_on_label")
                } else if remindersBlocked {
                    Text("Notifications are turned off for FitApp. Turn them on in the iPhone Settings app to get a reminder.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("build_expiry_reminder_blocked_label")
                } else {
                    Button {
                        Task {
                            let granted = await BuildExpiry.enableReminders()
                            remindersOn = granted
                            remindersBlocked = !granted
                        }
                    } label: {
                        Label("Remind me before it expires", systemImage: "bell")
                    }
                    .accessibilityIdentifier("build_expiry_enable_reminder_button")
                }
            } header: {
                Text("Test Install")
            } footer: {
                Text("This copy of FitApp was installed with a free Apple developer account, which Apple limits to 7 days. When it expires the app will not open. Your data stays on the phone: connect the iPhone to your Mac and press Run in Xcode again (do not delete the app first). Keep Google backup on as a safety net.")
                    .accessibilityIdentifier("build_expiry_footer")
            }
            .task {
                let status = await BuildExpiry.notificationStatus()
                remindersOn = (status == .authorized || status == .provisional || status == .ephemeral)
                remindersBlocked = (status == .denied)
            }
        }
    }
}
