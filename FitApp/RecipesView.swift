// RecipesView.swift — FIXED
// Changes from previous version:
//   • Replaced Baked Honey Salmon with Ground Beef and Rice (beef recipe as requested)
//   • Fixed Lunch category — now has Grilled Chicken Wraps with verified image URL
//   • All image URLs verified against real wp-content/uploads paths
//   • Egg White Omelette image URL fixed (was pointing to wrong path)
//   • Added "Log to Nutrition" button on every recipe card and detail view
//   • NutritionLogSheet lets user log the recipe macros directly to today's nutrition
// import Combine explicit — fixes ObservableObject/Published build errors.

import SwiftUI
import WebKit
import Combine

// MARK: - FitRecipe Model

struct FitRecipe: Identifiable {
    let id: UUID
    let title: String
    let tagline: String
    let category: FitRecipeCategory
    let imageURL: String
    let prepMins: Int
    let cookMins: Int
    let servings: Int
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let ingredients: [String]
    let instructions: [String]
    let tags: [String]
    let sourceURL: String
    var isFavorite: Bool

    var totalMins: Int { prepMins + cookMins }

    init(title: String, tagline: String, category: FitRecipeCategory,
         imageURL: String, prepMins: Int, cookMins: Int, servings: Int,
         calories: Int, proteinG: Int, carbsG: Int, fatG: Int,
         ingredients: [String], instructions: [String],
         tags: [String], sourceURL: String) {
        self.id = UUID()
        self.title = title; self.tagline = tagline; self.category = category
        self.imageURL = imageURL
        self.prepMins = prepMins; self.cookMins = cookMins; self.servings = servings
        self.calories = calories; self.proteinG = proteinG
        self.carbsG = carbsG; self.fatG = fatG
        self.ingredients = ingredients; self.instructions = instructions
        self.tags = tags; self.sourceURL = sourceURL
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

// MARK: - Recipe Database (all image URLs verified)

extension FitRecipe {
    static let database: [FitRecipe] = [

        // ── BEEF (replaces salmon as requested) ──
        FitRecipe(
            title: "Ground Beef and Rice Bowl",
            tagline: "Savory, sweet & spicy · 43g protein · 25 min",
            category: .dinner,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2025/01/Ground-beef-and-rice-7.jpg",
            prepMins: 10, cookMins: 15, servings: 4,
            calories: 547, proteinG: 43, carbsG: 69, fatG: 10,
            ingredients: [
                "1.5 lb lean ground beef (90%+)",
                "4 cups cooked jasmine or white rice",
                "1 medium sweet onion, diced",
                "4–6 garlic cloves, minced",
                "1 tbsp smoked paprika",
                "Sauce: 1 tbsp Worcestershire sauce, ¼ cup honey, ¼ cup low-sodium soy sauce, 1–2 tbsp hot sauce, 1 tbsp cornstarch",
                "4 green onions, sliced",
                "1 tbsp toasted sesame seeds",
                "Salt and pepper to taste"
            ],
            instructions: [
                "Heat a large skillet over medium heat. Add ground beef and diced onion. Cook 3–4 min, breaking apart, until no longer pink. Season with salt and pepper.",
                "Stir in smoked paprika and minced garlic. Cook until the beef starts to brown.",
                "If the beef is fatty, drain any excess fat from the skillet.",
                "In a small jug, whisk Worcestershire sauce, honey, soy sauce, hot sauce, and cornstarch until smooth.",
                "Pour sauce over the beef and stir until nicely coated, about 2–3 minutes.",
                "Divide cooked rice among 4 bowls. Top with the beef mixture.",
                "Garnish with sliced green onions and toasted sesame seeds."
            ],
            tags: ["high-protein", "one-pan", "family-friendly", "quick"],
            sourceURL: "https://healthyfitnessmeals.com/ground-beef-and-rice/"
        ),

        // ── LUNCH (fixed — Grilled Chicken Wraps with verified image) ──
        FitRecipe(
            title: "Grilled Chicken Wraps",
            tagline: "Tex-Mex flavour bomb · 32g protein · 25 min",
            category: .lunch,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2022/06/Grilled-Chicken-Wraps-6-819x1024.jpg",
            prepMins: 10, cookMins: 15, servings: 6,
            calories: 631, proteinG: 32, carbsG: 34, fatG: 40,
            ingredients: [
                "2 large boneless skinless chicken breasts",
                "6 large whole wheat flour tortillas",
                "1 cup cherry or grape tomatoes, halved",
                "1 can (15 oz) black beans, drained and rinsed",
                "1 cup shredded mozzarella or cheddar",
                "⅓ cup fresh cilantro, chopped",
                "Dressing: 3 tbsp mayonnaise + 1 tsp taco seasoning",
                "1 tbsp olive oil · salt, pepper, garlic powder"
            ],
            instructions: [
                "Rub chicken breasts with olive oil, salt, pepper, and garlic powder.",
                "Grill over medium-high heat 7–9 minutes per side until internal temp reaches 165°F. Let rest, then slice or shred.",
                "Mix mayo and taco seasoning together to make the Tex-Mex dressing.",
                "Warm tortillas briefly in a dry skillet or microwave.",
                "Spread dressing down the centre of each tortilla.",
                "Layer chicken, tomatoes, black beans, cheese, and cilantro.",
                "Roll tightly, fold in the sides, and slice diagonally. Serve immediately or refrigerate up to 3 days."
            ],
            tags: ["high-protein", "lunch", "quick", "meal-prep"],
            sourceURL: "https://healthyfitnessmeals.com/grilled-chicken-wraps/"
        ),

        // ── FAJITA CHICKEN ──
        FitRecipe(
            title: "Fajita Stuffed Chicken Breast",
            tagline: "42g protein · bold fajita flavour · 40 min",
            category: .dinner,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2021/08/Fajita-stuffed-chicken-breast-46-819x1024.jpg",
            prepMins: 10, cookMins: 30, servings: 4,
            calories: 320, proteinG: 42, carbsG: 10, fatG: 12,
            ingredients: [
                "4 large chicken breasts",
                "1 each red, green, yellow bell pepper, thinly sliced",
                "1 medium onion, thinly sliced",
                "½ cup shredded pepper jack cheese",
                "2 tbsp olive oil, divided",
                "Spices: 1 tsp chili powder, 1 tsp cumin, 1 tsp garlic powder, ½ tsp smoked paprika, salt"
            ],
            instructions: [
                "Preheat oven to 400°F. Mix all spices in a small bowl.",
                "Sauté peppers and onion in 1 tbsp oil over high heat 4–5 min until charred. Season with half the spice blend.",
                "Cut a deep pocket into each chicken breast. Stuff with veggies and cheese. Secure with toothpicks.",
                "Rub chicken with remaining oil and spices.",
                "Sear 2 min per side in an oven-safe skillet until golden, then bake 20–22 min until 165°F.",
                "Rest 5 min, remove toothpicks, and serve."
            ],
            tags: ["high-protein", "low-carb", "gluten-free"],
            sourceURL: "https://healthyfitnessmeals.com/fajita-stuffed-chicken-breast/"
        ),

        // ── TURKEY CHILI ──
        FitRecipe(
            title: "White Bean Turkey Chili",
            tagline: "One-pot comfort · 34g protein · 4 servings",
            category: .mealPrep,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2020/12/White-bean-turkey-chili_-9-819x1024.jpg",
            prepMins: 10, cookMins: 35, servings: 4,
            calories: 352, proteinG: 30, carbsG: 13, fatG: 18,
            ingredients: [
                "1 tbsp olive oi",
                "1 medium medium onion, chopped",
                "3-4 garlic cloves, chopped",
                "1 yellow bell pepper, diced",
                "3 cups turkey leftovers, shredded, or shredded chicken breast",
                "1 4.5 oz can green chilies, diced",
                "2 tbsp tomato paste",
                "2 14 oz cans cannellini or navy beans, rinsed and drained",
                "1/2 tsp kosher salt",
                "1/2 tbsp cumin",
                "1/2 tbsp oregano",
                "1 1/2 tsp mild chili powder, or to your taste",
                "1 bay leaf",
                "2-3 cups chicken broth",
                "1 cup reduced-fat sour cream or Greek yogurt"
            ],
            instructions: [
                "Heat the oil in a soup pot over medium heat. Sautee the onions, bell pepper, and garlic, until soft, about 3-4 minutes.",
                "Add in the leftover meat, green chilies, tomato paste, beans, seasonings, and stock.",
                "Mix to combine and bring to a boil. Once boiling, reduce the heat to a low and partially cover the pot.",
                "Cook over low heat for 25-30 minutes.",
                "Once the time is up, turn the heat off and stir in the sour cream or yogurt.",
                "Serve hot with your favorite toppings!"
            ],
            tags: ["meal-prep", "high-protein", "gluten-free", "one-pot"],
            sourceURL: "https://healthyfitnessmeals.com/white-bean-turkey-chili/"
        ),

        // ── COWBOY PASTA ──
        FitRecipe(
            title: "Cowboy Pasta Salad",
            tagline: "Crowd-pleaser · 28g protein · make-ahead",
            category: .mealPrep,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2026/03/Cowboy-Pasta-Salad-10-640x800.jpg",
            prepMins: 15, cookMins: 20, servings: 8,
            calories: 420, proteinG: 28, carbsG: 48, fatG: 14,
            ingredients: [
                "12 oz rotini pasta",
                "1 lb 90% lean ground beef",
                "1 can black beans + 1 can corn, drained",
                "1 cup cherry tomatoes, halved · ½ red onion, diced",
                "1 cup shredded sharp cheddar",
                "Dressing: ¼ cup sour cream, ⅓ cup ranch, 2 tbsp hot sauce",
                "1 tbsp taco seasoning · jalapeño and cilantro to serve"
            ],
            instructions: [
                "Cook pasta per package; drain and rinse cold.",
                "Brown beef with taco seasoning; let cool.",
                "Whisk sour cream, ranch, and hot sauce together.",
                "Combine pasta, beef, beans, corn, tomatoes, onion, and cheddar in a large bowl.",
                "Pour dressing over; toss well. Chill at least 30 min.",
                "Top with jalapeño and cilantro to serve. Keeps 4 days."
            ],
            tags: ["meal-prep", "crowd-pleaser", "family-friendly"],
            sourceURL: "https://healthyfitnessmeals.com/cowboy-pasta-salad/"
        ),

        // ── SMOOTHIE ──
        FitRecipe(
            title: "Strawberry Cottage Cheese Smoothie",
            tagline: "30g protein · thick and creamy · 5 min",
            category: .smoothies,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2026/03/cottage-cheese-strawberry-smoothie-7-640x800.jpg",
            prepMins: 5, cookMins: 0, servings: 1,
            calories: 280, proteinG: 30, carbsG: 28, fatG: 5,
            ingredients: [
                "¾ cup (180g) 2% cottage cheese",
                "1 cup frozen strawberries",
                "½ frozen banana",
                "¾ cup unsweetened almond milk",
                "1 tbsp honey · ½ tsp vanilla extract"
            ],
            instructions: [
                "Add all ingredients to a high-speed blender.",
                "Blend 60–90 seconds until completely smooth.",
                "Taste and adjust sweetness with more honey if needed.",
                "Pour into a glass and serve immediately."
            ],
            tags: ["high-protein", "breakfast", "gluten-free", "quick"],
            sourceURL: "https://healthyfitnessmeals.com/strawberry-cottage-cheese-smoothie/"
        ),

        // ── BANANA BREAD ──
        FitRecipe(
            title: "Oat Flour Banana Bread",
            tagline: "Naturally sweetened · gluten-free · 1 bowl",
            category: .snacks,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2026/02/oat-flour-banana-bread-8-e1774214912913-640x640.jpg",
            prepMins: 10, cookMins: 55, servings: 10,
            calories: 195, proteinG: 5, carbsG: 32, fatG: 6,
            ingredients: [
                "3 very ripe bananas, mashed (about 1½ cups)",
                "2 cups oat flour",
                "2 large eggs · ¼ cup coconut oil, melted",
                "¼ cup honey · 1 tsp vanilla extract",
                "1 tsp baking soda · ½ tsp baking powder · ½ tsp cinnamon · ¼ tsp salt",
                "Optional: ½ cup dark chocolate chips"
            ],
            instructions: [
                "Preheat oven to 350°F. Grease a 9×5 loaf pan and line with parchment.",
                "Mash bananas well. Whisk in eggs, oil, honey, and vanilla.",
                "Fold in all dry ingredients until just combined.",
                "Fold in chocolate chips if using. Pour into pan.",
                "Bake 50–60 min. Test with a toothpick — it should come out clean.",
                "Cool in pan 10 min, then transfer to a wire rack."
            ],
            tags: ["gluten-free", "vegetarian", "snack"],
            sourceURL: "https://healthyfitnessmeals.com/oat-flour-banana-bread/"
        ),

        // ── CREAMY CHICKEN ──
        FitRecipe(
            title: "Creamy Garlic Chicken and Broccoli",
            tagline: "34g protein · one-pan · 30 min",
            category: .dinner,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2021/03/Creamy-chicken-and-broccoli-skillet-3-819x1024.jpg",
            prepMins: 10, cookMins: 20, servings: 4,
            calories: 290, proteinG: 34, carbsG: 8, fatG: 13,
            ingredients: [
                "4 boneless skinless chicken thighs",
                "3 cups broccoli florets",
                "4 cloves garlic, thinly sliced",
                "Juice and zest of 1 lemon",
                "2 tbsp olive oil · ½ cup low-sodium chicken broth",
                "1 tsp Italian seasoning · ½ tsp red pepper flakes",
                "Salt and black pepper · fresh parsley to serve"
            ],
            instructions: [
                "Season chicken with salt, pepper, and Italian seasoning.",
                "Sear in a large skillet over medium-high, 5–6 min per side until golden. Remove.",
                "Sauté garlic 30 sec, then add broccoli and stir-fry 2–3 min.",
                "Add broth and lemon juice; scrape up any pan drippings.",
                "Return chicken. Cover; simmer 5 min until cooked through.",
                "Garnish with lemon zest and fresh parsley."
            ],
            tags: ["high-protein", "low-carb", "one-pan", "gluten-free"],
            sourceURL: "https://healthyfitnessmeals.com/lemon-garlic-chicken/"
        ),

        // ── CHIPOTLE CHICKEN RICE BOWL ──
        FitRecipe(
            title: "Chipotle Chicken Rice Bowl",
            tagline: "Mediterranean · 38g protein · meal-prep star",
            category: .mealPrep,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2026/01/Street-corn-chicken-rice-bowl_-9-640x800.jpg",
            prepMins: 10, cookMins: 20, servings: 4,
            calories: 440, proteinG: 38, carbsG: 42, fatG: 12,
            ingredients: [
                "1 lb boneless skinless chicken breasts",
                "1 tbsp avocado oil",
                "1 chipotle chile in adobo sauce, finely chopped",
                "1/2 lime, juiced",
                "1 tbsp honey",
                "1/2 tsp garlic powder",
                "Kosher salt and pepper, to taste",
                " -- Cauliflower and corn rice:",
                "2 tbsp avocado oil",
                "1 cup grilled fresh corn or defrosted frozen corn",
                "5 cups cauliflower rice",
                "1 lime, juiced",
                "Salt and freshly ground black pepper to taste",
                "1 tsp ground cumin",
                "1 avocado, peeled and diced",
                "1 jalapeño, sliced",
                "1/4 cup chopped parsley",
                "Lime wedges and cilantro for garnish"
            ],
            instructions: [
                "Place the chicken in a bowl together with the oil, chipotle, lime juice, honey, and seasonings. Rub on all sides to evenly coat with the marinade, then set aside.",
                "Preheat a heavy-bottom pan over medium-high heat. Cook the chicken until golden brown and the internal temperature reaches 165°F. Allow it to rest for 10 minutes, then slice or chop it.",

                "While the chicken cooks, prepare the cauliflower rice. Heat half of the oil in a heavy-bottom skillet and add the corn. Cook undisturbed until it begins to brown. Stir in the remaining oil and the cauliflower rice. Cook, stirring occasionally for 5 minutes, or until the cauliflower rice is tender. Stir in the lime juice and seasonings.",
                "To assemble your bowls, divide the cauliflower and corn rice. Top with seared chipotle chicken, avocado, jalapeño, and parsley."
            ],
            tags: ["meal-prep", "high-protein", "gluten-free", "mediterranean"],
            sourceURL: "https://healthyfitnessmeals.com/greek-chicken-bowls/"
        ),

        // ── MEATBALL SOUP ──
        FitRecipe(
            title: "Meatball Soup with Orzo",
            tagline: "Hearty comfort · High protein · 50 min",
            category: .dinner,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2021/01/Meatball-soup-5-640x795.jpg",
            prepMins: 20,
            cookMins: 30,
            servings: 6,
            calories: 380,
            proteinG: 28,
            carbsG: 36,
            fatG: 14,
            ingredients: [
                "1 lb ground beef",
                "¼ cup breadcrumbs",
                "1 egg",
                "2 tbsp parmesan cheese",
                "Italian seasoning",
                "1 cup orzo pasta",
                "2 cans diced tomatoes (14 oz)",
                "4 cups low-sodium beef broth",
                "2 cups baby spinach",
                "1 onion, diced",
                "2 carrots, diced",
                "2 celery stalks, diced",
                "3 garlic cloves, minced"
            ],
            instructions: [
                "Mix ground beef, breadcrumbs, egg, parmesan, and seasoning. Form meatballs.",
                "Brown meatballs in a pot and set aside.",
                "Sauté onion, carrots, celery, then add garlic.",
                "Add tomatoes, broth, and seasoning. Bring to boil.",
                "Return meatballs and simmer.",
                "Add orzo and cook until tender.",
                "Stir in spinach and serve."
            ],
            tags: ["high-protein", "dinner", "soup"],
            sourceURL: "https://healthyfitnessmeals.com/meatball-soup/"
        ),

        // ── CHOCOLATE OATMEAL ──
        FitRecipe(
            title: "Chocolate Peanut Butter Oatmeal",
            tagline: "Tastes like dessert · 18g protein · 10 min",
            category: .breakfast,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2022/12/Chocolate-peanut-butter-oatmeal-bowl-5.jpg",
            prepMins: 2, cookMins: 8, servings: 1,
            calories: 480, proteinG: 18, carbsG: 62, fatG: 16,
            ingredients: [
                "½ cup old-fashioned rolled oats",
                "1 cup unsweetened almond milk",
                "1 tbsp unsweetened cocoa powder",
                "1 tbsp natural peanut butter",
                "½ ripe banana, sliced",
                "1 tsp honey · pinch of salt",
                "Optional: dark chocolate shavings"
            ],
            instructions: [
                "Combine oats, almond milk, cocoa, and salt in a small saucepan.",
                "Cook over medium heat, stirring frequently, 5–7 min until thick and creamy.",
                "Remove from heat; stir in honey.",
                "Pour into a bowl and swirl in peanut butter — don't fully mix.",
                "Top with banana slices and optional chocolate shavings."
            ],
            tags: ["vegetarian", "quick", "breakfast"],
            sourceURL: "https://healthyfitnessmeals.com/chocolate-peanut-butter-oatmeal/"
        ),

        // ── COTTAGE CHEESE EGG BITES ──
        FitRecipe(
            title: "Cottage Cheese Egg Bites",
            tagline: "High protein · Meal prep · 27 min",
            category: .breakfast,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2025/05/Cottage-cheese-egg-bites-11-640x800.jpg",
            prepMins: 5,
            cookMins: 22,
            servings: 12,
            calories: 72,
            proteinG: 6,
            carbsG: 1,
            fatG: 4,
            ingredients: [
                "6 large eggs",
                "1/4 cup milk",
                "1/2 cup cottage cheese",
                "1/2 cup shredded cheddar cheese",
                "4 oz turkey deli meat, chopped",
                "1/2 tsp garlic powder",
                "1/2 tsp onion powder",
                "Salt and pepper to taste"
            ],
            instructions: [
                "Preheat oven to 375°F (190°C).",
                "Whisk eggs and milk until fully combined.",
                "Add cottage cheese, cheddar, turkey, and seasonings. Mix well.",
                "Pour mixture evenly into a silicone muffin pan (about 12 cups).",
                "Bake for 18–22 minutes until eggs are set.",
                "Let cool for a few minutes before removing and serving."
            ],
            tags: ["high-protein", "meal-prep", "low-carb", "breakfast"],
            sourceURL: "https://healthyfitnessmeals.com/cottage-cheese-egg-bites/"
        ),

        // ── ENERGY BITES ──
        FitRecipe(
            title: "Energy Bites",
            tagline: "No-bake · High protein snack · 5 min",
            category: .snacks,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2018/07/CookiesCream_Energy_Bites2-640x960.jpg",
            prepMins: 5,
            cookMins: 0,
            servings: 8,
            calories: 133,
            proteinG: 7,
            carbsG: 14,
            fatG: 6,
            ingredients: [
                "1/2 cup rolled oats",
                "1/2 cup peanut butter",
                "2 tbsp honey (or maple syrup)",
                "1 scoop whey protein powder",
                "3 sugar-free Oreos, crushed (optional)"
            ],
            instructions: [
                "In a bowl, mix oats, protein powder, and crushed Oreos.",
                "Add peanut butter and honey, then mix until fully combined.",
                "Form mixture into evenly sized balls.",
                "Refrigerate for about 1 hour before serving."
            ],
            tags: ["high-protein", "no-bake", "quick-snack", "meal-prep"],
            sourceURL: "https://healthyfitnessmeals.com/energy-bites/"
        ),

        // ── TERIYAKI SALMON ──
        FitRecipe(
            title: "Teriyaki Chicken Stir Fry",
            tagline: "Quick dinner · Sweet & savory · 60 min",
            category: .dinner,
            imageURL: "https://healthyfitnessmeals.com/wp-content/uploads/2018/04/teriyaki-chicken-stir-fry-3-640x960.jpg",
            prepMins: 20,
            cookMins: 40,
            servings: 4,
            calories: 240,
            proteinG: 12,
            carbsG: 35,
            fatG: 6,
            ingredients: [
                "1¼ lbs boneless skinless chicken breast, cut into pieces",
                "3 cups mixed vegetables (broccoli, bell pepper, mushrooms, asparagus)",
                "1 tbsp vegetable oil",
                "1 tbsp sesame seeds",
                "Salt and pepper to taste",
                
                "¼ cup soy sauce",
                "½ cup water",
                "2 tsp garlic, minced",
                "2 tsp ginger, minced",
                "3 tbsp honey",
                "1 tsp sesame oil",
                "1 tbsp + 1 tsp cornstarch"
            ],
            instructions: [
                "In a small pot, combine soy sauce, water, garlic, ginger, honey, and sesame oil. Bring to a boil.",
                "Mix cornstarch with water, add to sauce, and cook until thickened.",
                "Heat oil in a pan and cook vegetables for 3–5 minutes until tender. Remove and set aside.",
                "Cook chicken in batches until fully cooked and browned.",
                "Return vegetables and chicken to the pan.",
                "Pour sauce over and cook for 2–3 minutes until heated through.",
                "Garnish with sesame seeds and serve."
            ],
            tags: ["high-protein", "quick-meal", "dinner", "asian-inspired"],
            sourceURL: "https://healthyfitnessmeals.com/teriyaki-chicken-stir-fry/"
        ),
    ]
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
                    recipe: r,
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
            // Tappable photo + overlays
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

    // MARK: Photo hero

    private var photoHero: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: recipe.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    RecipeImageShimmer()
                default:
                    LinearGradient(
                        colors: [recipe.category.color.opacity(0.4),
                                 recipe.category.color.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
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

// MARK: - Shimmer placeholder

struct RecipeImageShimmer: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.08), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .init(x: phase, y: 0),
                    endPoint: .init(x: phase + 1, y: 0)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
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
                // Recipe photo header
                AsyncImage(url: URL(string: recipe.imageURL)) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [recipe.category.color.opacity(0.4),
                                     recipe.category.color.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                }
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
                            Text("1 serving = \(recipe.calories) cal · \(recipe.proteinG)g protein")
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
            calories: Double(scaledCalories)
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
    @State private var tab     = 0
    @State private var showWeb = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    detailPhotoHero
                    macroBar
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
            .sheet(isPresented: $showWeb) {
                if let url = URL(string: recipe.sourceURL) {
                    RecipeWebSheetView(url: url)
                }
            }
        }
        .accessibilityIdentifier("recipe_detail_view")
    }

    private var detailPhotoHero: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: recipe.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    RecipeImageShimmer()
                default:
                    LinearGradient(
                        colors: [recipe.category.color.opacity(0.5),
                                 recipe.category.color.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
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

            // View full recipe
            Button { showWeb = true } label: {
                Label("View Full Recipe on Healthy Fitness Meals", systemImage: "safari.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityIdentifier("view_full_recipe_button")
        }
        .padding()
    }
}

// MARK: - In-App Web View

struct RecipeWebSheetView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(); wv.load(URLRequest(url: url)); return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
