// CustomWorkouts.swift
// Custom, reusable workouts ("Upper Body", "Leg Day", ...).
//
//   • SavedWorkout / SavedWorkoutExercise  – persisted templates (stored in AppData.savedWorkouts)
//   • MyWorkoutsView                       – list: tap to load on the main page, star = default, edit, delete
//   • WorkoutEditorView                    – create / edit a workout (name + exercises, sets, reps)
//   • ExercisePickerSheet                  – add exercises from the built-in library
//
// A saved workout is only a template. Loading one copies its exercises into
// AppState.exercises (the list shown on the Workout tab), so ticking exercises off or
// finishing a session never changes the template.

import SwiftUI
import Combine  // explicit import

// MARK: - Models

struct SavedWorkoutExercise: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var repRange: String? = nil
}

struct SavedWorkout: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var exercises: [SavedWorkoutExercise]
    var createdAt: Date = Date()

    static let builtInDefaults: [SavedWorkout] = [
        SavedWorkout(id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!, name: "Upper A", exercises: [
            .init(name: "Bench press / chest press", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Lat pulldown", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Seated cable row", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Incline dumbbell press", sets: 2, reps: 12, repRange: "10–12 reps"),
            .init(name: "Lateral raises", sets: 2, reps: 15, repRange: "12–15 reps"),
            .init(name: "Biceps curl", sets: 2, reps: 15, repRange: "10–15 reps"),
            .init(name: "Triceps pushdown", sets: 2, reps: 15, repRange: "10–15 reps")
        ]),
        SavedWorkout(id: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!, name: "Lower A", exercises: [
            .init(name: "Squat ili leg press", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Romanian deadlift", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Leg curl", sets: 2, reps: 15, repRange: "10–15 reps"),
            .init(name: "Leg extension", sets: 2, reps: 15, repRange: "10–15 reps"),
            .init(name: "Calf raises", sets: 3, reps: 15, repRange: "12–15 reps"),
            .init(name: "Plank", sets: 3, reps: 60, repRange: "30–60 sec")
        ]),
        SavedWorkout(id: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!, name: "Upper B", exercises: [
            .init(name: "Overhead press", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Pull-ups / lat pulldown", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Dumbbell bench press", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Chest-supported row", sets: 2, reps: 12, repRange: "8–12 reps"),
            .init(name: "Face pulls / rear-delt fly", sets: 2, reps: 15, repRange: "12–15 reps"),
            .init(name: "Hammer curls", sets: 2, reps: 15, repRange: "10–15 reps"),
            .init(name: "Overhead triceps extension", sets: 2, reps: 15, repRange: "10–15 reps")
        ]),
        SavedWorkout(id: UUID(uuidString: "00000000-0000-4000-8000-000000000104")!, name: "Lower B", exercises: [
            .init(name: "Leg press / squat", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Hip thrust", sets: 3, reps: 12, repRange: "8–12 reps"),
            .init(name: "Bulgarian split squat", sets: 2, reps: 12, repRange: "8–12 per leg"),
            .init(name: "Leg curl", sets: 2, reps: 15, repRange: "10–15 reps"),
            .init(name: "Calf raises", sets: 3, reps: 15, repRange: "12–15 reps"),
            .init(name: "Dead bug", sets: 3, reps: 12, repRange: "8–12 per side")
        ])
    ]

    /// Fresh (not completed) exercises for the Workout tab.
    var asWorkoutExercises: [WorkoutExercise] {
        exercises.map { WorkoutExercise(name: $0.name, sets: $0.sets, reps: $0.reps, repRange: $0.repRange) }
    }

    var summary: String {
        let count = exercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }

    /// Accessibility ID used by Appium tests, e.g. "saved_workout_upper_body".
    var accessibilityID: String {
        "saved_workout_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
}

// MARK: - My Workouts (list)

struct MyWorkoutsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private struct EditorTarget: Identifiable {
        let id = UUID()
        let workout: SavedWorkout
        let isNew: Bool
    }

    private enum PendingSwitch {
        case workout(SavedWorkout)
        case free
    }

    @State private var editor: EditorTarget? = nil
    @State private var pendingSwitch: PendingSwitch? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    freeWorkoutRow
                } footer: {
                    Text("The starred workout is loaded on the main page when the app starts. You can change it any time.")
                }

                Section("Saved workouts") {
                    if appState.savedWorkouts.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.savedWorkouts) { workout in
                            workoutRow(workout)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { appState.savedWorkouts[$0].id }
                            ids.forEach { appState.deleteWorkout(id: $0) }
                        }
                    }
                }
            }
            .navigationTitle("My Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("close_my_workouts_button")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editor = EditorTarget(workout: SavedWorkout(name: "", exercises: []), isNew: true)
                    } label: {
                        Label("New Workout", systemImage: "plus")
                    }
                    .accessibilityIdentifier("new_workout_button")
                }
            }
            .sheet(item: $editor) { target in
                WorkoutEditorView(workout: target.workout, isNew: target.isNew)
                    .environmentObject(appState)
            }
            .confirmationDialog("Switch workout?",
                                isPresented: pendingBinding,
                                titleVisibility: .visible) {
                Button("Switch and discard today's progress", role: .destructive) {
                    if let pending = pendingSwitch { perform(pending) }
                    pendingSwitch = nil
                }
                Button("Cancel", role: .cancel) { pendingSwitch = nil }
            } message: {
                Text("You already ticked off exercises today. Switching removes those ticks.")
            }
        }
        .accessibilityIdentifier("my_workouts_view")
    }

    // MARK: Rows

    private var freeWorkoutRow: some View {
        Button { request(.free) } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick workout").font(.headline).foregroundStyle(.primary)
                    Text("Starter list, no saved workout").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if appState.activeWorkoutID == nil {
                    activeBadge
                }
            }
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("free_workout_row")
    }

    private func workoutRow(_ workout: SavedWorkout) -> some View {
        let isActive  = appState.activeWorkoutID == workout.id
        let isDefault = appState.defaultWorkoutID == workout.id

        return HStack(spacing: 12) {
            Button { request(.workout(workout)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name).font(.headline).foregroundStyle(.primary)
                        Text(workout.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isActive { activeBadge }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(workout.accessibilityID)

            Button {
                appState.setDefaultWorkout(id: isDefault ? nil : workout.id)
            } label: {
                Image(systemName: isDefault ? "star.fill" : "star")
                    .foregroundStyle(isDefault ? Color.yellow : Color.secondary)
                    .padding(6)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isDefault ? "Remove as default workout" : "Set as default workout")
            .accessibilityIdentifier("default_star_\(workout.accessibilityID)")
        }
        .swipeActions(edge: .leading) {
            Button {
                editor = EditorTarget(workout: workout, isNew: false)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button { request(.workout(workout)) } label: {
                Label("Use today", systemImage: "play.fill")
            }
            Button { editor = EditorTarget(workout: workout, isNew: false) } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                appState.setDefaultWorkout(id: isDefault ? nil : workout.id)
            } label: {
                Label(isDefault ? "Remove as default" : "Set as default",
                      systemImage: isDefault ? "star.slash" : "star")
            }
            Button(role: .destructive) { appState.deleteWorkout(id: workout.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var activeBadge: some View {
        Text("ACTIVE")
            .font(.system(size: 10, weight: .black))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No saved workouts yet")
                .font(.headline)
            Text("Tap + to build one, for example an upper body day with 5–6 exercises.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityIdentifier("no_saved_workouts_label")
    }

    // MARK: Switching

    private var pendingBinding: Binding<Bool> {
        Binding(
            get: { pendingSwitch != nil },
            set: { isShown in if !isShown { pendingSwitch = nil } }
        )
    }

    /// Switches right away, or asks first when today's progress would be lost.
    private func request(_ target: PendingSwitch) {
        if appState.completedExercisesCount > 0 {
            pendingSwitch = target
        } else {
            perform(target)
        }
    }

    private func perform(_ target: PendingSwitch) {
        switch target {
        case .workout(let workout):
            if appState.startWorkout(id: workout.id) { dismiss() }
        case .free:
            appState.useFreeWorkout()
            dismiss()
        }
    }
}

// MARK: - Editor

struct WorkoutEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var draft: SavedWorkout
    @State private var showPicker = false
    private let isNew: Bool

    init(workout: SavedWorkout, isNew: Bool) {
        _draft = State(initialValue: workout)
        self.isNew = isNew
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.exercises.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout name") {
                    TextField("e.g. Upper Body", text: $draft.name)
                        .accessibilityIdentifier("workout_name_field")
                }

                Section {
                    if draft.exercises.isEmpty {
                        Text("No exercises yet. Add some below.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("no_workout_exercises_label")
                    }
                    ForEach($draft.exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Exercise name", text: $exercise.name)
                                .font(.headline)
                            HStack {
                                Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...99)
                                    .font(.subheadline)
                            }
                            HStack {
                                Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...999)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { draft.exercises.remove(atOffsets: $0) }
                    .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Exercises (\(draft.exercises.count))")
                } footer: {
                    Text("Swipe left to delete. Tap Edit at the bottom to reorder.")
                }

                Section {
                    Button { showPicker = true } label: {
                        Label("Add from library", systemImage: "books.vertical")
                    }
                    .accessibilityIdentifier("add_from_library_button")

                    Button {
                        draft.exercises.append(SavedWorkoutExercise(name: "", sets: 3, reps: 10))
                    } label: {
                        Label("Add custom exercise", systemImage: "plus")
                    }
                    .accessibilityIdentifier("add_custom_exercise_button")
                }
            }
            .navigationTitle(isNew ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_workout_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if appState.saveWorkout(draft) { dismiss() }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("save_workout_button")
                }
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet { exercise in
                    draft.exercises.append(SavedWorkoutExercise(name: exercise.name, sets: 3, reps: 12))
                }
            }
        }
        .accessibilityIdentifier("workout_editor_view")
    }
}

// MARK: - Exercise picker (built-in library)

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let onPick: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var added: Set<UUID> = []

    private var displayed: [Exercise] {
        Exercise.all.filter { ex in
            (selectedGroup == nil || ex.muscleGroup == selectedGroup) &&
            (searchText.isEmpty ||
             ex.name.localizedCaseInsensitiveContains(searchText) ||
             ex.muscleGroup.rawValue.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                groupBar
                List(displayed) { ex in
                    Button {
                        onPick(ex)
                        added.insert(ex.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: ex.muscleGroup.icon)
                                .foregroundStyle(ex.muscleGroup.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(.headline).foregroundStyle(.primary)
                                Text(ex.muscleGroup.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: added.contains(ex.id) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(added.contains(ex.id) ? Color.green : Color.blue)
                        }
                    }
                    .accessibilityIdentifier("pick_\(ex.accessibilityID)")
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("picker_done_button")
                }
            }
        }
        .accessibilityIdentifier("exercise_picker_sheet")
    }

    private var groupBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", color: .blue, isOn: selectedGroup == nil) { selectedGroup = nil }
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    chip(group.rawValue, color: group.color, isOn: selectedGroup == group) {
                        selectedGroup = selectedGroup == group ? nil : group
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ label: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isOn ? color : Color.secondary.opacity(0.1))
                .foregroundStyle(isOn ? .white : Color.primary)
                .clipShape(Capsule())
        }
        .accessibilityIdentifier("picker_filter_\(label.lowercased())")
    }
}
