// WorkoutView.swift  — REDESIGNED
// "Today's Workout" with a stunning animated mesh gradient hero,
// circular progress ring, and spring-animated exercise rows.
// import Combine explicit to prevent ObservableObject conformance errors.

import SwiftUI
import Combine  // explicit import

// MARK: - Main Workout View

struct WorkoutView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddExercise = false
    @State private var showLibrary     = false
    @State private var pulsePhase      = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Status bar colour fill
                LinearGradient(
                    colors: [Color(red:0.04,green:0.10,blue:0.42), Color(red:0.18,green:0.04,blue:0.48)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 340)
                .ignoresSafeArea(edges: .top)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        workoutHero
                        exerciseListSection
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddExercise) {
                AddExerciseSheet().environmentObject(appState)
            }
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView().environmentObject(appState)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            }
        }
        .accessibilityIdentifier("workout_view")
    }

    // MARK: - Workout Hero

    private var workoutHero: some View {
        ZStack {
            meshGradient
            floatingShapes
            heroContent
        }
        .frame(height: 300)
        .clipped()
    }

    private var meshGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red:0.04,green:0.10,blue:0.42),
                    Color(red:0.18,green:0.04,blue:0.48),
                    Color(red:0.04,green:0.22,blue:0.52),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.blue.opacity(0.35), .clear],
                center: UnitPoint(x: 0.2, y: 0.25),
                startRadius: 10, endRadius: 180
            )
            .blur(radius: 20)
            .offset(y: pulsePhase ? -8 : 8)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulsePhase)

            RadialGradient(
                colors: [Color.purple.opacity(0.25), .clear],
                center: UnitPoint(x: 0.8, y: 0.65),
                startRadius: 10, endRadius: 150
            )
            .blur(radius: 16)
            .offset(y: pulsePhase ? 8 : -8)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: pulsePhase)
        }
    }

    private var floatingShapes: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: 220, height: 220).offset(x: -90, y: -30)
            Circle().stroke(Color.white.opacity(0.04), lineWidth: 1)
                .frame(width: 300, height: 300).offset(x: 100, y: 40)
        }
    }

    private var heroContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S WORKOUT")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(2)
                        .accessibilityIdentifier("workout_title")
                    Text(splitName)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer()
                progressRing
            }
            .padding(.horizontal, 24)

            HStack(spacing: 8) {
                Text("🔥")
                    .scaleEffect(pulsePhase ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsePhase)
                Text(motivationalQuote)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                    .accessibilityIdentifier("motivational_text")
                Spacer()
                Button { showLibrary = true } label: {
                    Label("Library", systemImage: "books.vertical.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("library_hero_button")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
    }

    private var progressRing: some View {
        let total    = max(appState.exercises.count, 1)
        let done     = appState.completedExercisesCount
        let progress = Double(done) / Double(total)

        return ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color.green, Color.cyan, Color.green],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
            VStack(spacing: 0) {
                Text("\(done)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(total)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 70, height: 70)
        .accessibilityIdentifier("workout_progress_ring")
    }

    // MARK: - Exercise List Section

    private var exerciseListSection: some View {
        VStack(spacing: 16) {
            ForEach(appState.exercises) { exercise in
                WorkoutExerciseRow(exercise: exercise) {
                    appState.toggleExercise(id: exercise.id)
                }
            }
            .padding(.top, 8)
            actionButtons
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.top, -28)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: { appState.finishWorkout() }) {
                Label("Finish Workout", systemImage: "checkmark.circle.fill")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(
                        colors: [Color(red:0.1,green:0.78,blue:0.42), Color(red:0.08,green:0.62,blue:0.32)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            }
            .accessibilityIdentifier("finish_workout_button")

            HStack(spacing: 10) {
                Button { showAddExercise = true } label: {
                    Label("Add Exercise", systemImage: "plus")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.blue.opacity(0.08))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityIdentifier("add_exercise_button")

                Button { showLibrary = true } label: {
                    Label("Browse Library", systemImage: "books.vertical")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.purple.opacity(0.08))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityIdentifier("open_library_button")
            }
        }
    }

    // MARK: - Helpers

    private var splitName: String {
        let day = Calendar.current.component(.weekday, from: Date())
        switch day {
        case 2: return "Monday — Push"
        case 3: return "Tuesday — Pull"
        case 4: return "Wednesday — Legs"
        case 5: return "Thursday — Push"
        case 6: return "Friday — Pull"
        case 7: return "Saturday — Cardio"
        default: return "Sunday — Rest"
        }
    }

    private var motivationalQuote: String {
        let q = ["Every rep counts.", "Progress, not perfection.",
                 "Strong today. Stronger tomorrow.", "You showed up — that's the hard part.",
                 "Don't count reps. Make reps count."]
        return q[Calendar.current.component(.day, from: Date()) % q.count]
    }
}

// MARK: - Workout Exercise Row

struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.18)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.18)) { pressed = false }
            }
            onTap()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(exercise.isCompleted ? Color.green : Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .animation(.spring(response: 0.3), value: exercise.isCompleted)
                    if exercise.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.headline)
                        .strikethrough(exercise.isCompleted, color: .secondary)
                        .foregroundStyle(exercise.isCompleted ? .secondary : .primary)
                    Text("\(exercise.sets) sets · \(exercise.reps) reps")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if exercise.isCompleted {
                    Text("Done ✓").font(.caption.bold()).foregroundStyle(.green)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(exercise.isCompleted ? Color.green.opacity(0.07) : Color.secondary.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(exercise.isCompleted ? Color.green.opacity(0.2) : .clear))
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(exercise.accessibilityID)
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var sets = "3"
    @State private var reps = "10"

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Name (e.g. Deadlift)", text: $name)
                        .accessibilityIdentifier("exercise_name_field")
                    TextField("Sets", text: $sets).keyboardType(.numberPad)
                        .accessibilityIdentifier("sets_field")
                    TextField("Reps", text: $reps).keyboardType(.numberPad)
                        .accessibilityIdentifier("reps_field")
                }
                if !name.isEmpty {
                    Section("Preview") {
                        Text("\(name) — \(sets) × \(reps)").foregroundStyle(.secondary)
                            .accessibilityIdentifier("exercise_preview_label")
                    }
                }
            }
            .navigationTitle("New Exercise").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.addExercise(name: name, sets: Int(sets) ?? 3, reps: Int(reps) ?? 10)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("save_exercise_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_button")
                }
            }
        }
        .accessibilityIdentifier("add_exercise_sheet")
    }
}
