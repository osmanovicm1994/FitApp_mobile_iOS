// ExerciseLibraryView.swift
// Exercise browser — grid/list toggle, muscle filter, detail sheet with local GIF hero.
// Uses Exercise.gifFilename directly — no image-source indirection layer.

import SwiftUI
import Combine  // explicit import

// MARK: - Exercise Library Root

struct ExerciseLibraryView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText              = ""
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var viewMode: ViewMode      = .grid
    @State private var selectedExercise: Exercise? = nil

    enum ViewMode { case grid, list }

    private var displayed: [Exercise] {
        Exercise.all.filter { ex in
            (selectedGroup == nil || ex.muscleGroup == selectedGroup) &&
            (searchText.isEmpty ||
             ex.name.localizedCaseInsensitiveContains(searchText) ||
             ex.muscleGroup.rawValue.localizedCaseInsensitiveContains(searchText) ||
             ex.shortDescription.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                muscleFilterBar
                Divider().opacity(0.25)
                if displayed.isEmpty { emptyState } else { content }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewMode = viewMode == .grid ? .list : .grid
                        }
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .fontWeight(.medium)
                    }
                    .accessibilityIdentifier("toggle_view_mode")
                }
            }
            .sheet(item: $selectedExercise) { ex in
                ExerciseDetailSheet(exercise: ex)
                    .environmentObject(appState)
            }
        }
        .accessibilityIdentifier("exercise_library_view")
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search exercises or muscles…", text: $searchText)
                .accessibilityIdentifier("exercise_search_field")
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: Filter chips

    private var muscleFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", icon: "square.grid.2x2", color: .blue,
                           isOn: selectedGroup == nil) {
                    withAnimation(.spring(response: 0.3)) { selectedGroup = nil }
                }
                ForEach(Exercise.allGroups, id: \.self) { group in
                    filterChip(group.rawValue, icon: group.icon,
                               color: group.color, isOn: selectedGroup == group) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedGroup = selectedGroup == group ? nil : group
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .accessibilityIdentifier("muscle_filter_bar")
    }

    @ViewBuilder
    private func filterChip(_ label: String, icon: String, color: Color,
                             isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2.bold())
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isOn ? color : Color.secondary.opacity(0.1))
            .foregroundStyle(isOn ? .white : Color.primary)
            .clipShape(Capsule())
            .shadow(color: isOn ? color.opacity(0.35) : .clear, radius: 5, y: 2)
        }
        .accessibilityIdentifier("filter_\(label.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        switch viewMode {
        case .grid:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14),
                               GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(displayed) { ex in
                        ExerciseGridCard(exercise: ex)
                            .onTapGesture { selectedExercise = ex }
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("exercise_grid")

        case .list:
            List(displayed) { ex in
                ExerciseListRow(exercise: ex)
                    .onTapGesture { selectedExercise = ex }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
            .accessibilityIdentifier("exercise_library_list")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No exercises found")
                .font(.title2.bold())
            Text("Try a different search or filter")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityIdentifier("no_exercises_label")
    }
}

// MARK: - Grid Card

struct ExerciseGridCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(spacing: 0) {
            // Local GIF — the centrepiece of every card
            AnimatedExerciseImage(
                filename: exercise.gifFilename,
                height: 160,
                cornerRadius: 0
            )
            .overlay(alignment: .topTrailing) {
                diffBadge(exercise.difficulty)
                    .padding(8)
            }

            // Text area
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: exercise.muscleGroup.icon)
                        .font(.caption2.bold())
                        .foregroundStyle(exercise.muscleGroup.color)
                    Text(exercise.muscleGroup.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(exercise.muscleGroup.color)
                }
                Text(exercise.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(exercise.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(exercise.setsReps)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.05))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12))
        )
        .accessibilityIdentifier(exercise.accessibilityID)
    }

    private func diffBadge(_ d: ExerciseDifficulty) -> some View {
        Text(d.rawValue)
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(d.color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

// MARK: - List Row

struct ExerciseListRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AnimatedExerciseImage(
                filename: exercise.gifFilename,
                height: 80,
                cornerRadius: 12
            )
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name).font(.headline)
                    Spacer()
                    Text(exercise.difficulty.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(exercise.difficulty.color.opacity(0.12))
                        .foregroundStyle(exercise.difficulty.color)
                        .clipShape(Capsule())
                }
                HStack(spacing: 4) {
                    Image(systemName: exercise.muscleGroup.icon)
                        .font(.caption)
                        .foregroundStyle(exercise.muscleGroup.color)
                    Text(exercise.muscleGroup.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(exercise.muscleGroup.color)
                }
                Text(exercise.shortDescription)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 10) {
                    Label(exercise.setsReps,   systemImage: "repeat")
                    Label(exercise.equipment,  systemImage: "dumbbell")
                }
                .font(.caption2).foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier(exercise.accessibilityID)
    }
}

// MARK: - Detail Sheet

struct ExerciseDetailSheet: View {
    let exercise: Exercise
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showAddedToast = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Full-width GIF hero
                    AnimatedExerciseImage(
                        filename: exercise.gifFilename,
                        height: 300,
                        cornerRadius: 0
                    )
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 8) {
                            Label(exercise.muscleGroup.rawValue,
                                  systemImage: exercise.muscleGroup.icon)
                                .font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(exercise.muscleGroup.color)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())

                            Text(exercise.difficulty.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .foregroundStyle(exercise.difficulty.color)
                                .clipShape(Capsule())
                        }
                        .padding(16)
                    }
                    .accessibilityIdentifier("exercise_image_hero")

                    // Details
                    VStack(alignment: .leading, spacing: 20) {
                        statsRow
                        descriptionCard
                        tipsCard
                    }
                    .padding()
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("close_exercise_detail")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addToWorkout) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                    }
                    .tint(exercise.muscleGroup.color)
                    .accessibilityIdentifier("add_to_workout_button")
                }
            }
            .overlay(alignment: .bottom) { toastView }
        }
        .accessibilityIdentifier("exercise_detail_view")
    }

    // MARK: Sub-views

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell("repeat",         "Sets × Reps", exercise.setsReps,         exercise.muscleGroup.color)
            Divider().frame(height: 44)
            statCell("dumbbell",       "Equipment",   exercise.equipment,         exercise.muscleGroup.color)
            Divider().frame(height: 44)
            statCell(exercise.difficulty == .beginner ? "1.circle.fill"
                     : exercise.difficulty == .intermediate ? "2.circle.fill"
                     : "3.circle.fill",
                     "Level", exercise.difficulty.rawValue, exercise.difficulty.color)
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("exercise_stats_row")
    }

    private func statCell(_ icon: String, _ label: String,
                           _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            Text(value).font(.system(size: 12, weight: .bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("About This Exercise", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(exercise.muscleGroup.color)
            Text(exercise.fullDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .accessibilityIdentifier("exercise_description")
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Form Tips", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(exercise.muscleGroup.color)
            ForEach(Array(exercise.formTips.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .frame(width: 26, height: 26)
                        .background(exercise.muscleGroup.color.opacity(0.15))
                        .foregroundStyle(exercise.muscleGroup.color)
                        .clipShape(Circle())
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("form_tip_\(i + 1)")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var toastView: some View {
        Group {
            if showAddedToast {
                Label("Added to today's workout!", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(exercise.muscleGroup.color)
                    .clipShape(Capsule())
                    .shadow(color: exercise.muscleGroup.color.opacity(0.4), radius: 10, y: 4)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: showAddedToast)
    }

    private func addToWorkout() {
        appState.addExercise(name: exercise.name, sets: 3, reps: 12)
        withAnimation { showAddedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showAddedToast = false }
        }
    }
}
