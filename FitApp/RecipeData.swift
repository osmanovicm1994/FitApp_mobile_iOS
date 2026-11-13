// RecipeData.swift
// FitApp's built-in recipes. All recipes, wording and artwork here are original FitApp content.
//
// Nutrition values are APPROXIMATE per-serving estimates calculated from typical ingredient
// values (USDA-style averages). They will differ with brands, cuts and portion sizes, and the
// app presents them as estimates. Do not copy text or images from other websites into this file.

import Foundation

extension FitRecipe {
    static let database: [FitRecipe] = [

        FitRecipe(
            title: "Ground Beef and Rice Bowl",
            tagline: "Sweet-savory beef over rice · 29g protein · 25 min",
            category: .dinner, emoji: "🍚",
            prepMins: 10, cookMins: 15, servings: 4,
            calories: 390, proteinG: 29, carbsG: 47, fatG: 9,
            ingredients: [
                "1 lb (450 g) lean ground beef (93%)",
                "3 cups cooked white rice",
                "1 small onion, finely chopped",
                "3 garlic cloves, minced",
                "2 tbsp soy sauce (low sodium)",
                "2 tbsp honey",
                "1–2 tsp chili sauce, to taste",
                "2 green onions, sliced",
                "2 tsp sesame seeds"
            ],
            instructions: [
                "Cook the rice according to the package and keep it warm.",
                "Brown the beef and onion in a large nonstick skillet over medium-high heat for 5–6 minutes, breaking the meat into small crumbles.",
                "Add the garlic and cook for 30 seconds, then drain off any excess fat.",
                "Stir the soy sauce, honey and chili sauce together and pour over the beef. Simmer for 2–3 minutes until glossy.",
                "Spoon the beef over the rice and finish with green onions and sesame seeds."
            ],
            tags: ["high-protein", "one-pan", "quick", "family-friendly"]
        ),

        FitRecipe(
            title: "Grilled Chicken Wraps",
            tagline: "Lime-yogurt sauce · 39g protein · 27 min",
            category: .lunch, emoji: "🌯",
            prepMins: 15, cookMins: 12, servings: 4,
            calories: 420, proteinG: 39, carbsG: 33, fatG: 14,
            ingredients: [
                "1 lb (450 g) chicken breast, pounded to an even thickness",
                "1 tbsp olive oil",
                "1 tsp each garlic powder, paprika and salt",
                "4 whole-wheat tortillas (8 inch)",
                "½ can black beans, drained and rinsed",
                "1 cup cherry tomatoes, halved",
                "½ cup (55 g) shredded cheddar",
                "⅓ cup plain Greek yogurt",
                "Juice of ½ lime and 1 tsp taco seasoning",
                "Fresh cilantro, chopped"
            ],
            instructions: [
                "Coat the chicken with the oil and spices. Grill or pan-sear 5–6 minutes per side until it reaches 165°F (74°C), then rest 5 minutes and slice.",
                "Stir the yogurt, lime juice and taco seasoning into a quick sauce.",
                "Warm the tortillas for about 20 seconds per side.",
                "Spread each tortilla with sauce, then add chicken, beans, tomatoes, cheese and cilantro.",
                "Fold in the sides and roll up tightly. Slice in half to serve."
            ],
            tags: ["high-protein", "lunch", "meal-prep", "quick"]
        ),

        FitRecipe(
            title: "Fajita Stuffed Chicken Breast",
            tagline: "Peppers and cheese inside · 42g protein · 45 min",
            category: .dinner, emoji: "🫑",
            prepMins: 15, cookMins: 30, servings: 4,
            calories: 325, proteinG: 42, carbsG: 6, fatG: 13,
            ingredients: [
                "4 chicken breasts (about 6 oz / 170 g each)",
                "2 bell peppers (any colours), thinly sliced",
                "½ onion, thinly sliced",
                "½ cup (55 g) shredded pepper jack cheese",
                "1½ tbsp olive oil, divided",
                "1 tsp chili powder, 1 tsp cumin, 1 tsp garlic powder, ½ tsp paprika, ½ tsp salt"
            ],
            instructions: [
                "Heat the oven to 400°F (200°C) and mix the spices in a small bowl.",
                "Cook the peppers and onion in 1 tbsp of the oil over high heat for 4–5 minutes until lightly charred. Stir in half the spice mix and let cool slightly.",
                "Slice a deep pocket into the side of each chicken breast. Fill with the vegetables and cheese and close with toothpicks.",
                "Rub the outside with the remaining oil and spices.",
                "Sear in an oven-safe skillet for 2 minutes per side, then bake 20–25 minutes until 165°F (74°C).",
                "Rest for 5 minutes, remove the toothpicks and serve."
            ],
            tags: ["high-protein", "low-carb", "gluten-free"]
        ),

        FitRecipe(
            title: "White Bean Turkey Chili",
            tagline: "One-pot meal prep · 36g protein · 45 min",
            category: .mealPrep, emoji: "🌶️",
            prepMins: 10, cookMins: 35, servings: 4,
            calories: 413, proteinG: 36, carbsG: 38, fatG: 14,
            ingredients: [
                "1 lb (450 g) ground turkey (93% lean)",
                "1 tbsp olive oil",
                "1 onion and 1 bell pepper, diced",
                "4 garlic cloves, minced",
                "2 cans (15 oz) white beans, drained and rinsed",
                "1 can (4 oz) diced green chiles",
                "2 tbsp tomato paste",
                "3 cups low-sodium chicken broth",
                "1 tsp cumin, 1 tsp oregano, 1 tsp chili powder, ½ tsp salt",
                "½ cup plain Greek yogurt, to finish"
            ],
            instructions: [
                "Heat the oil in a large pot and cook the onion and pepper for 4 minutes.",
                "Add the turkey and garlic and cook, breaking it up, until no pink remains.",
                "Stir in the tomato paste and spices for 1 minute.",
                "Add the beans, green chiles and broth. Simmer uncovered for 25 minutes, stirring now and then.",
                "Take the pot off the heat and stir in the yogurt. Adjust the salt and serve."
            ],
            tags: ["meal-prep", "high-protein", "gluten-free", "one-pot"]
        ),

        FitRecipe(
            title: "Cowboy Pasta Salad",
            tagline: "Beef, beans and corn · 32g protein · make-ahead",
            category: .mealPrep, emoji: "🥗",
            prepMins: 15, cookMins: 15, servings: 6,
            calories: 412, proteinG: 32, carbsG: 47, fatG: 11,
            ingredients: [
                "8 oz (225 g) rotini or other short pasta",
                "1 lb (450 g) lean ground beef (93%)",
                "1 tbsp taco seasoning",
                "1 can black beans, drained and rinsed",
                "1 cup corn kernels (frozen or canned)",
                "1 cup cherry tomatoes, halved",
                "½ red onion, finely diced",
                "¾ cup (85 g) shredded cheddar",
                "¾ cup plain Greek yogurt",
                "Juice of 1 lime and hot sauce to taste"
            ],
            instructions: [
                "Cook the pasta until just tender, then rinse under cold water and drain well.",
                "Brown the beef with the taco seasoning, drain any fat and let it cool for 10 minutes.",
                "Whisk the yogurt, lime juice and hot sauce together.",
                "Toss the pasta, beef, beans, corn, tomatoes, onion and cheese with the dressing.",
                "Chill for 30 minutes before serving. Keeps up to 4 days in the fridge."
            ],
            tags: ["meal-prep", "crowd-pleaser", "high-protein"]
        ),

        FitRecipe(
            title: "Strawberry Cottage Cheese Smoothie",
            tagline: "Thick and creamy · 21g protein · 5 min",
            category: .smoothies, emoji: "🍓",
            prepMins: 5, cookMins: 0, servings: 1,
            calories: 283, proteinG: 21, carbsG: 40, fatG: 6,
            ingredients: [
                "¾ cup (170 g) 2% cottage cheese",
                "1 cup frozen strawberries",
                "½ frozen banana",
                "¾ cup unsweetened almond milk",
                "1 tsp honey (optional)"
            ],
            instructions: [
                "Add the almond milk and cottage cheese to a blender first, then the fruit.",
                "Blend on high for about a minute until completely smooth.",
                "Taste, add honey if you like it sweeter, and serve right away."
            ],
            tags: ["high-protein", "breakfast", "quick", "gluten-free"]
        ),

        FitRecipe(
            title: "Oat Flour Banana Bread",
            tagline: "Honey-sweetened · one bowl · 10 slices",
            category: .snacks, emoji: "🍌",
            prepMins: 10, cookMins: 55, servings: 10,
            calories: 190, proteinG: 5, carbsG: 28, fatG: 7,
            ingredients: [
                "3 very ripe bananas, mashed",
                "2 cups (200 g) oat flour (certified gluten-free if needed)",
                "2 eggs",
                "3 tbsp coconut oil, melted",
                "¼ cup honey",
                "1 tsp vanilla extract",
                "1 tsp baking soda, ½ tsp cinnamon, ¼ tsp salt",
                "Optional: 2 tbsp dark chocolate chips (not included in the nutrition values)"
            ],
            instructions: [
                "Heat the oven to 350°F (175°C) and line a 9×5 inch loaf pan with parchment.",
                "Whisk the bananas, eggs, coconut oil, honey and vanilla until smooth.",
                "Stir in the oat flour, baking soda, cinnamon and salt until just combined.",
                "Pour into the pan and bake 50–55 minutes, until a toothpick comes out clean.",
                "Cool in the pan for 10 minutes, then lift out and cool completely before slicing into 10."
            ],
            tags: ["vegetarian", "snack", "one-bowl"]
        ),

        FitRecipe(
            title: "Creamy Garlic Chicken and Broccoli",
            tagline: "Yogurt-lemon sauce · 35g protein · 30 min",
            category: .dinner, emoji: "🥦",
            prepMins: 10, cookMins: 20, servings: 4,
            calories: 264, proteinG: 35, carbsG: 7, fatG: 10,
            ingredients: [
                "4 boneless skinless chicken thighs (about 1.3 lb / 600 g)",
                "3 cups broccoli florets",
                "4 garlic cloves, sliced",
                "1 tbsp olive oil",
                "½ cup low-sodium chicken broth",
                "½ cup plain Greek yogurt",
                "2 tbsp lemon juice",
                "1 tbsp grated parmesan",
                "1 tsp Italian seasoning, salt and pepper"
            ],
            instructions: [
                "Season the chicken with salt, pepper and Italian seasoning.",
                "Brown the chicken in the oil over medium-high heat, about 5 minutes per side, then move it to a plate.",
                "Cook the garlic for 30 seconds, then add the broccoli and broth. Cover and steam for 3–4 minutes.",
                "Return the chicken, cover and cook about 5 more minutes until it is at least 165°F (74°C) inside.",
                "Turn off the heat. Stir the yogurt, lemon juice and parmesan together with a spoonful of the hot pan juices, then fold it into the pan.",
                "Serve right away."
            ],
            tags: ["high-protein", "low-carb", "one-pan"]
        ),

        FitRecipe(
            title: "Chipotle Chicken Rice Bowl",
            tagline: "Smoky chicken, corn and avocado · 34g protein",
            category: .mealPrep, emoji: "🥑",
            prepMins: 15, cookMins: 20, servings: 4,
            calories: 474, proteinG: 34, carbsG: 54, fatG: 14,
            ingredients: [
                "1 lb (450 g) chicken breast",
                "1 tbsp olive oil",
                "1 chipotle pepper in adobo, minced, plus 1 tbsp of the sauce",
                "Juice of 1 lime",
                "3 cups cooked brown rice",
                "1 cup corn kernels",
                "½ can black beans, drained and rinsed",
                "1 avocado, diced",
                "Cilantro, cumin and garlic powder to taste"
            ],
            instructions: [
                "Mix the oil, chipotle, adobo sauce, lime juice, ½ tsp cumin and ½ tsp garlic powder. Coat the chicken and marinate for at least 15 minutes.",
                "Cook the chicken in a hot skillet for 5–6 minutes per side until it reaches 165°F (74°C). Rest 5 minutes, then slice.",
                "Warm the corn and beans in the same pan for 2–3 minutes.",
                "Divide the rice among 4 containers or bowls and top with chicken, corn, beans, avocado and cilantro.",
                "For meal prep, keep the avocado separate and add it fresh. The rest keeps 4 days in the fridge."
            ],
            tags: ["meal-prep", "high-protein", "gluten-free"]
        ),

        FitRecipe(
            title: "Meatball Soup with Orzo",
            tagline: "Hearty and comforting · 23g protein · 50 min",
            category: .dinner, emoji: "🍲",
            prepMins: 20, cookMins: 30, servings: 6,
            calories: 296, proteinG: 23, carbsG: 27, fatG: 10,
            ingredients: [
                "1 lb (450 g) lean ground beef (93%)",
                "¼ cup breadcrumbs, 1 egg, 2 tbsp grated parmesan",
                "1 tsp Italian seasoning",
                "1 tbsp olive oil",
                "1 onion, 2 carrots and 2 celery stalks, diced",
                "3 garlic cloves, minced",
                "1 can (14 oz) diced tomatoes",
                "5 cups low-sodium beef broth",
                "¾ cup orzo",
                "2 cups baby spinach"
            ],
            instructions: [
                "Mix the beef, breadcrumbs, egg, parmesan and Italian seasoning. Roll into about 24 small meatballs.",
                "Heat the oil in a large pot and brown the meatballs in two batches. Set them aside.",
                "Cook the onion, carrots and celery for 5 minutes, then add the garlic for 30 seconds.",
                "Add the tomatoes and broth and bring to a boil. Return the meatballs and simmer for 10 minutes.",
                "Stir in the orzo and cook 8–9 minutes until tender, then add the spinach and let it wilt."
            ],
            tags: ["high-protein", "soup", "comfort-food"]
        ),

        FitRecipe(
            title: "Chocolate Peanut Butter Oatmeal",
            tagline: "Cocoa oats with banana · 12g protein · 10 min",
            category: .breakfast, emoji: "🥣",
            prepMins: 2, cookMins: 8, servings: 1,
            calories: 360, proteinG: 12, carbsG: 53, fatG: 14,
            ingredients: [
                "½ cup (40 g) rolled oats",
                "1 cup unsweetened almond milk",
                "1 tbsp unsweetened cocoa powder",
                "1 tbsp natural peanut butter",
                "½ banana, sliced",
                "1 tsp honey and a pinch of salt"
            ],
            instructions: [
                "Stir the oats, almond milk, cocoa and salt together in a small pot.",
                "Cook over medium heat for 5–7 minutes, stirring often, until thick.",
                "Stir in the honey, pour into a bowl and top with the peanut butter and banana."
            ],
            tags: ["vegetarian", "quick", "breakfast"]
        ),

        FitRecipe(
            title: "Cottage Cheese Egg Bites",
            tagline: "Make-ahead breakfast · 14g protein per 2 bites",
            category: .breakfast, emoji: "🥚",
            prepMins: 10, cookMins: 20, servings: 6,
            calories: 147, proteinG: 14, carbsG: 2, fatG: 9,
            ingredients: [
                "6 eggs",
                "½ cup (115 g) cottage cheese",
                "¼ cup milk",
                "½ cup (55 g) shredded cheddar",
                "3 oz (85 g) deli turkey, chopped",
                "½ cup chopped spinach",
                "Salt, pepper and garlic powder",
                "Makes 12 bites. One serving is 2 bites."
            ],
            instructions: [
                "Heat the oven to 375°F (190°C) and grease a 12-cup muffin tin well (or use a silicone one).",
                "Blend or whisk the eggs, milk and cottage cheese until mostly smooth.",
                "Divide the turkey, spinach and cheddar among the cups, then pour the egg mixture over.",
                "Bake 18–20 minutes until set and lightly puffed.",
                "Cool for 5 minutes before removing. Keeps 4 days in the fridge or 2 months in the freezer."
            ],
            tags: ["high-protein", "meal-prep", "low-carb", "breakfast"]
        ),

        FitRecipe(
            title: "Energy Bites",
            tagline: "No-bake peanut butter snack · 6g protein each",
            category: .snacks, emoji: "🍪",
            prepMins: 10, cookMins: 0, servings: 12,
            calories: 131, proteinG: 6, carbsG: 14, fatG: 7,
            ingredients: [
                "1 cup (80 g) rolled oats",
                "½ cup (130 g) natural peanut butter",
                "¼ cup honey",
                "1 scoop (30 g) vanilla protein powder",
                "2 tbsp mini dark chocolate chips",
                "Makes 12 bites. One serving is 1 bite."
            ],
            instructions: [
                "Mix everything in a bowl until a thick, sticky dough forms. Add a splash of milk if it is too dry.",
                "Chill the dough for 15 minutes.",
                "Roll into 12 equal balls.",
                "Store in the fridge for up to a week."
            ],
            tags: ["high-protein", "no-bake", "snack", "meal-prep"]
        ),

        FitRecipe(
            title: "Teriyaki Chicken Stir Fry",
            tagline: "Quick homemade sauce · 38g protein · 30 min",
            category: .dinner, emoji: "🥢",
            prepMins: 15, cookMins: 15, servings: 4,
            calories: 449, proteinG: 38, carbsG: 50, fatG: 10,
            ingredients: [
                "1¼ lb (570 g) chicken breast, cut into bite-size pieces",
                "3 cups mixed vegetables (broccoli, bell pepper, snap peas)",
                "1 tbsp neutral oil",
                "3 cups cooked white rice, to serve",
                "Sauce: 3 tbsp soy sauce, 2 tbsp honey, 1 tbsp rice vinegar, 2 tsp each minced garlic and ginger, 1 tsp sesame oil, 2 tsp cornstarch, ¼ cup water",
                "1 tbsp sesame seeds"
            ],
            instructions: [
                "Whisk all the sauce ingredients together until the cornstarch dissolves.",
                "Heat half the oil in a large skillet or wok over high heat and stir-fry the vegetables for 3–4 minutes. Remove them.",
                "Add the remaining oil and cook the chicken for 5–6 minutes until golden and cooked through.",
                "Return the vegetables, pour in the sauce and stir for 1–2 minutes until it thickens.",
                "Serve over the rice, sprinkled with sesame seeds."
            ],
            tags: ["high-protein", "quick", "asian-inspired", "dinner"]
        ),
    ]
}
