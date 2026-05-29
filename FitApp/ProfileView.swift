// ProfileView.swift
// View and edit the user profile created during onboarding.

import SwiftUI
import Combine  // explicit import

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var isEditing: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar + name header
                    profileHeader
                    // Stats summary
                    statsGrid
                    // Workout summary
                    workoutSummaryCard
                    // Goal card
                    goalCard
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { isEditing = true }
                        .accessibilityIdentifier("edit_profile_button")
                }
            }
            .sheet(isPresented: $isEditing) {
                EditProfileSheet()
            }
        }
        .accessibilityIdentifier("profile_view")
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Text(appState.profile.avatarEmoji)
                .font(.system(size: 80))
                .accessibilityIdentifier("profile_avatar")

            Text(appState.profile.name.isEmpty ? "Your Name" : appState.profile.name)
                .font(.title.bold())
                .accessibilityIdentifier("profile_name_label")

            Text(appState.profile.goal.rawValue)
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
                .accessibilityIdentifier("profile_goal_label")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCell(label: "Age",    value: "\(appState.profile.age)", unit: "yrs",  id: "profile_age_cell")
            StatCell(label: "Weight", value: String(format: "%.0f", appState.profile.weightKg), unit: "kg", id: "profile_weight_cell")
            StatCell(label: "Height", value: String(format: "%.0f", appState.profile.heightCm), unit: "cm", id: "profile_height_cell")
        }
        .accessibilityIdentifier("profile_stats_grid")
    }

    // MARK: - Workout Summary

    private var workoutSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout Summary", systemImage: "dumbbell.fill")
                .font(.headline)

            HStack {
                VStack {
                    Text("\(appState.workoutHistory.count)")
                        .font(.title.bold())
                        .foregroundColor(.blue)
                        .accessibilityIdentifier("total_workouts_label")
                    Text("Total\nWorkouts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50)

                VStack {
                    Text("\(appState.completedExercisesCount)")
                        .font(.title.bold())
                        .foregroundColor(.green)
                        .accessibilityIdentifier("completed_exercises_label")
                    Text("Done\nToday")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50)

                VStack {
                    Text("\(appState.exercises.count)")
                        .font(.title.bold())
                        .foregroundColor(.orange)
                        .accessibilityIdentifier("total_exercises_label")
                    Text("In\nPlan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            NavigationLink("View Workout History →") {
                WorkoutHistoryView()
            }
            .font(.subheadline.bold())
            .foregroundColor(.blue)
            .accessibilityIdentifier("workout_history_link")
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Goal Card

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Daily Goals", systemImage: "target")
                .font(.headline)

            VStack(spacing: 10) {
                GoalRow(
                    label: "Water",
                    current: Int(appState.todayNutrition.waterMl),
                    goal: Int(appState.dailyWaterGoalMl),
                    unit: "ml",
                    color: .cyan,
                    id: "water_goal_row"
                )
                GoalRow(
                    label: "Protein",
                    current: Int(appState.todayNutrition.proteinG),
                    goal: Int(appState.dailyProteinGoalG),
                    unit: "g",
                    color: .blue,
                    id: "protein_goal_row"
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Sub-views

struct StatCell: View {
    let label: String
    let value: String
    let unit: String
    let id: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold())
            Text(unit).font(.caption).foregroundColor(.secondary)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .accessibilityIdentifier(id)
    }
}

struct GoalRow: View {
    let label: String
    let current: Int
    let goal: Int
    let unit: String
    let color: Color
    let id: String

    var progress: Double { min(Double(current) / max(Double(goal), 1), 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(current) / \(goal) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 8)
        }
        .accessibilityIdentifier(id)
    }
}

// MARK: - Workout History

struct WorkoutHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if appState.workoutHistory.isEmpty {
                ContentUnavailableView(
                    "No Workout History Yet",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Finish a workout to see it listed here.")
                )
                .accessibilityIdentifier("empty_workout_history")
            } else {
                ForEach(appState.workoutHistory.sorted(by: { $0.date > $1.date })) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.date, style: .date)
                            .font(.headline)
                        Text("\(session.exercises.count) exercises")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("workout_history_row_\(session.id)")
                }
            }
        }
        .navigationTitle("Workout History")
        .accessibilityIdentifier("workout_history_view")
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var age: String = ""
    @State private var weightKg: String = ""
    @State private var heightCm: String = ""
    @State private var selectedGoal: UserProfile.FitnessGoal = .maintain
    @State private var selectedAvatar: String = ""

    private let avatars = ["🧑", "👨", "👩", "🧔", "👱", "🏋️", "🤸", "🧘"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(avatars, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.largeTitle)
                                    .padding(6)
                                    .background(selectedAvatar == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                    .onTapGesture { selectedAvatar = emoji }
                            }
                        }
                    }
                    .accessibilityIdentifier("edit_avatar_picker")
                }
                Section("Personal") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("edit_name_field")
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("25", text: $age).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("edit_age_field")
                    }
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("70", text: $weightKg).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("edit_weight_field")
                    }
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("170", text: $heightCm).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("edit_height_field")
                    }
                }
                Section("Fitness Goal") {
                    ForEach(UserProfile.FitnessGoal.allCases, id: \.self) { goal in
                        Button(action: { selectedGoal = goal }) {
                            HStack {
                                Image(systemName: goal.icon)
                                Text(goal.rawValue)
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("edit_goal_\(goal.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .accessibilityIdentifier("save_profile_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_edit_button")
                }
            }
        }
        .onAppear { populateFromProfile() }
        .accessibilityIdentifier("edit_profile_sheet")
    }

    private func populateFromProfile() {
        name         = appState.profile.name
        age          = "\(appState.profile.age)"
        weightKg     = String(format: "%.0f", appState.profile.weightKg)
        heightCm     = String(format: "%.0f", appState.profile.heightCm)
        selectedGoal = appState.profile.goal
        selectedAvatar = appState.profile.avatarEmoji
    }

    private func saveProfile() {
        appState.profile = UserProfile(
            id: appState.profile.id,
            name: name,
            age: Int(age) ?? appState.profile.age,
            weightKg: Double(weightKg) ?? appState.profile.weightKg,
            heightCm: Double(heightCm) ?? appState.profile.heightCm,
            goal: selectedGoal,
            avatarEmoji: selectedAvatar.isEmpty ? appState.profile.avatarEmoji : selectedAvatar
        )
        dismiss()
    }
}
