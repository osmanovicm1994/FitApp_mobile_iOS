// BackupViews.swift
// UI for Google backup & restore. Pure display + user intent: all logic lives in AppState.
//   • BackupSettingsSection  — the "Backup & Restore" section inside Settings
//   • RestoreOfferSheet      — "Backup found" confirmation (shown by RootView)
//   • RestoreFromGoogleButton — the button on the first onboarding screen

import SwiftUI
import Combine  // explicit import

// MARK: - Settings section

struct BackupSettingsSection: View {
    @EnvironmentObject var appState: AppState
    @State private var showDisconnectAlert = false
    @State private var showDeleteCloudAlert = false

    private var autoBackupBinding: Binding<Bool> {
        Binding(get: { appState.autoBackupEnabled },
                set: { appState.setAutoBackup($0) })
    }

    var body: some View {
        Section {
            if let email = appState.cloudEmail {
                connectedRows(email: email)
            } else {
                Button {
                    Task { await appState.connectGoogle() }
                } label: {
                    HStack {
                        Label("Connect Google Account", systemImage: "icloud.and.arrow.up")
                        Spacer()
                        if appState.cloudBusy { ProgressView() }
                    }
                }
                .disabled(appState.cloudBusy)
                .accessibilityIdentifier("google_connect_button")
            }

            if let message = appState.cloudMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .accessibilityIdentifier("cloud_message")
            }
        } header: {
            Text("Backup & Restore")
        } footer: {
            Text("Your data is saved as one private file in a hidden app folder of your own Google Drive. Only FitApp can open it, and it does not use your normal Drive storage list. Use it to move FitApp to a new phone.")
                .accessibilityIdentifier("backup_footer")
        }
        .alert("Disconnect Google?", isPresented: $showDisconnectAlert) {
            Button("Disconnect", role: .destructive) {
                Task { await appState.disconnectGoogle(deleteCloudBackup: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Automatic backups stop. The backup already in your Google Drive is kept.")
        }
        .alert("Delete Cloud Backup?", isPresented: $showDeleteCloudAlert) {
            Button("Delete Backup & Disconnect", role: .destructive) {
                Task { await appState.disconnectGoogle(deleteCloudBackup: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the FitApp backup from your Google Drive and disconnects your account. Data on this device is not changed.")
        }
    }

    @ViewBuilder
    private func connectedRows(email: String) -> some View {
        HStack {
            Text("Account")
            Spacer()
            Text(email)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("google_account_value")
        }

        HStack {
            Text("Last Backup")
            Spacer()
            if let last = appState.lastBackupAt {
                Text(last, style: .relative)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("last_backup_value")
            } else {
                Text("Never")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("last_backup_value")
            }
        }

        Toggle("Automatic Backup", isOn: autoBackupBinding)
            .accessibilityIdentifier("auto_backup_toggle")

        Button {
            Task { await appState.backupNow() }
        } label: {
            HStack {
                Label("Back Up Now", systemImage: "icloud.and.arrow.up")
                Spacer()
                if appState.cloudBusy { ProgressView() }
            }
        }
        .disabled(appState.cloudBusy)
        .accessibilityIdentifier("backup_now_button")

        Button {
            Task { await appState.offerRestoreFromCloud() }
        } label: {
            Label("Restore from Backup…", systemImage: "icloud.and.arrow.down")
        }
        .disabled(appState.cloudBusy)
        .accessibilityIdentifier("restore_backup_button")

        Button(role: .destructive) {
            showDisconnectAlert = true
        } label: {
            Label("Disconnect Google", systemImage: "person.crop.circle.badge.xmark")
        }
        .disabled(appState.cloudBusy)
        .accessibilityIdentifier("google_disconnect_button")

        Button(role: .destructive) {
            showDeleteCloudAlert = true
        } label: {
            Label("Delete Cloud Backup…", systemImage: "trash")
        }
        .disabled(appState.cloudBusy)
        .accessibilityIdentifier("delete_cloud_backup_button")
    }
}

// MARK: - Restore confirmation sheet

struct RestoreOfferSheet: View {
    @EnvironmentObject var appState: AppState
    let offer: CloudRestoreOffer

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Backup Found")
                    .font(.title2.bold())
                    .accessibilityIdentifier("restore_offer_title")

                VStack(spacing: 10) {
                    detailRow("Profile", offer.profileName.isEmpty ? "—" : offer.profileName)
                    detailRow("Backed up", offer.remoteModified.formatted(date: .abbreviated, time: .shortened))
                    detailRow("Workouts logged", "\(offer.workoutCount)")
                    detailRow("Meals logged", "\(offer.mealCount)")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                if appState.hasCompletedOnboarding {
                    Text("Restoring replaces all data currently on this device with this backup.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    appState.restore(offer)
                } label: {
                    Text("Restore This Backup")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .accessibilityIdentifier("restore_confirm_button")

                if appState.hasCompletedOnboarding {
                    Button {
                        Task { await appState.keepLocalDataAndReplaceBackup() }
                    } label: {
                        Text("Keep This Device's Data & Replace Backup")
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityIdentifier("restore_keep_local_button")
                }

                Button("Cancel", role: .cancel) {
                    appState.dismissRestoreOffer()
                }
                .foregroundColor(.secondary)
                .accessibilityIdentifier("restore_cancel_button")

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("restore_offer_sheet")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

// MARK: - Onboarding button

struct RestoreFromGoogleButton: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task { await appState.connectGoogle() }
            } label: {
                HStack(spacing: 8) {
                    if appState.cloudBusy {
                        ProgressView()
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    Text("Restore from Google")
                        .fontWeight(.medium)
                }
            }
            .disabled(appState.cloudBusy)
            .accessibilityIdentifier("restore_from_google_button")

            if let message = appState.cloudMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("restore_message")
            }
        }
    }
}
