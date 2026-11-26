# CLAUDE.md — FitApp iOS

> Project rules and conventions for the FitApp iOS SwiftUI app.
> Read this before writing, editing, or reviewing any Swift code in this repo.

---

## 📁 Project layout

```
FitApp_mobile_iOS/
└── FitApp/                     ← All source lives here (flat — no subfolders)
    ├── FitAppApp.swift          ← @main entry point; injects AppState as @StateObject
    ├── AppState.swift           ← Central ObservableObject — ALL state + business logic
    ├── RootView.swift           ← Top-level router: onboarding vs MainTabView
    ├── MainTabView.swift        ← Tab bar (5 tabs with accessibilityIdentifier)
    ├── OnboardingView.swift     ← 3-step profile wizard (first launch only)
    ├── WorkoutView.swift        ← Today's workout: hero, exercise rows, add/finish
    ├── ExerciseLibraryView.swift← Filterable exercise library (39 exercises)
    ├── NutritionView.swift      ← Water + macro logging, quick log, meal list
    ├── CustomFoodViews.swift    ← "My Foods": MyFoodsCard (Nutrition tab) + CustomFoodEditorSheet
    ├── CustomMealViews.swift    ← "My Meals": MyMealsCard (Nutrition tab) + CustomMealEditorSheet + ingredient sheet
    ├── BuildExpiry.swift        ← Free-account 7-day install expiry: reads the signing profile, Settings section, reminder notifications
    ├── RecipesView.swift        ← Recipe browser with favorites
    ├── ProfileView.swift        ← User profile display and edit; Body Progress card
    ├── BodyTrackingViews.swift  ← Weight tracker, body measurements, charts (Settings → Body Tracking, Profile)
    ├── SettingsView.swift       ← Dark mode toggle, body tracking, backup, data reset
    ├── ExerciseDatabase.swift   ← Static exercise catalogue (Exercise.all)
    ├── ExerciseAssetLoader.swift← Loads GIF/PNG exercise assets from Assets/
    ├── PersistenceStore.swift   ← Versioned JSON file storage (used ONLY by AppState)
    ├── NumberParsing.swift      ← Locale-safe number parsing/formatting + ProfileLimits + MeasurementLimits
    ├── RecipeData.swift         ← FitRecipe.database — ORIGINAL recipe content only (no copied text/images/links)
    ├── GoogleAuthService.swift  ← Google OAuth (PKCE, no SDK) + Keychain; CloudConfig holds the iOS Client ID (used ONLY by AppState)
    ├── DriveBackupService.swift ← Drive appDataFolder upload/download of the backup JSON (used ONLY by AppState)
    ├── BackupViews.swift        ← Settings backup section, restore sheet, onboarding restore button
    ├── PrivacyInfo.xcprivacy    ← Apple privacy manifest (update when adding SDKs / collected data)
    └── Assets/
        └── ExerciseGIFs/       ← Exercise animation files (.gif / .png) — ORIGINAL artwork only, no third-party GIFs
```

**The layout is intentionally flat.** Do not introduce subfolders unless explicitly agreed — the current structure is deliberate and easy to navigate.

---

## ⚡ Build & run

This is a native Xcode project. There are no npm scripts.

| Action | How |
|---|---|
| Build & run | Open `FitApp.xcodeproj` in Xcode → select simulator → ⌘R |
| Run on device | Select physical device in scheme selector → ⌘R |
| Clean build | Product → Clean Build Folder (⇧⌘K) |
| Bundle ID | `com.winter.FitApp` |
| Minimum iOS | iOS 18.0 |

There is no CI/CD config in this repo yet.

---

## 🧰 Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI framework | SwiftUI (+ Swift Charts for weight / measurement trends) |
| State management | `ObservableObject` / `@Published` / `@EnvironmentObject` |
| Persistence | One versioned JSON file via `PersistenceStore`, written only by `AppState` |
| Async | Swift concurrency (`async`/`await`) where needed |
| GIF rendering | `AnimatedExerciseImage` (ImageIO, local bundle assets) |
| Asset loading | `ExerciseAssetLoader` (resolves `.gif` vs `.png` automatically) |
| Testing (UI) | Appium via `AppiumFitApp` repo (see accessibility IDs below) |

---

## 🏗️ Architecture

### State — `AppState`

`AppState` is the single source of truth. It is an `ObservableObject` injected at the root as `@StateObject` and consumed everywhere as `@EnvironmentObject`.

**It owns:**
- All data models (`exercises`, `workoutHistory`, `todayNutrition`, `fitRecipes`, `profile`, `customFoods`, `weightLog`, `bodyMeasurements`)
- All persistence (every `@Published` var schedules a debounced save to the JSON file via `didSet`)
- All business logic methods (`toggleExercise`, `finishWorkout`, `logNutrition`, `saveCustomFood`, `logCustomFood`, `logWeight`, `logMeasurement`, `updateProfile`, `toggleRecipeFavorite`, `resetAllData`)
- Computed properties (`dailyProteinGoalG`, `waterProgress`, `currentWeightKg`, `totalWeightChangeKg`, `colorScheme`, etc.)

**Rules:**
- Never put business logic in a View. All mutations go through `AppState` methods.
- Never access `UserDefaults` directly from a View or child struct. Use `AppState`.
- Never create a second `ObservableObject`. Extend `AppState` instead.

### Views — pure display + user intent

Views observe `AppState` via `@EnvironmentObject var appState: AppState`. They call `appState` methods for any mutation and derive all display values from `appState` computed properties.

```swift
// ✅ Correct
appState.toggleExercise(id: exercise.id)

// ❌ Wrong — logic in a view
exercises[idx].isCompleted.toggle()
UserDefaults.standard.set(...)
```

### Persistence

All app data is saved as ONE versioned JSON file (`Application Support/FitApp/fitapp-data.json`, model: `AppData` in `AppState.swift`) by `PersistenceStore`. Writes are atomic, the last good copy is kept as `fitapp-data.previous.json`, and an unreadable file is moved aside, never overwritten.

- Never store app data in `UserDefaults`. New persisted fields go into `AppData` (optional or with a default + `decodeIfPresent`).
- Layout: `FitApp.xcodeproj` is in the repo root, all sources live in `FitApp/` (flat). This repo root is the single source of truth.
- Google backup: the backup file IS `AppData` encoded by `PersistenceStore.encode`. Cloud state (refresh token, email, last backup) lives in the Keychain, not in `AppData`. Auto backup only runs after this device has backed up or restored once, and never overwrites a newer backup written by another device.
- Recipe content always comes from `FitRecipe.database` — only the `isFavorite` flag is persisted via `RecipeFavoriteFlag`.
- Nutrition is a meal log (`MealEntry`) plus water per day (`waterByDay`). "Today" is derived (`todayMeals`, `todayNutrition`), so nothing needs resetting at midnight and history is kept.
- "My Foods" are `CustomFood` templates (values per ONE serving). Logging one just appends a normal `MealEntry` (source `"custom"`), so history never depends on the food still existing.
- Body tracking: `weightLog` (`WeightEntry`, oldest first, at most one per day) and `bodyMeasurements` (`BodyMeasurement`, one per type per day, cm). The newest weigh-in drives `profile.weightKg` (and therefore the calorie/protein goals); editing the profile weight goes through `AppState.updateProfile`, which records it as today's weigh-in so the two never disagree. `BodyMeasurement.kind` is a plain string holding a `BodyMeasurementType` raw value — never rename those raw values (they are in saved files and backups).
- "My Meals" are `CustomMeal` templates built from `CustomMealItem` ingredients (each item is a COPY of a food's per-serving values plus a `quantity` in servings, so editing/deleting a food never changes a saved meal). Totals are computed, never stored. Logging a meal appends ONE normal `MealEntry` (source `"custom_meal"`) with the summed calories and macros. `customMeals` is an optional-with-default field in `AppData`, so old files and backups still load.
- "Reset All Data" keeps the profile, My Foods, My Meals, weight history and measurements. "Delete All My Data" removes everything.

---

## 📐 Domain models

All models are `Codable` structs defined in `AppState.swift`. Do not move them to separate files — they are intentionally co-located with the state that manages them.

| Model | Key fields | Accessibility ID |
|---|---|---|
| `UserProfile` | name, age, weightKg, heightCm, goal, avatarEmoji | — |
| `WorkoutExercise` | name, sets, reps, isCompleted | `exercise_{snake_name}` |
| `WorkoutSession` | date, exercises | — |
| `NutritionEntry` | waterMl, proteinG, carbsG, fatsG, calories (today's totals, computed — not stored) | — |
| `MealEntry` | name, proteinG, carbsG, fatsG, calories, source (stored meal log) | `meal_row_{index}`, `delete_meal_{index}` |
| `CustomFood` | name, servingLabel, calories, proteinG, carbsG, fatsG (per serving) | `custom_food_row_{index}`, `log_custom_food_{index}` |
| `WeightEntry` | date, kg | `weight_row_{index}` |
| `BodyMeasurement` | date, kind (`BodyMeasurementType` raw value), cm | `measurement_row_{type}`, `measurement_entry_row_{index}` |
| `FitRecipe` | title, category, isFavorite, ... | `recipe_card_{snake_title}` |

`BodyMeasurementType` cases: `neck, shoulders, chest, waist, hips, arm, forearm, wrist, thigh, calf`.

`UserProfile.FitnessGoal` drives the daily protein goal:

| Goal | Protein multiplier |
|---|---|
| `.gainMuscle` | weight × 2.2 g |
| `.loseWeight` | weight × 1.8 g |
| `.performance` | weight × 2.0 g |
| `.maintain` | weight × 1.5 g |

---

## 🔑 Accessibility identifiers

Every interactive element has a stable `accessibilityIdentifier` for Appium automation (the `AppiumFitApp` repo). **Never rename or remove these without also updating the locator files in `AppiumFitApp/mobile-tests/core/locators/`.**

Key identifiers:

| Element | Identifier |
|---|---|
| Main tab bar | `main_tab_bar` |
| Workout tab | `tab_workout` |
| Nutrition tab | `tab_nutrition` |
| Recipes tab | `tab_recipes` |
| Profile tab | `tab_profile` |
| Settings tab | `tab_settings` |
| Finish workout button | `finish_workout_button` |
| Add exercise button | `add_exercise_button` |
| Open library button | `open_library_button` |
| Each exercise row | `exercise_{snake_name}` e.g. `exercise_push_ups` |
| Onboarding next | `onboarding_next_button` |
| Onboarding name field | `name_field` |

My Foods (Nutrition tab):

| Element | Identifier |
|---|---|
| Card / empty hint | `my_foods_card` / `no_custom_foods_label` |
| Add food button | `add_custom_food_button` |
| Food row / log (+) / ⋯ menu | `custom_food_row_{index}` / `log_custom_food_{index}` / `custom_food_menu_{index}` |
| Editor sheet | `custom_food_sheet` |
| Editor fields | `custom_food_name_field`, `custom_food_serving_field`, `custom_food_calories_field`, `custom_food_protein_field`, `custom_food_carbs_field`, `custom_food_fats_field` |
| Editor buttons / messages | `save_custom_food_button`, `cancel_custom_food_button`, `custom_food_validation_label`, `custom_food_save_error` |
| "Save as custom food" toggle (Log Macros sheet) | `save_as_custom_food_toggle` |

Body tracking (Settings → Body Tracking, Profile → Body Progress):

| Element | Identifier |
|---|---|
| Settings links | `weight_tracker_link`, `measurements_link` (values: `settings_current_weight_value`, `settings_measurements_value`) |
| Profile card / links | `body_progress_card`, `profile_weight_tracker_link`, `profile_measurements_link`, `profile_weight_change_label` |
| Weight screen | `weight_tracker_view`, `add_weight_button`, `weight_current_label`, `weight_total_change_label`, `weight_30d_change_label`, `weight_7d_change_label`, `weight_chart`, `weight_chart_hint`, `weight_row_{index}` |
| Log weight sheet | `log_weight_sheet`, `log_weight_field`, `log_weight_date_picker`, `save_weight_button`, `cancel_weight_button`, `log_weight_validation_hint` |
| Measurements list | `measurements_view`, `add_measurement_button`, `measurement_row_{type}` (e.g. `measurement_row_wrist`) |
| Measurement detail | `measurement_detail_{type}`, `add_measurement_entry_button`, `measurement_current_label`, `measurement_change_label`, `measurement_chart`, `measurement_entry_row_{index}` |
| Log measurement sheet | `log_measurement_sheet`, `log_measurement_type_picker`, `log_measurement_field`, `log_measurement_date_picker`, `save_measurement_button`, `cancel_measurement_button`, `log_measurement_validation_hint` |

Accessibility ID format for exercises is computed via `WorkoutExercise.accessibilityID`:
```swift
"exercise_\(name.lowercased().replacingOccurrences(of: " ", with: "_")...)"
```

---

## ✅ Coding conventions

### SwiftUI patterns

- Views are `struct`, not `class`.
- Use `private` for all subview properties and helper computed vars inside a View.
- Break large `body` implementations into `private var` computed properties (e.g. `private var heroContent: some View`).
- `@State` for local ephemeral UI state only. `@EnvironmentObject` for anything that needs to persist or cross views.
- Always use `.accessibilityIdentifier(...)` on any interactive element that could be targeted by Appium.
- Prefer `NavigationStack` over deprecated `NavigationView`.

### Naming

- Views: `PascalCase` ending in `View`, `Sheet`, or `Row` e.g. `WorkoutExerciseRow`, `AddExerciseSheet`.
- `AppState` methods: verb-first camelCase e.g. `toggleExercise`, `finishWorkout`, `logNutrition`.
- Accessibility IDs: `snake_case` with a semantic prefix e.g. `exercise_push_ups`, `tab_workout`, `finish_workout_button`.

### GIFs and exercise assets

Exercise GIFs live in `Assets/ExerciseGIFs/`. Use `ExerciseAssetLoader` to resolve them — it handles both `.gif` and `.png` extensions automatically. Never hardcode the extension in `Exercise.gifFilename`.

```swift
// ✅ Correct — gifFilename is the base name without extension
Exercise(gifFilename: "push_up")

// ❌ Wrong
Exercise(gifFilename: "push_up.gif")
```

Only use exercise animations we own (the current set is original artwork). Do not add GIFs or images copied from other sites or datasets — the App Store release must not contain third-party copyrighted media.

### Adding a new screen

1. Create `NewFeatureView.swift` in `FitApp/` (flat — no subfolder).
2. Add any new model fields to `AppState.swift` as `@Published var`.
3. Add persistence in `AppState.init` (load) and via `didSet` (save).
4. Add business logic methods to `AppState`.
5. Wire into `MainTabView.swift` if it's a top-level tab, or present as a `.sheet` / `NavigationStack` push.
6. Add `accessibilityIdentifier` to every new interactive element.
7. Notify the Appium test repo to update locators.

### Adding a new exercise to the library

Add to `Exercise.all` in `ExerciseDatabase.swift`. Follow the exact same struct initialiser pattern as existing entries. The `gifFilename` must match a file in `Assets/ExerciseGIFs/` (without extension).

---

## 🚫 What NOT to do

| Anti-pattern | Correct approach |
|---|---|
| Business logic in a View body | Move to `AppState` method |
| Direct `UserDefaults` access in a View | Use `AppState` |
| Creating a second `ObservableObject` | Extend `AppState` |
| Removing/renaming an `accessibilityIdentifier` without updating Appium locators | Coordinate with `AppiumFitApp` repo first |
| Adding subfolders to `FitApp/` | Keep the flat layout |
| Hardcoding `.gif` extension in `gifFilename` | Use base filename only |
| Using `@StateObject` anywhere except `FitAppApp.swift` | Use `@EnvironmentObject` in all child views |
| Renaming a `BodyMeasurementType` raw value | Add a new case instead; raw values are stored in user data |
| Setting `appState.profile` directly to change the weight | Use `appState.updateProfile(_:)` so the weight history stays in sync |

---

## 🔗 Relationship to other repos

| Repo | Relationship |
|---|---|
| `FitApp-Android` | Same domain model, same feature set, implemented in Kotlin/Compose |
| `AppiumFitApp` | Automated UI tests; targets this app via `com.winter.FitApp` bundle ID. iOS locators in `core/locators/*/ios.*.ts` |

When you change accessibility identifiers, navigation structure, or add new screens, check whether `AppiumFitApp/mobile-tests/core/locators/` needs updating.

---

## 🍽️ My Meals (Nutrition tab) — accessibility identifiers

| Element | Identifier |
|---|---|
| Card / empty hint | `my_meals_card` / `no_custom_meals_label` |
| Add meal button | `add_custom_meal_button` |
| Meal row / log (+) / ⋯ menu | `custom_meal_row_{index}` / `log_custom_meal_{index}` / `custom_meal_menu_{index}` |
| Editor sheet | `custom_meal_sheet` |
| Editor fields / labels | `custom_meal_name_field`, `custom_meal_no_items_label`, `custom_meal_total_label`, `custom_meal_total_error`, `custom_meal_validation_label`, `custom_meal_save_error` |
| Ingredient row / stepper | `meal_item_row_{index}` / `meal_item_quantity_stepper_{index}` |
| Add ingredient | `add_meal_item_from_foods_menu`, `add_meal_item_quick_menu`, `add_meal_item_manual_button` |
| Editor buttons | `save_custom_meal_button`, `cancel_custom_meal_button` |
| Manual ingredient sheet | `custom_meal_item_sheet`, `meal_item_name_field`, `meal_item_serving_field`, `meal_item_calories_field`, `meal_item_protein_field`, `meal_item_carbs_field`, `meal_item_fats_field`, `save_meal_item_button`, `cancel_meal_item_button` |

## ⏳ Test install expiry (Settings) — accessibility identifiers

Shown ONLY on builds signed with a development profile (free developer account = 7 days). Hidden on App Store / TestFlight builds and in the simulator, so UI tests on the simulator will not see it.

| Element | Identifier |
|---|---|
| Expiry date / time left | `build_expiry_date_value` / `build_expiry_remaining_value` |
| Enable reminder / state labels | `build_expiry_enable_reminder_button` / `build_expiry_reminder_on_label`, `build_expiry_reminder_blocked_label` |
| Footer | `build_expiry_footer` |

`BuildExpiry` holds only device/build info (no user data), so it is deliberately not part of `AppState` or `AppData`. The reminder is re-planned every time the app becomes active, so reinstalling from Xcode moves it forward automatically.
