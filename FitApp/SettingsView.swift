// SettingsView.swift
// App settings: dark/light mode toggle, reset options, about.

import SwiftUI
import Combine  // explicit import

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetAlert: Bool = false
    @State private var showResetProfileAlert: Bool = false

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

                // ── Nutrition ─────────────────────────────────────────────
                Section("Nutrition") {
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
                        appState.resetNutrition()
                    } label: {
                        Label("Reset Today's Nutrition", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("reset_nutrition_settings_button")
                }

                // ── Data ──────────────────────────────────────────────────
                Section("Data") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("reset_all_data_button")
                }

                // ── About ─────────────────────────────────────────────────
                Section("About") {
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
                        Text("Recipes from")
                        Spacer()
                        Link("cleananddelicious.com",
                             destination: URL(string: "https://cleananddelicious.com")!)
                            .accessibilityIdentifier("clean_and_delicious_link")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    appState.resetNutrition()
                    appState.workoutHistory = []
                    appState.exercises = [
                        WorkoutExercise(name: "Push-ups",  sets: 3, reps: 15),
                        WorkoutExercise(name: "Squats",    sets: 4, reps: 12),
                        WorkoutExercise(name: "Pull-ups",  sets: 3, reps: 8),
                        WorkoutExercise(name: "Plank",     sets: 3, reps: 60),
                        WorkoutExercise(name: "Lunges",    sets: 3, reps: 12),
                        WorkoutExercise(name: "Crunches",  sets: 3, reps: 20),
                    ]
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all workouts and nutrition data. Your profile will be kept.")
            }
            .alert("Reset Profile?", isPresented: $showResetProfileAlert) {
                Button("Reset", role: .destructive) {
                    appState.profile = UserProfile()
                    appState.hasCompletedOnboarding = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be taken back through the onboarding wizard.")
            }
        }
        .accessibilityIdentifier("settings_view")
    }
}
