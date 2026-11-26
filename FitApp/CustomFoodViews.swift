// CustomFoodViews.swift
// "My Foods": foods the user creates themselves (name, serving, calories, macros) and logs in one tap.
// All data lives in AppState (customFoods); these views only display it and call AppState methods.

import SwiftUI
import Combine  // explicit import

// MARK: - Editor target

/// Identifies what the editor sheet is open for: a new food (food == nil) or an existing one.
private struct FoodEditorTarget: Identifiable {
    let id = UUID()
    let food: CustomFood?
}

// MARK: - My Foods card (shown on the Nutrition tab)

struct MyFoodsCard: View {
    @EnvironmentObject var appState: AppState
    @State private var editorTarget: FoodEditorTarget? = nil
    @State private var foodToDelete: CustomFood? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Foods")
                    .font(.headline)
                Spacer()
                Button {
                    editorTarget = FoodEditorTarget(food: nil)
                } label: {
                    Label("Add Food", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                }
                .accessibilityIdentifier("add_custom_food_button")
            }

            if appState.customFoods.isEmpty {
                Text("Create your own foods with their calories and macros, then log them in one tap.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("no_custom_foods_label")
            } else {
                ForEach(Array(appState.customFoods.enumerated()), id: \.element.id) { index, food in
                    foodRow(food, index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .accessibilityIdentifier("my_foods_card")
        .sheet(item: $editorTarget) { target in
            CustomFoodEditorSheet(existing: target.food)
        }
        .alert("Delete this food?",
               isPresented: Binding(get: { foodToDelete != nil },
                                    set: { if !$0 { foodToDelete = nil } }),
               presenting: foodToDelete) { food in
            Button("Delete", role: .destructive) { appState.deleteCustomFood(id: food.id) }
            Button("Cancel", role: .cancel) {}
        } message: { food in
            Text("\"\(food.name)\" will be removed from My Foods. Meals you already logged are kept.")
        }
    }

    private func foodRow(_ food: CustomFood, index: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.subheadline.bold())
                Text("\(food.servingLabel) · \(Int(food.calories)) kcal · P \(NumberParsing.display(food.proteinG)) · C \(NumberParsing.display(food.carbsG)) · F \(NumberParsing.display(food.fatsG))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                appState.logCustomFood(id: food.id, servings: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .accessibilityLabel("Log \(food.name)")
            .accessibilityIdentifier("log_custom_food_\(index)")

            Menu {
                Button("Log ½ serving") { appState.logCustomFood(id: food.id, servings: 0.5) }
                Button("Log 2 servings") { appState.logCustomFood(id: food.id, servings: 2) }
                Divider()
                Button("Edit") { editorTarget = FoodEditorTarget(food: food) }
                Button("Delete", role: .destructive) { foodToDelete = food }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("More options for \(food.name)")
            .accessibilityIdentifier("custom_food_menu_\(index)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("custom_food_row_\(index)")
    }
}

// MARK: - Editor sheet

struct CustomFoodEditorSheet: View {
    let existing: CustomFood?

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var serving: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fats: String = ""
    @State private var saveFailed: Bool = false

    init(existing: CustomFood?) {
        self.existing = existing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name (e.g. Homemade granola)", text: $name)
                        .accessibilityIdentifier("custom_food_name_field")
                    TextField("Serving (e.g. 100 g, 1 slice)", text: $serving)
                        .accessibilityIdentifier("custom_food_serving_field")
                    if let nameError {
                        Text(nameError)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("custom_food_validation_label")
                    }
                }

                Section {
                    valueRow(label: "Calories (kcal)", text: $calories,
                             placeholder: caloriesPlaceholder, id: "custom_food_calories_field")
                    valueRow(label: "Protein (g)", text: $protein, placeholder: "0", id: "custom_food_protein_field")
                    valueRow(label: "Carbs (g)", text: $carbs, placeholder: "0", id: "custom_food_carbs_field")
                    valueRow(label: "Fats (g)", text: $fats, placeholder: "0", id: "custom_food_fats_field")
                } header: {
                    Text("Per serving")
                } footer: {
                    Text("Leave calories empty to calculate them from protein, carbs and fats (4, 4 and 9 kcal per gram). Values are for one serving; you can log half or double servings later.")
                }

                if saveFailed {
                    Section {
                        Text("This food could not be saved. Names must be unique and you can keep up to \(CustomFood.maxCount) foods.")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("custom_food_save_error")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("save_custom_food_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_custom_food_button")
                }
            }
        }
        .onAppear { populate() }
        .accessibilityIdentifier("custom_food_sheet")
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

    private var nameError: String? {
        guard !trimmedName.isEmpty else { return nil }
        if appState.customFoodNameExists(trimmedName, excluding: existing?.id) {
            return "You already have a food with this name."
        }
        return nil
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && nameError == nil && parsed != nil
    }

    /// Shows the estimate in the empty calories field once protein, carbs or fats are entered.
    private var caloriesPlaceholder: String {
        guard caloriesAreBlank,
              let p = fieldValue(protein), let c = fieldValue(carbs), let f = fieldValue(fats) else { return "0" }
        let estimate = CustomFood.estimatedCalories(protein: p, carbs: c, fats: f)
        return estimate > 0 ? "≈ \(Int(estimate))" : "0"
    }

    // MARK: Actions

    private func populate() {
        guard let food = existing, name.isEmpty else { return }
        name     = food.name
        serving  = food.servingLabel
        calories = NumberParsing.display(food.calories)
        protein  = food.proteinG == 0 ? "" : NumberParsing.display(food.proteinG)
        carbs    = food.carbsG == 0 ? "" : NumberParsing.display(food.carbsG)
        fats     = food.fatsG == 0 ? "" : NumberParsing.display(food.fatsG)
    }

    private func save() {
        guard let values = parsed else { return }
        let food = CustomFood(id: existing?.id ?? UUID(),
                              name: trimmedName,
                              servingLabel: serving,
                              calories: values.calories,
                              proteinG: values.protein,
                              carbsG: values.carbs,
                              fatsG: values.fats)
        if appState.saveCustomFood(food) {
            dismiss()
        } else {
            saveFailed = true
        }
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
