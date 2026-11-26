// SettingsView.swift
// App settings: dark/light mode toggle, goals, body tracking, backup, reset/delete options,
// health disclaimer, about.

import SwiftUI
import Combine  // explicit import
import FitAppSharedModule

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetAlert: Bool = false
    @State private var showResetProfileAlert: Bool = false
    @State private var showResetNutritionAlert: Bool = false
    @State private var showDeleteAllAlert: Bool = false
#if DEBUG
    @State private var showSharedExperience = false
#endif

    var body: some View {
        NavigationStack {
            Form {

                // ── Appearance ────────────────────────────────────────────
                Section("Appearance") {
                    HStack {
                        Label("Dark Mode", systemImage: appState.isDarkMode ? "moon.fill" : "sun.max.fill")
                        Spacer()
                        Toggle("", isOn: $appState.isDarkMode)
                            .labelsHidden()
                            .accessibilityIdentifier("dark_mode_toggle")
                    }
                    .accessibilityIdentifier("dark_mode_row")
                }

                // ── Profile ───────────────────────────────────────────────
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(appState.profile.name)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_name_value")
                    }
                    HStack {
                        Text("Goal")
                        Spacer()
                        Text(appState.profile.goal.rawValue)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_goal_value")
                    }
                    Button(role: .destructive) {
                        showResetProfileAlert = true
                    } label: {
                        Label("Reset Profile & Re-run Onboarding", systemImage: "person.crop.circle.badge.xmark")
                    }
                    .accessibilityIdentifier("reset_profile_button")
                }

                // ── Body tracking (weight + measurements) ─────────────────
                BodyTrackingSettingsSection()

                // ── Nutrition ─────────────────────────────────────────────
                Section {
                    HStack {
                        Text("Daily Calorie Goal")
                        Spacer()
                        Text("\(Int(appState.dailyCalorieGoal)) kcal")
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_calorie_goal_value")
                    }
                    HStack {
                        Text("Daily Water Goal")
                        Spacer()
                        Text("\(Int(appState.dailyWaterGoalMl)) ml")
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_water_goal_value")
                    }
                    HStack {
                        Text("Daily Protein Goal")
                        Spacer()
                        Text("\(Int(appState.dailyProteinGoalG)) g")
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_protein_goal_value")
                    }
                    Button(role: .destructive) {
                        showResetNutritionAlert = true
                    } label: {
                        Label("Reset Today's Nutrition", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("reset_nutrition_settings_button")
                } header: {
                    Text("Nutrition")
                } footer: {
                    Text("Goals are rough estimates based on your age, weight, height and goal. They are not medical advice.")
                        .accessibilityIdentifier("goal_estimate_footer")
                }

                // ── Backup & Restore (Google) ─────────────────────────────
                BackupSettingsSection()

                // ── Test install expiry (free developer account only) ─────
                BuildExpirySettingsSection()

                // ── Data ──────────────────────────────────────────────────
                Section("Data") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("reset_all_data_button")

                    Button(role: .destructive) {
                        showDeleteAllAlert = true
                    } label: {
                        Label("Delete All My Data", systemImage: "trash.fill")
                    }
                    .accessibilityIdentifier("delete_all_data_button")
                }

                // ── Health disclaimer ─────────────────────────────────────
                Section("Health Disclaimer") {
                    Text("FitApp provides general fitness and nutrition information for educational purposes only. It is not medical advice and does not replace a doctor, dietitian or qualified trainer. Talk to a health professional before changing your diet or starting a new exercise program, and stop exercising if you feel pain, dizziness or unwell.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("health_disclaimer_text")
                }

                // ── About ─────────────────────────────────────────────────
                Section("About") {
#if DEBUG
                    Button {
                        showSharedExperience = true
                    } label: {
                        Label("Shared Experience Preview", systemImage: "swift")
                    }
                    .accessibilityIdentifier("shared_experience_preview_button")
#endif
                    HStack {
                        Text("App")
                        Spacer()
                        Text("FitApp")
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_app_name")
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_version")
                    }
                    HStack {
                        Text("Recipes")
                        Spacer()
                        Text("Original FitApp recipes")
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("settings_recipes_source")
                    }
                }
            }
            .navigationTitle("Settings")
#if DEBUG
            .fullScreenCover(isPresented: $showSharedExperience) {
                ReactNativeView(moduleName: "main")
            }
#endif
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    appState.resetTrackingData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all workouts and nutrition data, including your nutrition history. Your profile, My Foods, My Meals, weight history and body measurements will be kept.")
            }
            .alert("Reset Today's Nutrition?", isPresented: $showResetNutritionAlert) {
                Button("Reset", role: .destructive) {
                    appState.resetNutrition()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all meals and water logged today. Earlier days are kept.")
            }
            .alert("Reset Profile?", isPresented: $showResetProfileAlert) {
                Button("Reset", role: .destructive) {
                    appState.resetProfile()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be taken back through the onboarding wizard. Your weight history and body measurements are kept.")
            }
            .alert("Delete All My Data?", isPresented: $showDeleteAllAlert) {
                Button("Delete Everything", role: .destructive) {
                    appState.resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your profile, workouts, nutrition history, My Foods, My Meals, weight history, body measurements and favorites from this device and returns FitApp to its first-launch state. If Google backup is connected, it is disconnected, but the backup already in your Google Drive is kept (delete it first with \"Delete Cloud Backup\" if you want it gone). This cannot be undone.")
            }
        }
        .accessibilityIdentifier("settings_view")
    }
}
