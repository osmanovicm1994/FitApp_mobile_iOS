// CustomMealViews.swift
// "My Meals": meals the user builds from several foods (My Foods, quick items or typed-in items).
// The meal's calories and macros are summed automatically and logged as one meal in one tap.
// All data lives in AppState (customMeals); these views only display it and call AppState methods.

import SwiftUI
import Combine  // explicit import

// MARK: - Editor target

/// Identifies what the editor sheet is open for: a new meal (meal == nil) or an existing one.
private struct MealEditorTarget: Identifiable {
    let id = UUID()
    let meal: CustomMeal?
}

// MARK: - My Meals card (shown on the Nutrition tab)

struct MyMealsCard: View {
    @EnvironmentObject var appState: AppState
    @State private var editorTarget: MealEditorTarget? = nil
    @State private var mealToDelete: CustomMeal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Meals")
                    .font(.headline)
                Spacer()
                Button {
                    editorTarget = MealEditorTarget(meal: nil)
                } label: {
                    Label("Add Meal", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                }
                .accessibilityIdentifier("add_custom_meal_button")
            }

            if appState.customMeals.isEmpty {
                Text("Combine several foods into one meal. Calories and macros are added up for you, and you can log the whole meal in one tap.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("no_custom_meals_label")
            } else {
                ForEach(Array(appState.customMeals.enumerated()), id: \.element.id) { index, meal in
                    mealRow(meal, index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .accessibilityIdentifier("my_meals_card")
        .sheet(item: $editorTarget) { target in
            CustomMealEditorSheet(existing: target.meal)
        }
        .alert("Delete this meal?",
               isPresented: Binding(get: { mealToDelete != nil },
                                    set: { if !$0 { mealToDelete = nil } }),
               presenting: mealToDelete) { meal in
            Button("Delete", role: .destructive) { appState.deleteCustomMeal(id: meal.id) }
            Button("Cancel", role: .cancel) {}
        } message: { meal in
            Text("\"\(meal.name)\" will be removed from My Meals. Meals you already logged are kept.")
        }
    }

    private func mealRow(_ meal: CustomMeal, index: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline.bold())
                Text("\(Int(meal.totalCalories.rounded())) kcal · P \(NumberParsing.display(meal.totalProteinG)) · C \(NumberParsing.display(meal.totalCarbsG)) · F \(NumberParsing.display(meal.totalFatsG))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(meal.items.map { $0.name }.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                appState.logCustomMeal(id: meal.id, servings: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .accessibilityLabel("Log \(meal.name)")
            .accessibilityIdentifier("log_custom_meal_\(index)")

            Menu {
                Button("Log ½ portion") { appState.logCustomMeal(id: meal.id, servings: 0.5) }
                Button("Log 2 portions") { appState.logCustomMeal(id: meal.id, servings: 2) }
                Divider()
                Button("Edit") { editorTarget = MealEditorTarget(meal: meal) }
                Button("Delete", role: .destructive) { mealToDelete = meal }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("More options for \(meal.name)")
            .accessibilityIdentifier("custom_meal_menu_\(index)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("custom_meal_row_\(index)")
    }
}

// MARK: - Meal editor sheet

struct CustomMealEditorSheet: View {
    let existing: CustomMeal?

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var items: [CustomMealItem] = []
    @State private var showManualItemSheet: Bool = false
    @State private var saveFailed: Bool = false

    init(existing: CustomMeal?) {
        self.existing = existing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name (e.g. Post-workout breakfast)", text: $name)
                        .accessibilityIdentifier("custom_meal_name_field")
                    if let nameError {
                        Text(nameError)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("custom_meal_validation_label")
                    }
                }

                Section {
                    if items.isEmpty {
                        Text("No ingredients yet. Add foods below.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("custom_meal_no_items_label")
                    }
                    ForEach($items) { $item in
                        itemRow($item)
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    Menu {
                        ForEach(appState.customFoods) { food in
                            Button("\(food.name) (\(food.servingLabel))") { add(food: food) }
                        }
                    } label: {
                        Label("Add from My Foods", systemImage: "fork.knife")
                    }
                    .disabled(appState.customFoods.isEmpty || itemLimitReached)
                    .accessibilityIdentifier("add_meal_item_from_foods_menu")

                    Menu {
                        ForEach(QuickMeal.presets, id: \.name) { quick in
                            Button("\(quick.emoji) \(quick.name)") { add(quick: quick) }
                        }
                    } label: {
                        Label("Add a quick item", systemImage: "bolt.fill")
                    }
                    .disabled(itemLimitReached)
                    .accessibilityIdentifier("add_meal_item_quick_menu")

                    Button {
                        showManualItemSheet = true
                    } label: {
                        Label("Add another item (type values)", systemImage: "plus")
                    }
                    .disabled(itemLimitReached)
                    .accessibilityIdentifier("add_meal_item_manual_button")
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text("Use the stepper to set how many servings of each ingredient go into the meal. Swipe an ingredient left to remove it. Up to \(CustomMeal.maxItems) ingredients.")
                }

                Section {
                    Text(totalText)
                        .font(.subheadline.bold())
                        .accessibilityIdentifier("custom_meal_total_label")
                    if let totalError {
                        Text(totalError)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("custom_meal_total_error")
                    }
                } header: {
                    Text("Total for the whole meal")
                }

                if saveFailed {
                    Section {
                        Text("This meal could not be saved. Names must be unique and you can keep up to \(CustomMeal.maxCount) meals.")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("custom_meal_save_error")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("save_custom_meal_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_custom_meal_button")
                }
            }
            .sheet(isPresented: $showManualItemSheet) {
                CustomMealItemSheet { item in
                    items.append(item)
                }
            }
        }
        .onAppear { populate() }
        .accessibilityIdentifier("custom_meal_sheet")
    }

    // MARK: Rows

    private func itemRow(_ item: Binding<CustomMealItem>) -> some View {
        let value = item.wrappedValue
        let index = items.firstIndex(where: { $0.id == value.id }) ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            Text(value.name)
                .font(.subheadline.bold())
            Text("\(NumberParsing.display(value.quantity)) × \(value.servingLabel) · \(Int(value.totalCalories.rounded())) kcal · P \(NumberParsing.display(value.totalProteinG)) · C \(NumberParsing.display(value.totalCarbsG)) · F \(NumberParsing.display(value.totalFatsG))")
                .font(.caption)
                .foregroundColor(.secondary)
            Stepper(value: item.quantity, in: 0.5...CustomMealItem.quantityRange.upperBound, step: 0.5) {
                Text("Servings: \(NumberParsing.display(value.quantity))")
                    .font(.footnote)
            }
            .accessibilityIdentifier("meal_item_quantity_stepper_\(index)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meal_item_row_\(index)")
    }

    // MARK: Totals and validation

    private var draft: CustomMeal {
        CustomMeal(id: existing?.id ?? UUID(), name: trimmedName, items: items)
    }

    private var totalText: String {
        let meal = draft
        return "\(Int(meal.totalCalories.rounded())) kcal · P \(NumberParsing.display(meal.totalProteinG)) g · C \(NumberParsing.display(meal.totalCarbsG)) g · F \(NumberParsing.display(meal.totalFatsG)) g"
    }

    private var totalsWithinLimit: Bool {
        let meal = draft
        return [meal.totalCalories, meal.totalProteinG, meal.totalCarbsG, meal.totalFatsG]
            .allSatisfy { $0.isFinite && $0 <= CustomFood.maxPerServing }
    }

    private var totalError: String? {
        totalsWithinLimit ? nil : "A single meal can have at most \(Int(CustomFood.maxPerServing)) kcal (or grams of a macro). Remove or reduce an ingredient."
    }

    private var itemLimitReached: Bool {
        items.count >= CustomMeal.maxItems
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameError: String? {
        guard !trimmedName.isEmpty else { return nil }
        if appState.customMealNameExists(trimmedName, excluding: existing?.id) {
            return "You already have a meal with this name."
        }
        return nil
    }

    private var canSave: Bool {
        let meal = draft
        let hasValue = meal.totalCalories + meal.totalProteinG + meal.totalCarbsG + meal.totalFatsG > 0
        return !trimmedName.isEmpty && nameError == nil && !items.isEmpty && hasValue && totalsWithinLimit
    }

    // MARK: Actions

    private func populate() {
        guard let meal = existing, name.isEmpty, items.isEmpty else { return }
        name = meal.name
        items = meal.items
    }

    private func add(food: CustomFood) {
        guard !itemLimitReached else { return }
        items.append(CustomMealItem(name: food.name,
                                    servingLabel: food.servingLabel,
                                    quantity: 1,
                                    calories: food.calories,
                                    proteinG: food.proteinG,
                                    carbsG: food.carbsG,
                                    fatsG: food.fatsG))
    }

    private func add(quick: QuickMeal) {
        guard !itemLimitReached else { return }
        items.append(CustomMealItem(name: quick.name,
                                    servingLabel: "1 serving",
                                    quantity: 1,
                                    calories: quick.calories,
                                    proteinG: quick.protein,
                                    carbsG: quick.carbs,
                                    fatsG: quick.fats))
    }

    private func save() {
        if appState.saveCustomMeal(draft) {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}

// MARK: - Manual ingredient sheet

/// Small form for an ingredient that is not in My Foods: name, serving and calories/macros per serving.
private struct CustomMealItemSheet: View {
    let onAdd: (CustomMealItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var serving: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fats: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Name (e.g. Olive oil)", text: $name)
                        .accessibilityIdentifier("meal_item_name_field")
                    TextField("Serving (e.g. 1 tbsp, 100 g)", text: $serving)
                        .accessibilityIdentifier("meal_item_serving_field")
                }

                Section {
                    valueRow(label: "Calories (kcal)", text: $calories,
                             placeholder: caloriesPlaceholder, id: "meal_item_calories_field")
                    valueRow(label: "Protein (g)", text: $protein, placeholder: "0", id: "meal_item_protein_field")
                    valueRow(label: "Carbs (g)", text: $carbs, placeholder: "0", id: "meal_item_carbs_field")
                    valueRow(label: "Fats (g)", text: $fats, placeholder: "0", id: "meal_item_fats_field")
                } header: {
                    Text("Per serving")
                } footer: {
                    Text("Leave calories empty to calculate them from protein, carbs and fats (4, 4 and 9 kcal per gram).")
                }
            }
            .navigationTitle("New Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(!canAdd)
                        .accessibilityIdentifier("save_meal_item_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_meal_item_button")
                }
            }
        }
        .accessibilityIdentifier("custom_meal_item_sheet")
    }

    // MARK: Validation

    /// Empty field = 0. Invalid text, negative or too large values make the whole form invalid (nil).
    private func fieldValue(_ text: String) -> Double? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return 0 }
        guard let v = NumberParsing.double(from: text), v >= 0, v <= CustomFood.maxPerServing else { return nil }
        return v
    }

    private var caloriesAreBlank: Bool {
        calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// nil when a field is invalid or when everything is zero.
    private var parsed: (calories: Double, protein: Double, carbs: Double, fats: Double)? {
        guard let p = fieldValue(protein),
              let c = fieldValue(carbs),
              let f = fieldValue(fats),
              let k = fieldValue(calories) else { return nil }
        let kcal = caloriesAreBlank ? CustomFood.estimatedCalories(protein: p, carbs: c, fats: f) : k
        guard kcal + p + c + f > 0 else { return nil }
        return (kcal, p, c, f)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        !trimmedName.isEmpty && parsed != nil
    }

    private var caloriesPlaceholder: String {
        guard caloriesAreBlank,
              let p = fieldValue(protein), let c = fieldValue(carbs), let f = fieldValue(fats) else { return "0" }
        let estimate = CustomFood.estimatedCalories(protein: p, carbs: c, fats: f)
        return estimate > 0 ? "≈ \(Int(estimate))" : "0"
    }

    private func add() {
        guard let values = parsed else { return }
        let trimmedServing = serving.trimmingCharacters(in: .whitespacesAndNewlines)
        onAdd(CustomMealItem(name: trimmedName,
                             servingLabel: trimmedServing.isEmpty ? "1 serving" : trimmedServing,
                             quantity: 1,
                             calories: values.calories,
                             proteinG: values.protein,
                             carbsG: values.carbs,
                             fatsG: values.fats))
        dismiss()
    }

    private func valueRow(label: String, text: Binding<String>, placeholder: String, id: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .accessibilityIdentifier(id)
        }
    }
}
