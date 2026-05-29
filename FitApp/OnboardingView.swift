// OnboardingView.swift
// First-launch profile creation wizard — multi-step.

import SwiftUI
import Combine  // explicit import

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var age: String = "25"
    @State private var weightKg: String = "70"
    @State private var heightCm: String = "170"
    @State private var selectedGoal: UserProfile.FitnessGoal = .loseWeight
    @State private var selectedAvatar: String = "🧑"

    private let avatars = ["🧑", "👨", "👩", "🧔", "👱", "🏋️", "🤸", "🧘"]

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(i <= step ? .blue : Color.gray.opacity(0.3))
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.top, 60)
            .accessibilityIdentifier("onboarding_progress")

            Spacer()

            // Step content
            Group {
                if step == 0 { stepOne }
                else if step == 1 { stepTwo }
                else { stepThree }
            }
            .padding(.horizontal, 32)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))

            Spacer()

            // Navigation buttons
            VStack(spacing: 12) {
                Button(action: nextStep) {
                    Text(step < 2 ? "Continue" : "Let's Go! 🚀")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(!canProceed)
                .accessibilityIdentifier("onboarding_next_button")

                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("onboarding_back_button")
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .accessibilityIdentifier("onboarding_view")
    }

    // MARK: - Step Views

    private var stepOne: some View {
        VStack(spacing: 28) {
            Text("👋 Welcome!")
                .font(.system(size: 48))
            Text("Create Your Profile")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboarding_title")
            Text("Let's personalise your FitApp experience.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Avatar picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(avatars, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 40))
                            .padding(8)
                            .background(
                                selectedAvatar == emoji
                                ? Color.blue.opacity(0.2)
                                : Color.clear
                            )
                            .cornerRadius(12)
                            .onTapGesture { selectedAvatar = emoji }
                    }
                }
            }
            .accessibilityIdentifier("avatar_picker")

            TextField("Your name", text: $name)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .accessibilityIdentifier("name_field")
        }
    }

    private var stepTwo: some View {
        VStack(spacing: 20) {
            Text("📊 Body Stats")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("stats_title")

            VStack(spacing: 14) {
                statField(label: "Age", value: $age, unit: "years", id: "age_field")
                statField(label: "Weight", value: $weightKg, unit: "kg", id: "weight_field")
                statField(label: "Height", value: $heightCm, unit: "cm", id: "height_field")
            }
        }
    }

    private var stepThree: some View {
        VStack(spacing: 24) {
            Text("🎯 Your Goal")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("goal_title")
            Text("What do you want to achieve?")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(UserProfile.FitnessGoal.allCases, id: \.self) { goal in
                    Button(action: { selectedGoal = goal }) {
                        HStack {
                            Image(systemName: goal.icon)
                                .frame(width: 32)
                            Text(goal.rawValue)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(
                            selectedGoal == goal
                            ? Color.blue.opacity(0.12)
                            : Color.secondary.opacity(0.08)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGoal == goal ? Color.blue : Color.clear)
                        )
                    }
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("goal_\(goal.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
                }
            }
        }
    }

    // MARK: - Helpers

    private func statField(label: String, value: Binding<String>, unit: String, id: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
            Text(unit)
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var canProceed: Bool {
        switch step {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func nextStep() {
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            saveProfile()
        }
    }

    private func saveProfile() {
        appState.profile = UserProfile(
            name: name,
            age: Int(age) ?? 25,
            weightKg: Double(weightKg) ?? 70,
            heightCm: Double(heightCm) ?? 170,
            goal: selectedGoal,
            avatarEmoji: selectedAvatar
        )
        appState.hasCompletedOnboarding = true
    }
}
