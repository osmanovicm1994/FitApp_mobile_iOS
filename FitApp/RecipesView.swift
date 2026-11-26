// RecipesView.swift
// Recipe browser: search, category filter, favourites, detail view and "Log to Nutrition".
// All recipe content lives in RecipeData.swift (original FitApp content, no external images or links).

import SwiftUI
import Combine

// MARK: - FitRecipe Model

struct FitRecipe: Identifiable {
    let id: UUID
    let title: String
    let tagline: String
    let category: FitRecipeCategory
    /// Emoji used as the recipe's artwork (shown on a category-coloured gradient).
    let emoji: String
    let prepMins: Int
    let cookMins: Int
    let servings: Int
    // Approximate per-serving estimates
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let ingredients: [String]
    let instructions: [String]
    let tags: [String]
    var isFavorite: Bool

    var totalMins: Int { prepMins + cookMins }

    init(title: String, tagline: String, category: FitRecipeCategory, emoji: String,
         prepMins: Int, cookMins: Int, servings: Int,
         calories: Int, proteinG: Int, carbsG: Int, fatG: Int,
         ingredients: [String], instructions: [String],
         tags: [String]) {
        self.id = UUID()
        self.title = title; self.tagline = tagline; self.category = category
        self.emoji = emoji
        self.prepMins = prepMins; self.cookMins = cookMins; self.servings = servings
        self.calories = calories; self.proteinG = proteinG
        self.carbsG = carbsG; self.fatG = fatG
        self.ingredients = ingredients; self.instructions = instructions
        self.tags = tags
        self.isFavorite = false
    }
}

// MARK: - Category

enum FitRecipeCategory: String, CaseIterable, Hashable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case mealPrep  = "Meal Prep"
    case snacks    = "Snacks"
    case smoothies = "Smoothies"

    var color: Color {
        switch self {
        case .breakfast: return Color(red:1.0,  green:0.65, blue:0.12)
        case .lunch:     return Color(red:0.30, green:0.82, blue:0.50)
        case .dinner:    return Color(red:0.32, green:0.60, blue:0.98)
        case .mealPrep:  return Color(red:0.68, green:0.38, blue:0.98)
        case .snacks:    return Color(red:0.98, green:0.40, blue:0.40)
        case .smoothies: return Color(red:0.98, green:0.45, blue:0.75)
        }
    }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "leaf.fill"
        case .dinner:    return "moon.stars.fill"
        case .mealPrep:  return "tray.fill"
        case .snacks:    return "bolt.fill"
        case .smoothies: return "drop.fill"
        }
    }
}

// MARK: - Recipe artwork (original, no network)

struct RecipeArt: View {
    let recipe: FitRecipe
    var emojiSize: CGFloat = 80

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [recipe.category.color.opacity(0.55),
                         recipe.category.color.opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(recipe.emoji)
                .font(.system(size: emojiSize))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
    }
}

// MARK: - Recipes View

struct RecipesView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchQuery   = ""
    @State private var selectedCat: FitRecipeCategory? = nil
    @State private var showFavOnly   = false
    @State private var selected: FitRecipe? = nil
    @State private var logRecipe: FitRecipe? = nil

    private var displayed: [FitRecipe] {
        appState.fitRecipes.filter { r in
            (selectedCat == nil || r.category == selectedCat) &&
            (!showFavOnly || r.isFavorite) &&
            (searchQuery.isEmpty ||
             r.title.localizedCaseInsensitiveContains(searchQuery) ||
             r.tagline.localizedCaseInsensitiveContains(searchQuery) ||
             r.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) }))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                categoryBar
                if displayed.isEmpty { emptyState } else { recipeList }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { withAnimation { showFavOnly.toggle() } } label: {
                        Image(systemName: showFavOnly ? "heart.fill" : "heart")
                            .foregroundStyle(.pink)
                    }
                    .accessibilityIdentifier("favorites_filter_button")
                }
            }
            .sheet(item: $selected) { r in
                RecipeDetailView(
                    recipe: appState.fitRecipes.first(where: { $0.id == r.id }) ?? r,
                    onFavorite: { appState.toggleRecipeFavorite(id: r.id) },
                    onLog: { logRecipe = r }
                )
            }
            .sheet(item: $logRecipe) { r in
                NutritionLogSheet(recipe: r)
                    .environmentObject(appState)
            }
        }
        .accessibilityIdentifier("recipes_view")
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search recipes, tags...", text: $searchQuery)
                .accessibilityIdentifier("recipes_search_field")
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal).padding(.vertical, 8)
    }

    // MARK: Category chips

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                catChip("All", icon: "square.grid.2x2", color: .blue, on: selectedCat == nil) {
                    withAnimation { selectedCat = nil }
                }
                ForEach(FitRecipeCategory.allCases, id: \.self) { cat in
                    catChip(cat.rawValue, icon: cat.icon, color: cat.color, on: selectedCat == cat) {
                        withAnimation { selectedCat = selectedCat == cat ? nil : cat }
                    }
                }
            }
            .padding(.horizontal).padding(.bottom, 10)
        }
        .accessibilityIdentifier("category_filter_bar")
    }

    @ViewBuilder
    private func catChip(_ label: String, icon: String, color: Color,
                          on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2.bold())
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? color : Color.secondary.opacity(0.08))
            .foregroundStyle(on ? Color.white : Color.primary)
            .clipShape(Capsule())
            .shadow(color: on ? color.opacity(0.3) : .clear, radius: 5, y: 2)
        }
        .accessibilityIdentifier(
            "category_\(label.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    // MARK: List

    private var recipeList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(displayed) { recipe in
                    RecipeCard(
                        recipe: recipe,
                        onTap: { selected = recipe },
                        onFavorite: { appState.toggleRecipeFavorite(id: recipe.id) },
                        onLog: { logRecipe = recipe }
                    )
                }
            }
            .padding()
        }
        .accessibilityIdentifier("recipes_list")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "fork.knife").font(.system(size: 50)).foregroundStyle(.secondary)
            Text("No recipes found").font(.title2.bold())
            Text("Try a different search or category").foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityIdentifier("no_recipes_label")
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let recipe: FitRecipe
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable artwork + overlays
            Button(action: onTap) {
                photoHero
            }
            .buttonStyle(.plain)

            // Text info section
            infoSection
        }
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        .accessibilityIdentifier(
            "recipe_card_\(recipe.title.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    // MARK: Artwork hero

    private var photoHero: some View {
        ZStack(alignment: .topTrailing) {
            RecipeArt(recipe: recipe, emojiSize: 84)
                .frame(height: 200)
                .clipped()

            // Top-right: gradient + favourite
            LinearGradient(
                colors: [.black.opacity(0.3), .clear],
                startPoint: .top, endPoint: .center
            )
            .frame(height: 80)
            .frame(maxHeight: .infinity, alignment: .top)

            Button(action: onFavorite) {
                Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(recipe.isFavorite ? .pink : .white)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4)
            }
            .padding(12)
            .accessibilityIdentifier("favorite_recipe_\(recipe.id)")

            // Bottom-left: category + time badges
            VStack(alignment: .leading) {
                Spacer()
                HStack(spacing: 8) {
                    Label(recipe.category.rawValue, systemImage: recipe.category.icon)
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(recipe.category.color)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    Label("\(recipe.totalMins) min", systemImage: "clock.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(12)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Info section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title).font(.headline).foregroundStyle(.primary)
                Text(recipe.tagline).font(.caption).foregroundStyle(.secondary)
            }

            // Macro pills
            HStack(spacing: 6) {
                macroPill("🔥", "\(recipe.calories) cal",  .orange)
                macroPill("💪", "\(recipe.proteinG)g",      .blue)
                macroPill("⚡", "\(recipe.carbsG)g carbs",  .yellow)
                macroPill("🥑", "\(recipe.fatG)g fat",      .green)
            }

            // Tags row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(recipe.tags.prefix(4), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.08))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }

            // Log to Nutrition button
            Button(action: onLog) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log to Nutrition")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(recipe.category.color.opacity(0.12))
                .foregroundStyle(recipe.category.color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(recipe.category.color.opacity(0.25), lineWidth: 1)
                )
            }
            .accessibilityIdentifier("log_to_nutrition_\(recipe.title.lowercased().replacingOccurrences(of: " ", with: "_"))")
        }
        .padding(14)
    }

    private func macroPill(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 10))
            Text(text).font(.system(size: 11, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .foregroundStyle(.secondary)
    }
}

// MARK: - Nutrition Log Sheet

struct NutritionLogSheet: View {
    let recipe: FitRecipe
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var servings: Double = 1.0
    @State private var showConfirm = false

    private var scaledCalories: Int  { Int(Double(recipe.calories) * servings) }
    private var scaledProtein: Double { Double(recipe.proteinG) * servings }
    private var scaledCarbs: Double   { Double(recipe.carbsG) * servings }
    private var scaledFat: Double     { Double(recipe.fatG) * servings }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recipe artwork header
                RecipeArt(recipe: recipe, emojiSize: 64)
                    .frame(height: 160)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text(recipe.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.6)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                ScrollView {
                    VStack(spacing: 24) {
                        // Servings stepper
                        VStack(spacing: 12) {
                            Text("How many servings did you eat?")
                                .font(.headline)
                            HStack(spacing: 24) {
                                Button {
                                    if servings > 0.5 { servings -= 0.5 }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(recipe.category.color)
                                }
                                Text(servings == servings.rounded() ? "\(Int(servings))" : String(format: "%.1f", servings))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .frame(minWidth: 80)
                                Button {
                                    if servings < 5 { servings += 0.5 }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(recipe.category.color)
                                }
                            }
                            Text("1 serving ≈ \(recipe.calories) cal · \(recipe.proteinG)g protein")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // What will be logged
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Will be logged to today")
                                .font(.headline)
                            HStack(spacing: 0) {
                                logCell("🔥", "Calories",  "\(scaledCalories)",        .orange)
                                logCell("💪", "Protein",   String(format:"%.0fg", scaledProtein), .blue)
                                logCell("⚡", "Carbs",    String(format:"%.0fg", scaledCarbs),   .yellow)
                                logCell("🥑", "Fat",      String(format:"%.0fg", scaledFat),     .green)
                            }
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Confirm button
                        Button(action: logAndDismiss) {
                            Label("Log \(String(format: servings == servings.rounded() ? "%.0f" : "%.1f", servings)) serving\(servings == 1 ? "" : "s") to Nutrition",
                                  systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(recipe.category.color)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: recipe.category.color.opacity(0.35), radius: 8, y: 4)
                        }
                        .accessibilityIdentifier("confirm_log_button")
                    }
                    .padding()
                }
            }
            .navigationTitle("Log to Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_log_button")
                }
            }
        }
        .accessibilityIdentifier("nutrition_log_sheet")
    }

    private func logCell(_ icon: String, _ label: String, _ val: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.title3)
            Text(val).font(.system(size: 16, weight: .bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func logAndDismiss() {
        appState.logNutrition(
            protein:  scaledProtein,
            carbs:    scaledCarbs,
            fats:     scaledFat,
            calories: Double(scaledCalories),
            name: recipe.title,
            source: "recipe"
        )
        dismiss()
    }
}

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    let recipe: FitRecipe
    let onFavorite: () -> Void
    let onLog: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    detailPhotoHero
                    macroBar
                    Text("Nutrition values are approximate estimates per serving.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .accessibilityIdentifier("nutrition_estimate_note")
                    Picker("", selection: $tab) {
                        Text("Ingredients").tag(0)
                        Text("Instructions").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .accessibilityIdentifier("recipe_tab_picker")
                    if tab == 0 { ingredientsList } else { instructionsList }
                    actionButtons
                }
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("close_recipe_button")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onFavorite) {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(.pink)
                    }
                    .accessibilityIdentifier("toggle_favorite_button")
                }
            }
        }
        .accessibilityIdentifier("recipe_detail_view")
    }

    private var detailPhotoHero: some View {
        ZStack(alignment: .bottom) {
            RecipeArt(recipe: recipe, emojiSize: 120)
                .frame(height: 280)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .center, endPoint: .bottom)
                .frame(height: 140)

            HStack(spacing: 16) {
                detailBadge(icon: "timer",    text: "\(recipe.prepMins)m prep")
                detailBadge(icon: "flame",    text: "\(recipe.cookMins)m cook")
                detailBadge(icon: "person.2", text: "\(recipe.servings) servings")
            }
            .padding(.bottom, 16)
        }
        .frame(height: 280)
    }

    private func detailBadge(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon); Text(text).fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }

    private var macroBar: some View {
        HStack(spacing: 0) {
            macroCell("🔥", "Calories", "\(recipe.calories)")
            macroCell("💪", "Protein",  "\(recipe.proteinG)g")
            macroCell("⚡", "Carbs",    "\(recipe.carbsG)g")
            macroCell("🥑", "Fat",      "\(recipe.fatG)g")
        }
        .padding(.vertical, 14)
        .background(Color.secondary.opacity(0.05))
        .accessibilityIdentifier("recipe_macro_bar")
    }

    private func macroCell(_ icon: String, _ label: String, _ val: String) -> some View {
        VStack(spacing: 3) {
            Text(icon).font(.title3)
            Text(val).font(.system(size: 15, weight: .bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, ing in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6)).foregroundStyle(recipe.category.color)
                        .padding(.top, 7)
                    Text(ing).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("ingredient_\(i + 1)")
                if i < recipe.ingredients.count - 1 { Divider().padding(.leading, 18) }
            }
        }
        .padding().accessibilityIdentifier("ingredients_list")
    }

    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .frame(width: 30, height: 30)
                        .background(recipe.category.color.opacity(0.15))
                        .foregroundStyle(recipe.category.color)
                        .clipShape(Circle())
                    Text(step).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("instruction_step_\(i + 1)")
            }
        }
        .padding().accessibilityIdentifier("instructions_list")
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Log to Nutrition
            Button(action: { onLog(); dismiss() }) {
                Label("Log to Nutrition", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(recipe.category.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: recipe.category.color.opacity(0.3), radius: 8, y: 4)
            }
            .accessibilityIdentifier("log_to_nutrition_detail_button")
        }
        .padding()
    }
}
