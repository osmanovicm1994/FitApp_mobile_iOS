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
    ├── ExerciseLibraryView.swift← Filterable exercise library (32 exercises)
    ├── NutritionView.swift      ← Water + macro logging
    ├── RecipesView.swift        ← Recipe browser with favorites
    ├── ProfileView.swift        ← User profile display and edit
    ├── SettingsView.swift       ← Dark mode toggle + data reset
    ├── ExerciseDatabase.swift   ← Static exercise catalogue (Exercise.all)
    ├── ExerciseAssetLoader.swift← Loads GIF/PNG exercise assets from Assets/
    ├── PersistenceStore.swift   ← Versioned JSON file storage (used ONLY by AppState)
    ├── NumberParsing.swift      ← Locale-safe number parsing + ProfileLimits
    └── Assets/
        └── ExerciseGIFs/       ← Exercise animation files (.gif / .png)
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
| UI framework | SwiftUI |
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
- All data models (`exercises`, `workoutHistory`, `todayNutrition`, `fitRecipes`, `profile`)
- All persistence (every `@Published` var schedules a debounced save to the JSON file via `didSet`)
- All business logic methods (`toggleExercise`, `finishWorkout`, `logNutrition`, `toggleRecipeFavorite`, `resetAllData`)
- Computed properties (`dailyProteinGoalG`, `waterProgress`, `colorScheme`, etc.)

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
- Layout: the Xcode project is `FitApp/FitApp.xcodeproj`; all sources live in `FitApp/FitApp/` (this repo is the single source of truth).
- Recipe content always comes from `FitRecipe.database` — only the `isFavorite` flag is persisted via `RecipeFavoriteFlag`.
- Nutrition is a meal log (`MealEntry`) plus water per day (`waterByDay`). "Today" is derived (`todayMeals`, `todayNutrition`), so nothing needs resetting at midnight and history is kept.

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
| `FitRecipe` | title, category, isFavorite, ... | `recipe_card_{snake_title}` |

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

---

## 🔗 Relationship to other repos

| Repo | Relationship |
|---|---|
| `FitApp-Android` | Same domain model, same feature set, implemented in Kotlin/Compose |
| `AppiumFitApp` | Automated UI tests; targets this app via `com.winter.FitApp` bundle ID. iOS locators in `core/locators/*/ios.*.ts` |

When you change accessibility identifiers, navigation structure, or add new screens, check whether `AppiumFitApp/mobile-tests/core/locators/` needs updating.
