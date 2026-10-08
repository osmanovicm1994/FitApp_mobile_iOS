// AppState.swift
// Central state object for FitApp: ALL state + business logic lives here.
//
// PERSISTENCE (schema v1): everything is saved as ONE versioned JSON file through
// PersistenceStore (see PersistenceStore.swift). UserDefaults is only read once, to migrate
// data written by older app versions (see LegacyKeys below).
//
// Saving is debounced (400 ms) and flushed whenever the app leaves the foreground
// (FitAppApp calls flush()), so a burst of changes costs one disk write.
//
// RULES for changing persisted models (UserProfile, WorkoutExercise, WorkoutSession,
// MealEntry, AppData):
//   • New fields must be optional or have a default AND be decoded with decodeIfPresent
//     (AppData) so old backups/files keep loading.
//   • Bump PersistenceStore.currentSchemaVersion only for breaking layout changes.

import SwiftUI
import Combine
import os

// MARK: - Legacy UserDefaults keys (read once to migrate older installs; never written)

enum LegacyKeys {
    static let profile                = "app.profile"
    static let hasCompletedOnboarding = "app.onboarding"
    static let isDarkMode             = "app.darkMode"
    static let exercises              = "app.exercises"
    static let workoutHistory         = "app.workoutHistory"
    static let todayNutrition         = "app.todayNutrition"
    static let todayNutritionDate     = "app.todayNutrition.date"
    static let fitRecipes             = "app.fitRecipes.favorites"

    static let all: [String] = [
        profile, hasCompletedOnboarding, isDarkMode, exercises,
        workoutHistory, todayNutrition, todayNutritionDate, fitRecipes
    ]
}

/// Shape of the favourites list written by older versions (UserDefaults).
struct LegacyRecipeFavoriteFlag: Codable {
    let title: String
    let isFavorite: Bool
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

    var completedCount: Int { exercises.filter(\.isCompleted).count }
}

/// Aggregate of one day's nutrition. Computed by AppState from the meal log; not stored.
struct NutritionEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var waterMl: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatsG: Double = 0
    var calories: Double = 0
}

/// One logged meal or snack. The meal log is the source of truth for nutrition history.
struct MealEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var name: String = "Meal"
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatsG: Double = 0
    var calories: Double = 0
    /// Where the entry came from: "manual", "quick", "recipe", "migrated" (later: "photo").
    var source: String = "manual"
}

// MARK: - AppData (the one thing that is saved / backed up / restored)

struct AppData: Codable {
    var schemaVersion: Int = PersistenceStore.currentSchemaVersion
    var savedAt: Date = Date()
    var profile: UserProfile = UserProfile()
    var hasCompletedOnboarding: Bool = false
    var isDarkMode: Bool = true
    var exercises: [WorkoutExercise] = AppData.starterExercises
    var workoutHistory: [WorkoutSession] = []
    var meals: [MealEntry] = []
    /// Water in ml per calendar day, keyed "yyyy-MM-dd".
    var waterByDay: [String: Double] = [:]
    /// nil = never saved yet, so the recipe database defaults apply.
    var favoriteRecipeTitles: [String]? = nil

    init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, savedAt, profile, hasCompletedOnboarding, isDarkMode
        case exercises, workoutHistory, meals, waterByDay, favoriteRecipeTitles
    }

    /// Tolerant decoding: every field is optional in the file, so older files/backups keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion          = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? PersistenceStore.currentSchemaVersion
        savedAt                = try c.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        profile                = try c.decodeIfPresent(UserProfile.self, forKey: .profile) ?? UserProfile()
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        isDarkMode             = try c.decodeIfPresent(Bool.self, forKey: .isDarkMode) ?? true
        exercises              = try c.decodeIfPresent([WorkoutExercise].self, forKey: .exercises) ?? AppData.starterExercises
        workoutHistory         = try c.decodeIfPresent([WorkoutSession].self, forKey: .workoutHistory) ?? []
        meals                  = try c.decodeIfPresent([MealEntry].self, forKey: .meals) ?? []
        waterByDay             = try c.decodeIfPresent([String: Double].self, forKey: .waterByDay) ?? [:]
        favoriteRecipeTitles   = try c.decodeIfPresent([String].self, forKey: .favoriteRecipeTitles)
    }

    static var starterExercises: [WorkoutExercise] {
        [
            WorkoutExercise(name: "Push-ups",  sets: 3, reps: 15),
            WorkoutExercise(name: "Squats",    sets: 4, reps: 12),
            WorkoutExercise(name: "Pull-ups",  sets: 3, reps: 8),
            WorkoutExercise(name: "Plank",     sets: 3, reps: 60),
            WorkoutExercise(name: "Lunges",    sets: 3, reps: 12),
            WorkoutExercise(name: "Crunches",  sets: 3, reps: 20),
        ]
    }

    /// Clamps values to sane ranges. Protects the UI from corrupt, edited or very old data
    /// (for example a NaN or a huge number would crash `Int(value)` conversions).
    mutating func sanitize() {
        profile.age = min(max(profile.age, ProfileLimits.age.lowerBound), ProfileLimits.age.upperBound)
        profile.weightKg = AppData.clamp(profile.weightKg, ProfileLimits.weightKg, fallback: 70)
        profile.heightCm = AppData.clamp(profile.heightCm, ProfileLimits.heightCm, fallback: 170)

        meals = meals.map { (meal: MealEntry) -> MealEntry in
            var m = meal
            m.proteinG = AppData.clamp(m.proteinG, 0...20000, fallback: 0)
            m.carbsG   = AppData.clamp(m.carbsG,   0...20000, fallback: 0)
            m.fatsG    = AppData.clamp(m.fatsG,    0...20000, fallback: 0)
            m.calories = AppData.clamp(m.calories, 0...20000, fallback: 0)
            return m
        }

        waterByDay = waterByDay.mapValues { AppData.clamp($0, 0...10000, fallback: 0) }

        exercises = exercises.map { (exercise: WorkoutExercise) -> WorkoutExercise in
            var e = exercise
            e.sets = min(max(e.sets, 1), 99)
            e.reps = min(max(e.reps, 1), 999)
            return e
        }
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - AppState

final class AppState: ObservableObject {

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FitApp",
                                    category: "AppState")

    private let store: PersistenceStore
    private var persistenceEnabled = true
    private var isDirty = false
    private var saveTask: Task<Void, Never>?

    // ── Profile ───────────────────────────────────────────────────────────
    @Published var profile: UserProfile {
        didSet { scheduleSave() }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { scheduleSave() }
    }

    // ── Theme ─────────────────────────────────────────────────────────────
    @Published var isDarkMode: Bool {
        didSet { scheduleSave() }
    }

    // ── Workout ───────────────────────────────────────────────────────────
    @Published var exercises: [WorkoutExercise] {
        didSet { scheduleSave() }
    }

    @Published var workoutHistory: [WorkoutSession] {
        didSet { scheduleSave() }
    }

    // ── Nutrition ─────────────────────────────────────────────────────────
    /// Every meal ever logged (history). Use `todayMeals` / `todayNutrition` for today's view.
    @Published private(set) var meals: [MealEntry] {
        didSet { scheduleSave() }
    }

    /// Water in ml per calendar day, keyed "yyyy-MM-dd".
    @Published private(set) var waterByDay: [String: Double] {
        didSet { scheduleSave() }
    }

    // ── Recipes ───────────────────────────────────────────────────────────
    @Published var fitRecipes: [FitRecipe] {
        didSet { scheduleSave() }
    }

    // ── Storage status ────────────────────────────────────────────────────
    /// Set when saved data had a problem (unreadable, recovered, or cannot be saved).
    /// RootView shows it once in an alert.
    @Published var storageWarning: String? = nil

    // MARK: - init

    init() {
        let store = PersistenceStore()
        self.store = store

        var data = AppData()
        var warning: String? = nil
        var savingAllowed = true
        var needsRewrite = false

        switch store.load() {
        case .empty:
            break
        case .loaded(let loaded):
            data = loaded
        case .migrated(let migrated):
            data = migrated
        case .recovered(let recovered, let message):
            data = recovered
            warning = message
            needsRewrite = true
        case .failed(let message, let allowSaving):
            warning = message
            savingAllowed = allowSaving
        }

        profile                = data.profile
        hasCompletedOnboarding = data.hasCompletedOnboarding
        isDarkMode             = data.isDarkMode
        exercises              = data.exercises
        workoutHistory         = data.workoutHistory
        meals                  = data.meals
        waterByDay             = data.waterByDay

        // Recipes — start from the full database, then restore the favourites.
        let favorites: Set<String>? = data.favoriteRecipeTitles.map { Set($0) }
        fitRecipes = FitRecipe.database.map { (recipe: FitRecipe) -> FitRecipe in
            var r = recipe
            if let favorites {
                r.isFavorite = favorites.contains(r.title)
            }
            return r
        }

        storageWarning     = warning
        persistenceEnabled = savingAllowed

        if needsRewrite {
            isDirty = true
            scheduleSave()
        }
    }

    // MARK: - Saving

    private func snapshot() -> AppData {
        var data = AppData()
        data.savedAt                = Date()
        data.profile                = profile
        data.hasCompletedOnboarding = hasCompletedOnboarding
        data.isDarkMode             = isDarkMode
        data.exercises              = exercises
        data.workoutHistory         = workoutHistory
        data.meals                  = meals
        data.waterByDay             = waterByDay
        data.favoriteRecipeTitles   = fitRecipes.filter { $0.isFavorite }.map { $0.title }
        return data
    }

    private func scheduleSave() {
        guard persistenceEnabled else { return }
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            self?.persistNow()
        }
    }

    /// Writes any pending changes immediately. Called when the app leaves the foreground.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        persistNow()
    }

    private func persistNow() {
        guard persistenceEnabled, isDirty else { return }
        do {
            try store.save(snapshot())
            isDirty = false
        } catch {
            Self.log.error("Could not save app data: \(error.localizedDescription, privacy: .public)")
            if storageWarning == nil {
                storageWarning = "FitApp could not save your latest changes (is the device storage full?). We will keep trying."
            }
        }
    }

    /// Called when the app returns to the foreground: re-evaluates "today" after midnight.
    func handleBecameActive() {
        objectWillChange.send()
    }

    // MARK: - Day helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "yyyy-MM-dd" key for a date in the user's current time zone.
    static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
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

    /// Meals logged today, newest first.
    var todayMeals: [MealEntry] {
        let calendar = Calendar.current
        let now = Date()
        return meals
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date > $1.date }
    }

    /// Today's totals (water + all macros), derived from the meal log.
    var todayNutrition: NutritionEntry {
        var entry = NutritionEntry()
        for meal in todayMeals {
            entry.proteinG += meal.proteinG
            entry.carbsG   += meal.carbsG
            entry.fatsG    += meal.fatsG
            entry.calories += meal.calories
        }
        entry.waterMl = waterByDay[Self.dayKey(for: Date())] ?? 0
        return entry
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        exercises.append(WorkoutExercise(name: String(trimmed.prefix(60)),
                                         sets: min(max(sets, 1), 99),
                                         reps: min(max(reps, 1), 999)))
    }

    /// Saves today's session to the history and resets the completion flags.
    /// Returns false (and changes nothing) when no exercise is marked as done.
    @discardableResult
    func finishWorkout() -> Bool {
        guard completedExercisesCount > 0 else { return false }
        workoutHistory.append(WorkoutSession(exercises: exercises))
        // Reset completion flags; keep the exercise list for next session
        exercises = exercises.map {
            WorkoutExercise(name: $0.name, sets: $0.sets, reps: $0.reps)
        }
        return true
    }

    // MARK: - Actions (Nutrition)

    func addWater(ml: Double) {
        guard ml.isFinite, ml > 0 else { return }
        let key = Self.dayKey(for: Date())
        let current = waterByDay[key] ?? 0
        waterByDay[key] = min(current + ml, dailyWaterGoalMl * 2)
    }

    /// Adds a meal to today's log. Ignores invalid input (negative, non-finite, absurdly large, or all zero).
    func logNutrition(protein: Double, carbs: Double, fats: Double, calories: Double,
                      name: String = "Meal", source: String = "manual") {
        let values = [protein, carbs, fats, calories]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 20000 }),
              values.contains(where: { $0 > 0 }) else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        meals.append(MealEntry(name: trimmed.isEmpty ? "Meal" : String(trimmed.prefix(60)),
                               proteinG: protein,
                               carbsG: carbs,
                               fatsG: fats,
                               calories: calories,
                               source: source))
    }

    func removeMeal(id: UUID) {
        meals.removeAll { $0.id == id }
    }

    /// Clears today's meals and today's water. Earlier days are kept.
    func resetNutrition() {
        let calendar = Calendar.current
        let now = Date()
        meals.removeAll { calendar.isDate($0.date, inSameDayAs: now) }
        waterByDay[Self.dayKey(for: now)] = nil
    }

    // MARK: - Actions (Recipes)

    func toggleRecipeFavorite(id: UUID) {
        if let idx = fitRecipes.firstIndex(where: { $0.id == id }) {
            fitRecipes[idx].isFavorite.toggle()
        }
    }

    // MARK: - Reset (Settings screen)

    /// Settings "Reset Profile": clears the profile and shows onboarding again. Workouts and meals are kept.
    func resetProfile() {
        profile = UserProfile()
        hasCompletedOnboarding = false
    }

    /// Settings "Reset All Data": clears workouts, workout history and ALL nutrition history.
    /// The profile and favourite recipes are kept.
    func resetTrackingData() {
        exercises = AppData.starterExercises
        workoutHistory = []
        meals = []
        waterByDay = [:]
    }

    /// Deletes everything (profile, workouts, nutrition, favourites and the stored files) and
    /// returns the app to its first-launch state. The dark-mode choice is kept.
    func resetAllData() {
        saveTask?.cancel()
        saveTask = nil
        store.deleteAllStoredData()

        persistenceEnabled = true
        storageWarning = nil

        profile                = UserProfile()
        hasCompletedOnboarding = false
        exercises              = AppData.starterExercises
        workoutHistory         = []
        meals                  = []
        waterByDay             = [:]
        fitRecipes             = FitRecipe.database

        isDirty = true
        flush()
    }
}
