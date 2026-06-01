// AppState.swift
// Central state object for GymApp.
// Matches the original model/action signatures exactly — no renames, no type changes.
// Persistence added via UserDefaults + JSON encoding using didSet observers.
// Every @Published var saves immediately on change and loads on init().

import SwiftUI
import Combine

// MARK: - Storage Keys

private enum Keys {
    static let profile               = "app.profile"
    static let hasCompletedOnboarding = "app.onboarding"
    static let isDarkMode            = "app.darkMode"
    static let exercises             = "app.exercises"
    static let workoutHistory        = "app.workoutHistory"
    static let todayNutrition        = "app.todayNutrition"
    static let todayNutritionDate    = "app.todayNutrition.date"
    static let fitRecipes            = "app.fitRecipes.favorites"  // only stores isFavorite flags
}

// MARK: - Persistence Helpers

private func save<T: Encodable>(_ value: T, key: String) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: key)
    }
}

private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}

// MARK: - Models

struct UserProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 25
    var weightKg: Double = 70.0
    var heightCm: Double = 170.0
    var goal: FitnessGoal = .loseWeight
    var avatarEmoji: String = "🧑"

    enum FitnessGoal: String, CaseIterable, Codable {
        case loseWeight  = "Lose Weight"
        case gainMuscle  = "Gain Muscle"
        case maintain    = "Maintain"
        case performance = "Performance"

        var icon: String {
            switch self {
            case .loseWeight:  return "arrow.down.circle"
            case .gainMuscle:  return "bolt.circle"
            case .maintain:    return "equal.circle"
            case .performance: return "flame.circle"
            }
        }
    }
}

struct WorkoutExercise: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var isCompleted: Bool = false

    /// Accessibility ID used by Appium tests
    var accessibilityID: String {
        "exercise_\(name.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_"))"
    }
}

struct WorkoutSession: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var exercises: [WorkoutExercise]
}

struct NutritionEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var waterMl: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatsG: Double = 0
    var calories: Double = 0
}

// Small Codable used to persist only the isFavorite flag per recipe.
// The full recipe content always comes from FitRecipe.database.
private struct RecipeFavoriteFlag: Codable {
    let title: String
    let isFavorite: Bool
}

// MARK: - AppState

final class AppState: ObservableObject {

    // ── Profile ───────────────────────────────────────────────────────────
    @Published var profile: UserProfile {
        didSet { save(profile, key: Keys.profile) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    // ── Theme ─────────────────────────────────────────────────────────────
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: Keys.isDarkMode) }
    }

    // ── Workout ───────────────────────────────────────────────────────────
    @Published var exercises: [WorkoutExercise] {
        didSet { save(exercises, key: Keys.exercises) }
    }

    @Published var workoutHistory: [WorkoutSession] {
        didSet { save(workoutHistory, key: Keys.workoutHistory) }
    }

    // ── Nutrition ─────────────────────────────────────────────────────────
    // todayNutrition resets automatically when the calendar day changes.
    @Published var todayNutrition: NutritionEntry {
        didSet { save(todayNutrition, key: Keys.todayNutrition) }
    }

    // ── Recipes ───────────────────────────────────────────────────────────
    @Published var fitRecipes: [FitRecipe] {
        didSet {
            // Only persist the isFavorite flags — recipe content comes from the database
            let flags = fitRecipes.map { RecipeFavoriteFlag(title: $0.title, isFavorite: $0.isFavorite) }
            save(flags, key: Keys.fitRecipes)
        }
    }

    // MARK: - init

    init() {
        // Profile
        profile = load(UserProfile.self, key: Keys.profile) ?? UserProfile()

        // Onboarding
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)

        // Dark mode — defaults to true
        if UserDefaults.standard.object(forKey: Keys.isDarkMode) != nil {
            isDarkMode = UserDefaults.standard.bool(forKey: Keys.isDarkMode)
        } else {
            isDarkMode = true
        }

        // Exercises — default starter list on first launch
        exercises = load([WorkoutExercise].self, key: Keys.exercises) ?? [
            WorkoutExercise(name: "Push-ups",  sets: 3, reps: 15),
            WorkoutExercise(name: "Squats",    sets: 4, reps: 12),
            WorkoutExercise(name: "Pull-ups",  sets: 3, reps: 8),
            WorkoutExercise(name: "Plank",     sets: 3, reps: 60),
            WorkoutExercise(name: "Lunges",    sets: 3, reps: 12),
            WorkoutExercise(name: "Crunches",  sets: 3, reps: 20),
        ]

        // Workout history
        workoutHistory = load([WorkoutSession].self, key: Keys.workoutHistory) ?? []

        // Nutrition — reset if the stored entry is from a previous day
        let savedNutrition = load(NutritionEntry.self, key: Keys.todayNutrition)
        let lastDate       = UserDefaults.standard.object(forKey: Keys.todayNutritionDate) as? Date

        if let saved = savedNutrition, let last = lastDate, Calendar.current.isDateInToday(last) {
            todayNutrition = saved
        } else {
            todayNutrition = NutritionEntry()
            UserDefaults.standard.set(Date(), forKey: Keys.todayNutritionDate)
        }

        // Recipes — start from the full database, then restore isFavorite flags
        let savedFlags = load([RecipeFavoriteFlag].self, key: Keys.fitRecipes) ?? []
        let flagMap = Dictionary(uniqueKeysWithValues: savedFlags.map { ($0.title, $0.isFavorite) })
        fitRecipes = FitRecipe.database.map { recipe in
            var r = recipe
            if let wasFavorite = flagMap[r.title] { r.isFavorite = wasFavorite }
            return r
        }
    }

    // MARK: - Computed Properties

    var colorScheme: ColorScheme? { isDarkMode ? .dark : .light }

    var completedExercisesCount: Int { exercises.filter(\.isCompleted).count }

    var dailyWaterGoalMl: Double { 2500 }

    var dailyProteinGoalG: Double {
        switch profile.goal {
        case .gainMuscle:  return profile.weightKg * 2.2
        case .loseWeight:  return profile.weightKg * 1.8
        case .maintain:    return profile.weightKg * 1.5
        case .performance: return profile.weightKg * 2.0
        }
    }

    var waterProgress: Double   { min(todayNutrition.waterMl  / dailyWaterGoalMl,    1.0) }
    var proteinProgress: Double { min(todayNutrition.proteinG / dailyProteinGoalG,   1.0) }

    var favoriteFitRecipes: [FitRecipe] { fitRecipes.filter { $0.isFavorite } }

    // MARK: - Actions (Workouts)

    func toggleExercise(id: UUID) {
        if let idx = exercises.firstIndex(where: { $0.id == id }) {
            exercises[idx].isCompleted.toggle()
        }
    }

    func addExercise(name: String, sets: Int, reps: Int) {
        exercises.append(WorkoutExercise(name: name, sets: sets, reps: reps))
    }

    func finishWorkout() {
        workoutHistory.append(WorkoutSession(exercises: exercises))
        // Reset completion flags; keep the exercise list for next session
        exercises = exercises.map {
            WorkoutExercise(name: $0.name, sets: $0.sets, reps: $0.reps)
        }
    }

    // MARK: - Actions (Nutrition)

    func addWater(ml: Double) {
        todayNutrition.waterMl = min(todayNutrition.waterMl + ml, dailyWaterGoalMl * 2)
    }

    func logNutrition(protein: Double, carbs: Double, fats: Double, calories: Double) {
        todayNutrition.proteinG  += protein
        todayNutrition.carbsG    += carbs
        todayNutrition.fatsG     += fats
        todayNutrition.calories  += calories
    }

    func resetNutrition() {
        todayNutrition = NutritionEntry()
        UserDefaults.standard.set(Date(), forKey: Keys.todayNutritionDate)
    }

    // MARK: - Actions (Recipes)

    func toggleRecipeFavorite(id: UUID) {
        if let idx = fitRecipes.firstIndex(where: { $0.id == id }) {
            fitRecipes[idx].isFavorite.toggle()
        }
    }

    // MARK: - Reset (Settings screen)

    func resetAllData() {
        [Keys.profile, Keys.exercises, Keys.workoutHistory,
         Keys.todayNutrition, Keys.todayNutritionDate, Keys.fitRecipes]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.removeObject(forKey: Keys.hasCompletedOnboarding)

        profile                 = UserProfile()
        hasCompletedOnboarding  = false
        exercises               = [
            WorkoutExercise(name: "Push-ups",  sets: 3, reps: 15),
            WorkoutExercise(name: "Squats",    sets: 4, reps: 12),
            WorkoutExercise(name: "Pull-ups",  sets: 3, reps: 8),
            WorkoutExercise(name: "Plank",     sets: 3, reps: 60),
            WorkoutExercise(name: "Lunges",    sets: 3, reps: 12),
            WorkoutExercise(name: "Crunches",  sets: 3, reps: 20),
        ]
        workoutHistory          = []
        todayNutrition          = NutritionEntry()
        fitRecipes              = FitRecipe.database
    }
}