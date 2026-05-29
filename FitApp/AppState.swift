// AppState.swift
// Central state object for GymApp
// Includes original workout/nutrition logic and new HFM recipe support.

import SwiftUI
import Combine

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

// MARK: - AppState

final class AppState: ObservableObject {
    
    // ── Profile ───────────────────────────────────
    @Published var profile: UserProfile = UserProfile()
    @Published var hasCompletedOnboarding: Bool = false

    // ── Theme ─────────────────────────────────────
    @Published var isDarkMode: Bool = true

    // ── Workout ───────────────────────────────────
    @Published var exercises: [WorkoutExercise] = [
        WorkoutExercise(name: "Push-ups",  sets: 3, reps: 15),
        WorkoutExercise(name: "Squats",    sets: 4, reps: 12),
        WorkoutExercise(name: "Pull-ups",  sets: 3, reps: 8),
        WorkoutExercise(name: "Plank",     sets: 3, reps: 60),
        WorkoutExercise(name: "Lunges",    sets: 3, reps: 12),
        WorkoutExercise(name: "Crunches",  sets: 3, reps: 20),
    ]
    @Published var workoutHistory: [WorkoutSession] = []

    // ── Nutrition ─────────────────────────────────
    @Published var todayNutrition: NutritionEntry = NutritionEntry()

    // ── Recipes ───────────────────────────────────
    @Published var fitRecipes: [FitRecipe] = FitRecipe.database

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

    var waterProgress: Double { min(todayNutrition.waterMl / dailyWaterGoalMl, 1.0) }
    var proteinProgress: Double { min(todayNutrition.proteinG / dailyProteinGoalG, 1.0) }

    var favoriteFitRecipes: [FitRecipe] {
        fitRecipes.filter { $0.isFavorite }
    }

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
        // Reset the current list for next time
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
    }

    // MARK: - Actions (Recipes)

    func toggleRecipeFavorite(id: UUID) {
        if let idx = fitRecipes.firstIndex(where: { $0.id == id }) {
            fitRecipes[idx].isFavorite.toggle()
        }
    }
}
