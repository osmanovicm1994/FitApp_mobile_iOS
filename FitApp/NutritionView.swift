// NutritionView.swift
// Daily nutrition tracking: water intake, protein, carbs, fats, calories, quick log and My Foods.

import SwiftUI
import Combine  // explicit import

struct NutritionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogMacros: Bool = false
    @State private var showResetDayAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Water card
                    waterCard
                    // Macro summary card
                    macroCard
                    // Quick log buttons
                    quickActionsCard
                    // The user's own foods
                    MyFoodsCard()
                    // Meals built from several foods
                    MyMealsCard()
                    // Today's meals (with delete)
                    mealsCard
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Macros") { showLogMacros = true }
                        .accessibilityIdentifier("log_macros_button")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset Day") { showResetDayAlert = true }
                        .foregroundColor(.red)
                        .accessibilityIdentifier("reset_nutrition_button")
                }
            }
            .sheet(isPresented: $showLogMacros) {
                LogMacrosSheet()
            }
        }
        .accessibilityIdentifier("nutrition_view")
        .alert("Reset today's nutrition?", isPresented: $showResetDayAlert) {
            Button("Reset", role: .destructive) { appState.resetNutrition() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all meals and water logged today. Earlier days are kept.")
        }
    }

    // MARK: - Water Card

    private var waterCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Water Intake", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundColor(.cyan)
                Spacer()
                Text("\(Int(appState.todayNutrition.waterMl)) / \(Int(appState.dailyWaterGoalMl)) ml")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("water_amount_label")
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan.opacity(0.15))
                        .frame(height: 16)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan)
                        .frame(width: geo.size.width * appState.waterProgress, height: 16)
                        .animation(.spring(), value: appState.waterProgress)
                }
            }
            .frame(height: 16)
            .accessibilityIdentifier("water_progress_bar")

            // Quick add buttons
            HStack(spacing: 10) {
                ForEach([150, 250, 350, 500], id: \.self) { ml in
                    Button(action: { appState.addWater(ml: Double(ml)) }) {
                        Text("+\(ml)ml")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .cornerRadius(20)
                    }
                    .accessibilityIdentifier("add_water_\(ml)ml")
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .accessibilityIdentifier("water_card")
    }

    // MARK: - Macro Card

    private var macroCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Macros Today", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                Text("\(Int(appState.todayNutrition.calories)) kcal")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                    .accessibilityIdentifier("calories_label")
            }

            Text("Daily goal: \(Int(appState.dailyCalorieGoal)) kcal (estimate)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("calorie_goal_label")

            HStack(spacing: 12) {
                MacroRing(
                    label: "Protein",
                    value: appState.todayNutrition.proteinG,
                    goal: appState.dailyProteinGoalG,
                    unit: "g",
                    color: .blue,
                    accessID: "protein_ring"
                )
                MacroRing(
                    label: "Carbs",
                    value: appState.todayNutrition.carbsG,
                    goal: appState.dailyCarbsGoalG,
                    unit: "g",
                    color: .orange,
                    accessID: "carbs_ring"
                )
                MacroRing(
                    label: "Fats",
                    value: appState.todayNutrition.fatsG,
                    goal: appState.dailyFatGoalG,
                    unit: "g",
                    color: .yellow,
                    accessID: "fats_ring"
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .accessibilityIdentifier("macro_card")
    }

    // MARK: - Today's Meals

    private var mealsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Meals")
                .font(.headline)

            if appState.todayMeals.isEmpty {
                Text("No meals logged yet today.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("no_meals_label")
            } else {
                ForEach(Array(appState.todayMeals.enumerated()), id: \.element.id) { index, meal in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.name)
                                .font(.subheadline.bold())
                            Text("\(Int(meal.calories)) kcal · P \(Int(meal.proteinG)) · C \(Int(meal.carbsG)) · F \(Int(meal.fatsG))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            appState.removeMeal(id: meal.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .accessibilityIdentifier("delete_meal_\(index)")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("meal_row_\(index)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .accessibilityIdentifier("meals_card")
    }

    // MARK: - Quick Actions

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Log")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(QuickMeal.presets, id: \.name) { meal in
                    Button(action: {
                        appState.logNutrition(
                            protein: meal.protein,
                            carbs: meal.carbs,
                            fats: meal.fats,
                            calories: meal.calories,
                            name: meal.name,
                            source: "quick"
                        )
                    }) {
                        VStack(spacing: 4) {
                            Text(meal.emoji).font(.title2)
                            Text(meal.name).font(.caption.bold())
                            Text("\(Int(meal.protein))g protein")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("quick_log_\(meal.name.lowercased().replacingOccurrences(of: " ", with: "_"))")
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .accessibilityIdentifier("quick_actions_card")
    }
}

// MARK: - Macro Ring

struct MacroRing: View {
    let label: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    let accessID: String

    var progress: Double { min(value / max(goal, 1), 1.0) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.system(size: 14, weight: .bold))
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(accessID)
    }
}

// MARK: - Log Macros Sheet

struct LogMacrosSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fats: String = ""
    @State private var calories: String = ""
    @State private var mealName: String = ""
    @State private var saveAsFood: Bool = false

    private var hasName: Bool {
        !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Name (optional)") {
                    TextField("e.g. Lunch", text: $mealName)
                        .accessibilityIdentifier("meal_name_field")
                }
                Section("Macros") {
                    macroRow(label: "Protein (g)", value: $protein, id: "log_protein_field")
                    macroRow(label: "Carbs (g)",   value: $carbs,   id: "log_carbs_field")
                    macroRow(label: "Fats (g)",    value: $fats,    id: "log_fats_field")
                    macroRow(label: "Calories",    value: $calories, id: "log_calories_field")
                }
                if hasName {
                    Section {
                        Toggle("Save as a custom food", isOn: $saveAsFood)
                            .accessibilityIdentifier("save_as_custom_food_toggle")
                    } footer: {
                        Text("Adds this meal to My Foods as one serving, so you can log it again in one tap.")
                    }
                }
            }
            .navigationTitle("Log Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let p = parsed?.protein ?? 0
                        let c = parsed?.carbs ?? 0
                        let f = parsed?.fats ?? 0
                        let k = parsed?.calories ?? 0
                        appState.logNutrition(
                            protein:  p,
                            carbs:    c,
                            fats:     f,
                            calories: k,
                            name: mealName,
                            source: "manual"
                        )
                        if saveAsFood && hasName {
                            appState.saveCustomFood(CustomFood(name: mealName,
                                                               calories: k,
                                                               proteinG: p,
                                                               carbsG: c,
                                                               fatsG: f))
                        }
                        dismiss()
                    }
                    .disabled(parsed == nil)
                    .accessibilityIdentifier("save_macros_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_macros_button")
                }
            }
        }
        .accessibilityIdentifier("log_macros_sheet")
    }

    /// Empty field = 0. Invalid text, negative or absurd values make the whole form invalid.
    private func fieldValue(_ text: String) -> Double? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return 0 }
        guard let v = NumberParsing.double(from: text), v >= 0, v <= 20000 else { return nil }
        return v
    }

    /// nil when any field is invalid or when everything is zero.
    private var parsed: (protein: Double, carbs: Double, fats: Double, calories: Double)? {
        guard let p = fieldValue(protein),
              let c = fieldValue(carbs),
              let f = fieldValue(fats),
              let k = fieldValue(calories),
              p + c + f + k > 0 else { return nil }
        return (p, c, f, k)
    }

    private func macroRow(label: String, value: Binding<String>, id: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .accessibilityIdentifier(id)
        }
    }
}

// MARK: - Quick Meal Presets

struct QuickMeal {
    let name: String
    let emoji: String
    let protein: Double
    let carbs: Double
    let fats: Double
    let calories: Double

    static let presets: [QuickMeal] = [
        QuickMeal(name: "Chicken Breast", emoji: "🍗", protein: 31, carbs: 0, fats: 3.6, calories: 165),
        QuickMeal(name: "Greek Yogurt",   emoji: "🥛", protein: 17, carbs: 6,  fats: 0.7, calories: 100),
        QuickMeal(name: "Eggs (2)",        emoji: "🥚", protein: 12, carbs: 1,  fats: 10,  calories: 143),
        QuickMeal(name: "Protein Shake",  emoji: "🥤", protein: 25, carbs: 5,  fats: 2,   calories: 130),
        QuickMeal(name: "Tuna Can",       emoji: "🐟", protein: 25, carbs: 0,  fats: 1,   calories: 110),
        QuickMeal(name: "Oats (100g)",    emoji: "🌾", protein: 13, carbs: 68, fats: 7,   calories: 389),
    ]
}
