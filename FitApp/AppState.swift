// AppState.swift
// Central state object for FitApp: ALL state + business logic lives here.
//
// PERSISTENCE (schema v1): everything is saved as ONE versioned JSON file through
// PersistenceStore (see PersistenceStore.swift). UserDefaults is not used for app data.
//
// Saving is debounced (400 ms) and flushed whenever the app leaves the foreground
// (FitAppApp calls flush()), so a burst of changes costs one disk write.
//
// RULES for changing persisted models (UserProfile, WorkoutExercise, WorkoutSession,
// MealEntry, CustomFood, WeightEntry, BodyMeasurement, AppData):
//   • New fields must be optional or have a default AND be decoded with decodeIfPresent
//     (AppData) so old backups/files keep loading.
//   • Bump PersistenceStore.currentSchemaVersion only for breaking layout changes.

import SwiftUI
import UIKit
import Combine
import os

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
    var repRange: String? = nil

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
    /// Where the entry came from: "manual", "quick", "recipe", "custom", "custom_meal", "migrated" (later: "photo").
    var source: String = "manual"
}

/// A food the user created ("My Foods"). All values are for ONE serving.
struct CustomFood: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Free text describing one serving, e.g. "100 g", "1 slice", "1 cup".
    var servingLabel: String = "1 serving"
    var calories: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatsG: Double = 0

    /// Upper limit per serving; with the 4x serving multiplier this stays below the 20000 meal limit.
    static let maxPerServing: Double = 5000
    static let maxCount: Int = 200

    /// Atwater estimate: 4 kcal per g of protein and carbs, 9 kcal per g of fat.
    static func estimatedCalories(protein: Double, carbs: Double, fats: Double) -> Double {
        (protein * 4 + carbs * 4 + fats * 9).rounded()
    }
}

/// One ingredient of a custom meal. It is a COPY of the food's values (per ONE serving), so editing or
/// deleting the food in My Foods later never changes a saved meal. `quantity` counts servings.
struct CustomMealItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var servingLabel: String = "1 serving"
    var quantity: Double = 1
    var calories: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatsG: Double = 0

    /// Allowed number of servings of one ingredient.
    static let quantityRange: ClosedRange<Double> = 0.25...20

    var totalCalories: Double { calories * quantity }
    var totalProteinG: Double { proteinG * quantity }
    var totalCarbsG: Double   { carbsG * quantity }
    var totalFatsG: Double    { fatsG * quantity }
}

/// A meal the user built from several foods ("My Meals"). Totals are always computed from the ingredients.
struct CustomMeal: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var items: [CustomMealItem] = []

    static let maxCount: Int = 100
    static let maxItems: Int = 30

    var totalCalories: Double { items.reduce(0) { $0 + $1.totalCalories } }
    var totalProteinG: Double { items.reduce(0) { $0 + $1.totalProteinG } }
    var totalCarbsG: Double   { items.reduce(0) { $0 + $1.totalCarbsG } }
    var totalFatsG: Double    { items.reduce(0) { $0 + $1.totalFatsG } }
}

/// One weigh-in. The log keeps at most one entry per calendar day.
struct WeightEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var kg: Double
}

/// The body measurements the user can track. Raw values are stored in the data file: never rename them.
enum BodyMeasurementType: String, CaseIterable, Codable, Identifiable {
    case neck, shoulders, chest, waist, hips, arm, forearm, wrist, thigh, calf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck:      return "Neck"
        case .shoulders: return "Shoulders"
        case .chest:     return "Chest"
        case .waist:     return "Waist"
        case .hips:      return "Hips"
        case .arm:       return "Arm (biceps)"
        case .forearm:   return "Forearm"
        case .wrist:     return "Wrist"
        case .thigh:     return "Thigh"
        case .calf:      return "Calf"
        }
    }

    /// Short "how to measure" hint shown on the detail and log screens.
    var hint: String {
        switch self {
        case .neck:      return "Around the middle of the neck, just below the Adam's apple."
        case .shoulders: return "Around the widest point of the shoulders, feet together and arms relaxed."
        case .chest:     return "Around the fullest part of the chest, under the arms, after a normal exhale."
        case .waist:     return "Around the narrowest part of the torso (usually just above the navel), after a normal exhale."
        case .hips:      return "Around the widest part of the hips and buttocks."
        case .arm:       return "Around the middle of the upper arm. Decide on relaxed or flexed and stay consistent."
        case .forearm:   return "Around the widest part of the forearm, just below the elbow."
        case .wrist:     return "Around the wrist, just above the wrist bone."
        case .thigh:     return "Around the widest part of the upper thigh."
        case .calf:      return "Around the widest part of the calf."
        }
    }
}

/// One body measurement in centimetres. `kind` holds a BodyMeasurementType raw value; it is a plain
/// string on purpose so data written by a newer app version (with more types) still loads.
struct BodyMeasurement: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var kind: String
    var cm: Double

    var type: BodyMeasurementType? { BodyMeasurementType(rawValue: kind) }
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
    /// Reusable custom workouts (templates) the user built.
    var savedWorkouts: [SavedWorkout] = []
    /// Saved workout that is loaded on the main page when the app starts (nil = none).
    var defaultWorkoutID: UUID? = nil
    /// Saved workout currently loaded on the main page (nil = quick/starter workout).
    var activeWorkoutID: UUID? = nil
    /// True when the user deliberately chose the quick workout, so the default is not re-applied at launch.
    var freeWorkoutChosen: Bool = false
    /// Foods the user created ("My Foods").
    var customFoods: [CustomFood] = []
    /// Meals built from several foods ("My Meals").
    var customMeals: [CustomMeal] = []
    /// Weigh-ins, oldest first, at most one per day.
    var weightLog: [WeightEntry] = []
    /// Body measurements (wrist, arm, waist, ...), any order.
    var bodyMeasurements: [BodyMeasurement] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, savedAt, profile, hasCompletedOnboarding, isDarkMode
        case exercises, workoutHistory, meals, waterByDay, favoriteRecipeTitles
        case savedWorkouts, defaultWorkoutID, activeWorkoutID, freeWorkoutChosen
        case customFoods, customMeals, weightLog, bodyMeasurements
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
        savedWorkouts          = try c.decodeIfPresent([SavedWorkout].self, forKey: .savedWorkouts) ?? []
        defaultWorkoutID       = try c.decodeIfPresent(UUID.self, forKey: .defaultWorkoutID)
        activeWorkoutID        = try c.decodeIfPresent(UUID.self, forKey: .activeWorkoutID)
        freeWorkoutChosen      = try c.decodeIfPresent(Bool.self, forKey: .freeWorkoutChosen) ?? false
        customFoods            = try c.decodeIfPresent([CustomFood].self, forKey: .customFoods) ?? []
        customMeals            = try c.decodeIfPresent([CustomMeal].self, forKey: .customMeals) ?? []
        weightLog              = try c.decodeIfPresent([WeightEntry].self, forKey: .weightLog) ?? []
        bodyMeasurements       = try c.decodeIfPresent([BodyMeasurement].self, forKey: .bodyMeasurements) ?? []
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

        savedWorkouts = savedWorkouts.map { (workout: SavedWorkout) -> SavedWorkout in
            var w = workout
            w.exercises = w.exercises.map { (exercise: SavedWorkoutExercise) -> SavedWorkoutExercise in
                var e = exercise
                e.sets = min(max(e.sets, 1), 99)
                e.reps = min(max(e.reps, 1), 999)
                return e
            }
            return w
        }
        // Never point at a workout that no longer exists.
        if let id = defaultWorkoutID, !savedWorkouts.contains(where: { $0.id == id }) {
            defaultWorkoutID = nil
        }
        if let id = activeWorkoutID, !savedWorkouts.contains(where: { $0.id == id }) {
            activeWorkoutID = nil
        }

        // Custom foods: drop nameless ones, clamp values, cap the count.
        let cleanedFoods = customFoods.compactMap { (food: CustomFood) -> CustomFood? in
            var f = food
            let name = f.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            f.name = String(name.prefix(60))
            let serving = f.servingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            f.servingLabel = serving.isEmpty ? "1 serving" : String(serving.prefix(40))
            f.calories = AppData.clamp(f.calories, 0...CustomFood.maxPerServing, fallback: 0)
            f.proteinG = AppData.clamp(f.proteinG, 0...CustomFood.maxPerServing, fallback: 0)
            f.carbsG   = AppData.clamp(f.carbsG,   0...CustomFood.maxPerServing, fallback: 0)
            f.fatsG    = AppData.clamp(f.fatsG,    0...CustomFood.maxPerServing, fallback: 0)
            return f
        }
        customFoods = Array(cleanedFoods.prefix(CustomFood.maxCount))

        // Custom meals: drop nameless or empty ones, clamp ingredient values, cap the counts.
        let cleanedMeals = customMeals.compactMap { (meal: CustomMeal) -> CustomMeal? in
            var m = meal
            let mealName = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !mealName.isEmpty else { return nil }
            m.name = String(mealName.prefix(60))
            let cleanedItems = m.items.compactMap { (item: CustomMealItem) -> CustomMealItem? in
                var i = item
                let itemName = i.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !itemName.isEmpty else { return nil }
                i.name = String(itemName.prefix(60))
                let serving = i.servingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                i.servingLabel = serving.isEmpty ? "1 serving" : String(serving.prefix(40))
                i.quantity = AppData.clamp(i.quantity, CustomMealItem.quantityRange, fallback: 1)
                i.calories = AppData.clamp(i.calories, 0...CustomFood.maxPerServing, fallback: 0)
                i.proteinG = AppData.clamp(i.proteinG, 0...CustomFood.maxPerServing, fallback: 0)
                i.carbsG   = AppData.clamp(i.carbsG,   0...CustomFood.maxPerServing, fallback: 0)
                i.fatsG    = AppData.clamp(i.fatsG,    0...CustomFood.maxPerServing, fallback: 0)
                return i
            }
            m.items = Array(cleanedItems.prefix(CustomMeal.maxItems))
            return m.items.isEmpty ? nil : m
        }
        customMeals = Array(cleanedMeals.prefix(CustomMeal.maxCount))

        // Weight log: drop corrupt entries, keep oldest first.
        weightLog = weightLog
            .filter { (entry: WeightEntry) -> Bool in
                entry.kg.isFinite && ProfileLimits.weightKg.contains(entry.kg)
            }
            .sorted { $0.date < $1.date }

        // Measurements: drop corrupt values. Unknown `kind` values are kept (written by a newer app).
        bodyMeasurements = bodyMeasurements.filter { (m: BodyMeasurement) -> Bool in
            m.cm.isFinite && MeasurementLimits.cm.contains(m.cm)
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
        didSet {
            scheduleSave()
            // Finishing onboarding creates the first weigh-in from the weight the user just entered.
            if hasCompletedOnboarding && !oldValue { syncWeightLogWithProfile() }
        }
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

    // ── Custom (saved) workouts ───────────────────────────────────────────
    @Published private(set) var savedWorkouts: [SavedWorkout] {
        didSet { scheduleSave() }
    }

    /// Loaded on the main page at launch. Changeable any time in My Workouts.
    @Published private(set) var defaultWorkoutID: UUID? {
        didSet { scheduleSave() }
    }

    /// The saved workout currently shown on the main page (nil = quick workout).
    @Published private(set) var activeWorkoutID: UUID? {
        didSet { scheduleSave() }
    }

    private var freeWorkoutChosen: Bool {
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

    /// Meals the user built from several foods ("My Meals"), sorted by name.
    @Published private(set) var customMeals: [CustomMeal] {
        didSet { scheduleSave() }
    }

    /// Foods the user created ("My Foods"), sorted by name.
    @Published private(set) var customFoods: [CustomFood] {
        didSet { scheduleSave() }
    }

    // ── Body tracking ─────────────────────────────────────────────────────
    /// Weigh-ins, oldest first, at most one per calendar day.
    @Published private(set) var weightLog: [WeightEntry] {
        didSet { scheduleSave() }
    }

    /// Body measurements (wrist, arm, waist, ...).
    @Published private(set) var bodyMeasurements: [BodyMeasurement] {
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

    // ── Google backup (device-local status; the secrets live in the Keychain) ──
    @Published private(set) var cloudEmail: String? = nil
    @Published private(set) var lastBackupAt: Date? = nil
    @Published private(set) var autoBackupEnabled: Bool = false
    @Published private(set) var cloudBusy: Bool = false
    /// Last backup/restore error or hint, shown in Settings / onboarding.
    @Published var cloudMessage: String? = nil
    /// A backup found in the cloud that waits for the user's decision (RootView shows a sheet).
    @Published var restoreOffer: CloudRestoreOffer? = nil

    private let cloudAuth = GoogleAuthService()
    private lazy var drive = DriveBackupService(auth: cloudAuth)
    /// True when there are local changes that are not in the cloud backup yet.
    private var cloudDirty = false

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
        case .recovered(let recovered, let message):
            data = recovered
            warning = message
            needsRewrite = true
        case .failed(let message, let allowSaving):
            warning = message
            savingAllowed = allowSaving
        }

        // Make the four starter plans available to new and existing users.
        // Preserve any workouts they have already created.
        if data.savedWorkouts.isEmpty {
            data.savedWorkouts = SavedWorkout.builtInDefaults
            if data.defaultWorkoutID == nil {
                data.defaultWorkoutID = SavedWorkout.builtInDefaults.first?.id
            }
            needsRewrite = true
        }

        profile                = data.profile
        hasCompletedOnboarding = data.hasCompletedOnboarding
        isDarkMode             = data.isDarkMode
        // Default workout: shown on the main page at launch, unless the user picked something else
        // or is in the middle of a session (ticked exercises are never overwritten).
        var startExercises = data.exercises
        var startActiveID  = data.activeWorkoutID
        if startActiveID == nil,
           !data.freeWorkoutChosen,
           let defaultID = data.defaultWorkoutID,
           let preset = data.savedWorkouts.first(where: { $0.id == defaultID }),
           !startExercises.contains(where: \.isCompleted) {
            startExercises = preset.asWorkoutExercises
            startActiveID  = defaultID
            needsRewrite   = true
        }

        exercises              = startExercises
        workoutHistory         = data.workoutHistory
        meals                  = data.meals
        waterByDay             = data.waterByDay
        savedWorkouts          = data.savedWorkouts
        defaultWorkoutID       = data.defaultWorkoutID
        activeWorkoutID        = startActiveID
        freeWorkoutChosen      = data.freeWorkoutChosen
        customFoods            = data.customFoods
        weightLog              = data.weightLog
        bodyMeasurements       = data.bodyMeasurements
        customMeals            = data.customMeals

        // Recipes — start from the full database, then restore the favourites.
        fitRecipes = Self.makeRecipes(favoriteTitles: data.favoriteRecipeTitles)

        storageWarning     = warning
        persistenceEnabled = savingAllowed

        if needsRewrite {
            isDirty = true
            scheduleSave()
        }

        // Existing users: the weight they already entered becomes their first weigh-in.
        syncWeightLogWithProfile()

        refreshCloudStatus()
    }

    /// The recipe database with the saved favourites applied (nil = keep database defaults).
    private static func makeRecipes(favoriteTitles: [String]?) -> [FitRecipe] {
        let favorites: Set<String>? = favoriteTitles.map { Set($0) }
        return FitRecipe.database.map { (recipe: FitRecipe) -> FitRecipe in
            var r = recipe
            if let favorites {
                r.isFavorite = favorites.contains(r.title)
            }
            return r
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
        data.savedWorkouts          = savedWorkouts
        data.defaultWorkoutID       = defaultWorkoutID
        data.activeWorkoutID        = activeWorkoutID
        data.freeWorkoutChosen      = freeWorkoutChosen
        data.customFoods            = customFoods
        data.customMeals            = customMeals
        data.weightLog              = weightLog
        data.bodyMeasurements       = bodyMeasurements
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
            cloudDirty = true
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

    /// Estimated daily calorie target. ROUGH ESTIMATE, not medical advice.
    /// Mifflin-St Jeor with the male (+5) and female (-161) constants averaged to -78, because FitApp
    /// deliberately does not collect sex or gender. x1.4 assumes light activity, then adjusted by goal.
    var dailyCalorieGoal: Double {
        let bmr = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) - 78
        let maintenance = bmr * 1.4
        let factor: Double
        switch profile.goal {
        case .loseWeight:  factor = 0.85
        case .gainMuscle:  factor = 1.10
        case .maintain:    factor = 1.00
        case .performance: factor = 1.05
        }
        let rounded = (maintenance * factor / 10).rounded() * 10
        return min(max(rounded, 1200), 5000)
    }

    /// ~27% of calories from fat.
    var dailyFatGoalG: Double {
        (dailyCalorieGoal * 0.27 / 9).rounded()
    }

    /// Whatever calories remain after protein and fat.
    var dailyCarbsGoalG: Double {
        let remaining = dailyCalorieGoal - dailyProteinGoalG * 4 - dailyFatGoalG * 9
        return max((remaining / 4).rounded(), 50)
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

    /// Latest weigh-in, or the profile weight when nothing was logged yet.
    var currentWeightKg: Double { weightLog.last?.kg ?? profile.weightKg }

    /// Total gain (+) or loss (-) from the first to the latest weigh-in. nil with fewer than two weigh-ins.
    var totalWeightChangeKg: Double? {
        guard weightLog.count >= 2, let first = weightLog.first, let last = weightLog.last else { return nil }
        return NumberParsing.roundedToTenth(last.kg - first.kg)
    }

    /// Gain (+) or loss (-) over the last `days` days: latest weigh-in versus the newest one at or before
    /// that cutoff. nil when there is no recent weigh-in or no older one to compare with.
    func weightChangeKg(overDays days: Int, now: Date = Date()) -> Double? {
        guard let latest = weightLog.last,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now),
              latest.date > cutoff,
              let baseline = weightLog.last(where: { $0.date <= cutoff }) else { return nil }
        return NumberParsing.roundedToTenth(latest.kg - baseline.kg)
    }

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
            WorkoutExercise(name: $0.name, sets: $0.sets, reps: $0.reps, repRange: $0.repRange)
        }
        return true
    }

    // MARK: - Actions (Saved workouts)

    /// The saved workout currently loaded on the main page, if any.
    var activeWorkout: SavedWorkout? {
        guard let id = activeWorkoutID else { return nil }
        return savedWorkouts.first(where: { $0.id == id })
    }

    /// Creates or updates a saved workout. Returns false (and saves nothing) if it has no named exercise.
    @discardableResult
    func saveWorkout(_ workout: SavedWorkout) -> Bool {
        var w = workout
        let trimmedName = w.name.trimmingCharacters(in: .whitespacesAndNewlines)
        w.name = trimmedName.isEmpty ? "My Workout" : String(trimmedName.prefix(40))
        w.exercises = w.exercises.compactMap { (exercise: SavedWorkoutExercise) -> SavedWorkoutExercise? in
            let n = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { return nil }
            var e = exercise
            e.name = String(n.prefix(60))
            e.sets = min(max(e.sets, 1), 99)
            e.reps = min(max(e.reps, 1), 999)
            return e
        }
        guard !w.exercises.isEmpty else { return false }

        if let idx = savedWorkouts.firstIndex(where: { $0.id == w.id }) {
            savedWorkouts[idx] = w
        } else {
            savedWorkouts.append(w)
        }
        return true
    }

    /// Saves the exercises currently on the main page as a new workout and marks it as the active one.
    @discardableResult
    func saveCurrentAsWorkout(name: String) -> Bool {
        let template = SavedWorkout(name: name,
                                    exercises: exercises.map {
                                        SavedWorkoutExercise(name: $0.name, sets: $0.sets, reps: $0.reps, repRange: $0.repRange)
                                    })
        guard saveWorkout(template) else { return false }
        activeWorkoutID = template.id
        freeWorkoutChosen = false
        return true
    }

    func deleteWorkout(id: UUID) {
        savedWorkouts.removeAll { $0.id == id }
        if defaultWorkoutID == id { defaultWorkoutID = nil }
        if activeWorkoutID == id { activeWorkoutID = nil }
    }

    /// Marks a workout as the one loaded at launch. Pass nil to have no default.
    func setDefaultWorkout(id: UUID?) {
        if let id, !savedWorkouts.contains(where: { $0.id == id }) { return }
        defaultWorkoutID = id
    }

    /// Loads a saved workout onto the main page (fresh, nothing ticked off).
    @discardableResult
    func startWorkout(id: UUID) -> Bool {
        guard let workout = savedWorkouts.first(where: { $0.id == id }) else { return false }
        exercises = workout.asWorkoutExercises
        activeWorkoutID = id
        freeWorkoutChosen = false
        return true
    }

    /// Goes back to the quick workout (starter list) and keeps the default from re-applying at launch.
    func useFreeWorkout() {
        exercises = AppData.starterExercises
        activeWorkoutID = nil
        freeWorkoutChosen = true
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

    // MARK: - Actions (Custom foods)

    /// True when another custom food already uses this name (case-insensitive).
    func customFoodNameExists(_ name: String, excluding id: UUID? = nil) -> Bool {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return customFoods.contains { $0.id != id && $0.name.lowercased() == key }
    }

    /// Creates or updates a custom food. Returns false (and saves nothing) for an empty or duplicate name,
    /// out-of-range or all-zero values, or when the 200-food limit is reached.
    @discardableResult
    func saveCustomFood(_ food: CustomFood) -> Bool {
        var f = food
        let trimmedName = f.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        f.name = String(trimmedName.prefix(60))
        let serving = f.servingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        f.servingLabel = serving.isEmpty ? "1 serving" : String(serving.prefix(40))

        let values = [f.calories, f.proteinG, f.carbsG, f.fatsG]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= CustomFood.maxPerServing }),
              values.contains(where: { $0 > 0 }) else { return false }
        guard !customFoodNameExists(f.name, excluding: f.id) else { return false }

        var list = customFoods
        if let idx = list.firstIndex(where: { $0.id == f.id }) {
            list[idx] = f
        } else {
            guard list.count < CustomFood.maxCount else { return false }
            list.append(f)
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        customFoods = list
        return true
    }

    func deleteCustomFood(id: UUID) {
        customFoods.removeAll { $0.id == id }
    }

    // MARK: - Actions (Custom meals)

    /// True when another custom meal already uses this name (case-insensitive).
    func customMealNameExists(_ name: String, excluding id: UUID? = nil) -> Bool {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return customMeals.contains { $0.id != id && $0.name.lowercased() == key }
    }

    /// Creates or updates a custom meal. Returns false (and saves nothing) for an empty or duplicate name,
    /// no ingredients, out-of-range values, a total above 5000 per value, or when the 100-meal limit is reached.
    @discardableResult
    func saveCustomMeal(_ meal: CustomMeal) -> Bool {
        var m = meal
        let trimmedName = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        m.name = String(trimmedName.prefix(60))

        var cleanItems: [CustomMealItem] = []
        for item in m.items {
            var i = item
            let itemName = i.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemName.isEmpty else { continue }
            i.name = String(itemName.prefix(60))
            let serving = i.servingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            i.servingLabel = serving.isEmpty ? "1 serving" : String(serving.prefix(40))
            guard i.quantity.isFinite, CustomMealItem.quantityRange.contains(i.quantity) else { return false }
            let values = [i.calories, i.proteinG, i.carbsG, i.fatsG]
            guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= CustomFood.maxPerServing }) else { return false }
            cleanItems.append(i)
        }
        guard !cleanItems.isEmpty, cleanItems.count <= CustomMeal.maxItems else { return false }
        m.items = cleanItems

        // Keeps a meal below 5000 so that logging up to 4 servings stays within the 20000 meal limit.
        let totals = [m.totalCalories, m.totalProteinG, m.totalCarbsG, m.totalFatsG]
        guard totals.allSatisfy({ $0.isFinite && $0 <= CustomFood.maxPerServing }),
              totals.contains(where: { $0 > 0 }) else { return false }
        guard !customMealNameExists(m.name, excluding: m.id) else { return false }

        var list = customMeals
        if let idx = list.firstIndex(where: { $0.id == m.id }) {
            list[idx] = m
        } else {
            guard list.count < CustomMeal.maxCount else { return false }
            list.append(m)
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        customMeals = list
        return true
    }

    func deleteCustomMeal(id: UUID) {
        customMeals.removeAll { $0.id == id }
    }

    /// Logs a custom meal as ONE meal entry with the summed calories and macros. `servings` is limited to
    /// 0.25...4. Returns true when a meal was added.
    @discardableResult
    func logCustomMeal(id: UUID, servings: Double = 1) -> Bool {
        guard let meal = customMeals.first(where: { $0.id == id }), servings.isFinite else { return false }
        let s = min(max(servings, 0.25), 4)
        let countBefore = meals.count
        let mealName = s == 1 ? meal.name : "\(meal.name) × \(NumberParsing.display(s))"
        logNutrition(protein: NumberParsing.roundedToTenth(meal.totalProteinG * s),
                     carbs: NumberParsing.roundedToTenth(meal.totalCarbsG * s),
                     fats: NumberParsing.roundedToTenth(meal.totalFatsG * s),
                     calories: (meal.totalCalories * s).rounded(),
                     name: mealName,
                     source: "custom_meal")
        return meals.count > countBefore
    }

    /// Logs a custom food as a meal. `servings` is limited to 0.25...4. Returns true when a meal was added.
    @discardableResult
    func logCustomFood(id: UUID, servings: Double = 1) -> Bool {
        guard let food = customFoods.first(where: { $0.id == id }), servings.isFinite else { return false }
        let s = min(max(servings, 0.25), 4)
        let countBefore = meals.count
        let mealName = s == 1 ? food.name : "\(food.name) × \(NumberParsing.display(s))"
        logNutrition(protein: NumberParsing.roundedToTenth(food.proteinG * s),
                     carbs: NumberParsing.roundedToTenth(food.carbsG * s),
                     fats: NumberParsing.roundedToTenth(food.fatsG * s),
                     calories: (food.calories * s).rounded(),
                     name: mealName,
                     source: "custom")
        return meals.count > countBefore
    }

    // MARK: - Actions (Profile & body tracking)

    /// Saves an edited profile. A changed weight also becomes today's weigh-in, so the weight history
    /// and the profile never disagree.
    func updateProfile(_ newProfile: UserProfile) {
        profile = newProfile
        syncWeightLogWithProfile()
    }

    /// Records the profile weight as today's weigh-in when it differs from the latest logged one
    /// (or nothing is logged yet). Does nothing before onboarding is finished.
    private func syncWeightLogWithProfile() {
        guard hasCompletedOnboarding else { return }
        let w = profile.weightKg
        guard w.isFinite, ProfileLimits.weightKg.contains(w) else { return }
        if let latest = weightLog.last, abs(latest.kg - w) <= 0.05 { return }
        logWeight(kg: w)
    }

    /// Adds a weigh-in (one per calendar day: logging again on the same day replaces it). Future dates are
    /// clamped to now. When it becomes the latest weigh-in the profile weight follows, so calorie and
    /// protein goals use the current weight. Returns false for values outside the allowed range.
    @discardableResult
    func logWeight(kg: Double, date: Date = Date()) -> Bool {
        guard kg.isFinite, ProfileLimits.weightKg.contains(kg) else { return false }
        let rounded = NumberParsing.roundedToTenth(kg)
        let when = min(date, Date())
        let calendar = Calendar.current

        var list = weightLog
        if let idx = list.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: when) }) {
            list[idx].kg = rounded
            list[idx].date = when
        } else {
            list.append(WeightEntry(date: when, kg: rounded))
        }
        list.sort { $0.date < $1.date }
        weightLog = list

        if let latest = weightLog.last, abs(profile.weightKg - latest.kg) > 0.0001 {
            profile.weightKg = latest.kg
        }
        return true
    }

    func deleteWeight(id: UUID) {
        weightLog.removeAll { $0.id == id }
        if let latest = weightLog.last, abs(profile.weightKg - latest.kg) > 0.0001 {
            profile.weightKg = latest.kg
        }
    }

    /// Adds a body measurement in cm (one per type per calendar day: the same day replaces it).
    /// Returns false for values outside MeasurementLimits.
    @discardableResult
    func logMeasurement(_ type: BodyMeasurementType, cm: Double, date: Date = Date()) -> Bool {
        guard cm.isFinite, MeasurementLimits.cm.contains(cm) else { return false }
        let rounded = NumberParsing.roundedToTenth(cm)
        let when = min(date, Date())
        let calendar = Calendar.current

        var list = bodyMeasurements
        if let idx = list.firstIndex(where: { $0.kind == type.rawValue && calendar.isDate($0.date, inSameDayAs: when) }) {
            list[idx].cm = rounded
            list[idx].date = when
        } else {
            list.append(BodyMeasurement(date: when, kind: type.rawValue, cm: rounded))
        }
        bodyMeasurements = list
        return true
    }

    func deleteMeasurement(id: UUID) {
        bodyMeasurements.removeAll { $0.id == id }
    }

    /// All entries of one measurement, oldest first.
    func measurements(for type: BodyMeasurementType) -> [BodyMeasurement] {
        bodyMeasurements
            .filter { $0.kind == type.rawValue }
            .sorted { $0.date < $1.date }
    }

    func latestMeasurement(for type: BodyMeasurementType) -> BodyMeasurement? {
        measurements(for: type).last
    }

    /// Change in cm from the first to the latest entry. nil with fewer than two entries.
    func measurementChangeCm(for type: BodyMeasurementType) -> Double? {
        let list = measurements(for: type)
        guard list.count >= 2, let first = list.first, let last = list.last else { return nil }
        return NumberParsing.roundedToTenth(last.cm - first.cm)
    }

    // MARK: - Actions (Recipes)

    func toggleRecipeFavorite(id: UUID) {
        if let idx = fitRecipes.firstIndex(where: { $0.id == id }) {
            fitRecipes[idx].isFavorite.toggle()
        }
    }

    // MARK: - Actions (Google backup & restore)

    private func refreshCloudStatus() {
        let account = cloudAuth.account
        cloudEmail        = account?.email
        lastBackupAt      = account?.lastBackupAt
        autoBackupEnabled = account?.autoBackup ?? false
    }

    private func cloudErrorText(_ error: Error) -> String? {
        if let cloud = error as? CloudError { return cloud.errorDescription }
        return error.localizedDescription
    }

    private func decodeBackup(_ raw: Data) throws -> AppData {
        do {
            return try PersistenceStore.decode(raw)
        } catch PersistenceError.newerSchema {
            throw CloudError.backupTooNew
        } catch {
            throw CloudError.backupUnreadable
        }
    }

    /// True when the cloud file was written by another device (or this device never synced).
    private func isRemoteNewer(_ remote: DriveBackupService.RemoteFile) -> Bool {
        guard let known = cloudAuth.account?.lastRemoteModified else { return true }
        return remote.modified > known.addingTimeInterval(2)
    }

    private func offer(for remote: DriveBackupService.RemoteFile) async throws -> CloudRestoreOffer {
        let raw = try await drive.download(remote)
        return CloudRestoreOffer(data: try decodeBackup(raw), remoteModified: remote.modified)
    }

    private func performBackup(replacing existing: DriveBackupService.RemoteFile?) async throws {
        flush()
        let raw = try PersistenceStore.encode(snapshot())
        cloudDirty = false
        do {
            let remote = try await drive.upload(raw, replacing: existing)
            cloudAuth.updateSync {
                $0.lastBackupAt = Date()
                $0.lastRemoteModified = remote.modified
            }
            refreshCloudStatus()
        } catch {
            cloudDirty = true
            throw error
        }
    }

    /// Signs in with Google. With a backup in the cloud the user is asked what to do (restore or replace).
    func connectGoogle() async {
        guard !cloudBusy else { return }
        cloudBusy = true
        cloudMessage = nil
        defer { cloudBusy = false }
        do {
            let account = try await cloudAuth.signIn()
            refreshCloudStatus()
            if let remote = try await drive.find() {
                restoreOffer = try await offer(for: remote)
            } else if hasCompletedOnboarding {
                try await performBackup(replacing: nil)
            } else {
                // Nothing to restore on a fresh install: do not stay connected.
                await cloudAuth.signOut(revoke: true)
                refreshCloudStatus()
                cloudMessage = "No FitApp backup was found on \(account.email)."
            }
        } catch CloudError.cancelled {
            refreshCloudStatus()
        } catch {
            refreshCloudStatus()
            cloudMessage = cloudErrorText(error)
        }
    }

    /// Settings "Back up now". If another device wrote a newer backup, the user decides first.
    func backupNow() async {
        guard !cloudBusy, cloudAuth.account != nil else { return }
        cloudBusy = true
        cloudMessage = nil
        defer { cloudBusy = false }
        do {
            let remote = try await drive.find()
            if let remote, isRemoteNewer(remote) {
                restoreOffer = try await offer(for: remote)
                cloudMessage = "A backup from another device or an earlier install exists. Choose which data to keep."
            } else {
                try await performBackup(replacing: remote)
            }
        } catch {
            cloudMessage = cloudErrorText(error)
            refreshCloudStatus()
        }
    }

    /// Settings "Restore from backup": downloads the backup and asks for confirmation.
    func offerRestoreFromCloud() async {
        guard !cloudBusy, cloudAuth.account != nil else { return }
        cloudBusy = true
        cloudMessage = nil
        defer { cloudBusy = false }
        do {
            if let remote = try await drive.find() {
                restoreOffer = try await offer(for: remote)
            } else {
                cloudMessage = "There is no backup in your Google account yet."
            }
        } catch {
            cloudMessage = cloudErrorText(error)
            refreshCloudStatus()
        }
    }

    /// Replaces ALL data on this device with the backup. The previous local file is kept as a safety copy.
    func restore(_ offer: CloudRestoreOffer) {
        flush()
        store.preserveCurrentAsPrevious()
        apply(offer.data)
        cloudDirty = false
        cloudAuth.updateSync {
            $0.lastBackupAt = Date()
            $0.lastRemoteModified = offer.remoteModified
            $0.autoBackup = true
        }
        refreshCloudStatus()
        restoreOffer = nil
        cloudMessage = nil
    }

    /// The user chose to keep this device's data and overwrite the cloud backup with it.
    func keepLocalDataAndReplaceBackup() async {
        restoreOffer = nil
        guard !cloudBusy, cloudAuth.account != nil else { return }
        cloudBusy = true
        cloudMessage = nil
        defer { cloudBusy = false }
        do {
            let remote = try await drive.find()
            try await performBackup(replacing: remote)
        } catch {
            cloudMessage = cloudErrorText(error)
            refreshCloudStatus()
        }
    }

    func dismissRestoreOffer() {
        restoreOffer = nil
        // Without a decision this device must not overwrite the cloud copy automatically.
    }

    func setAutoBackup(_ enabled: Bool) {
        cloudAuth.updateSync { $0.autoBackup = enabled }
        refreshCloudStatus()
    }

    /// Disconnects Google. Optionally deletes the backup file from the user's Drive first.
    func disconnectGoogle(deleteCloudBackup: Bool) async {
        cloudBusy = true
        cloudMessage = nil
        defer { cloudBusy = false }
        if deleteCloudBackup {
            do {
                if let remote = try await drive.find() {
                    try await drive.delete(remote)
                }
            } catch {
                // Stay connected so the user can retry; never pretend the backup is gone.
                cloudMessage = cloudErrorText(error)
                return
            }
        }
        await cloudAuth.signOut(revoke: true)
        refreshCloudStatus()
    }

    /// Called when the app moves to the background: uploads pending changes (at most every 10 minutes).
    func backupWhenLeavingForeground() {
        let application = UIApplication.shared
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = application.beginBackgroundTask(withName: "FitApp backup") {
            application.endBackgroundTask(taskID)
        }
        Task {
            await autoBackupIfNeeded()
            application.endBackgroundTask(taskID)
        }
    }

    private func autoBackupIfNeeded() async {
        guard let account = cloudAuth.account,
              account.autoBackup,
              let last = account.lastBackupAt,
              cloudDirty,
              hasCompletedOnboarding,
              persistenceEnabled,
              !cloudBusy,
              Date().timeIntervalSince(last) >= 600 else { return }
        cloudBusy = true
        defer { cloudBusy = false }
        do {
            let remote = try await drive.find()
            if let remote, isRemoteNewer(remote) {
                cloudMessage = "Automatic backup paused: a newer backup from another device exists. Open Settings to choose which data to keep."
                return
            }
            try await performBackup(replacing: remote)
        } catch {
            cloudMessage = "Automatic backup failed: \(cloudErrorText(error) ?? "unknown error")"
            refreshCloudStatus()
        }
    }

    /// Replaces every piece of app data with `data` and saves it.
    private func apply(_ data: AppData) {
        saveTask?.cancel()
        saveTask = nil
        persistenceEnabled = true
        storageWarning = nil

        profile                = data.profile
        hasCompletedOnboarding = data.hasCompletedOnboarding
        isDarkMode             = data.isDarkMode
        exercises              = data.exercises
        workoutHistory         = data.workoutHistory
        meals                  = data.meals
        waterByDay             = data.waterByDay
        savedWorkouts          = data.savedWorkouts
        defaultWorkoutID       = data.defaultWorkoutID
        activeWorkoutID        = data.activeWorkoutID
        freeWorkoutChosen      = data.freeWorkoutChosen
        customFoods            = data.customFoods
        weightLog              = data.weightLog
        bodyMeasurements       = data.bodyMeasurements
        customMeals            = data.customMeals
        fitRecipes             = Self.makeRecipes(favoriteTitles: data.favoriteRecipeTitles)

        // A backup made before weight tracking existed has no weigh-ins: start from the profile weight.
        syncWeightLogWithProfile()

        isDirty = true
        flush()
    }

    // MARK: - Reset (Settings screen)

    /// Settings "Reset Profile": clears the profile and shows onboarding again. Workouts, meals and the
    /// weight / measurement history are kept.
    func resetProfile() {
        profile = UserProfile()
        hasCompletedOnboarding = false
    }

    /// Settings "Reset All Data": clears workouts, workout history and ALL nutrition history.
    /// The profile, favourite recipes, My Foods, weight history and measurements are kept.
    func resetTrackingData() {
        exercises = AppData.starterExercises
        activeWorkoutID = nil
        freeWorkoutChosen = true
        workoutHistory = []
        meals = []
        waterByDay = [:]
    }

    /// Deletes everything (profile, workouts, nutrition, My Foods, weight and measurements, favourites and
    /// the stored files) and returns the app to its first-launch state. The dark-mode choice is kept.
    func resetAllData() {
        saveTask?.cancel()
        saveTask = nil
        store.deleteAllStoredData()

        // Also forget the Google connection on this device (a backup already in Drive stays there).
        if cloudAuth.account != nil {
            Task { await disconnectGoogle(deleteCloudBackup: false) }
        }

        persistenceEnabled = true
        storageWarning = nil

        profile                = UserProfile()
        hasCompletedOnboarding = false
        exercises              = AppData.starterExercises
        workoutHistory         = []
        meals                  = []
        waterByDay             = [:]
        fitRecipes             = FitRecipe.database
        savedWorkouts          = []
        defaultWorkoutID       = nil
        activeWorkoutID        = nil
        freeWorkoutChosen      = false
        customFoods            = []
        customMeals            = []
        weightLog              = []
        bodyMeasurements       = []

        isDirty = true
        flush()
    }
}
