import FitAppCoreResources

/// App-specific enum adapter; calculation rules and their JS bundle ship with FitApp-Shared.
enum SharedCore {
    static func estimateCalories(protein: Double, carbs: Double, fats: Double) -> Double {
        FitAppSharedCore.estimateCalories(proteinG: protein, carbsG: carbs, fatsG: fats)
    }

    static func dailyProteinGoal(weightKg: Double, goal: UserProfile.FitnessGoal) -> Double {
        let sharedGoal: String
        switch goal {
        case .loseWeight: sharedGoal = "loseWeight"
        case .gainMuscle: sharedGoal = "gainMuscle"
        case .maintain: sharedGoal = "maintain"
        case .performance: sharedGoal = "performance"
        }
        return FitAppSharedCore.dailyProteinGoal(weightKg: weightKg, goal: sharedGoal)
    }
}
