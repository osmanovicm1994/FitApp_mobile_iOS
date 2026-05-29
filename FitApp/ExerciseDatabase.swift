// ExerciseDatabase.swift
// Exercise database — 32 exercises mapped to their exact downloaded GIF/PNG filenames.
// Filenames match what was downloaded into Assets/ExerciseGIFs/:
//   • Most are .gif  (e.g. push_up.gif)
//   • russian_twist  is .png
// The loader resolves the extension automatically, so we only store the base name.

import SwiftUI
import Combine  // explicit import

// MARK: - Muscle Group

enum MuscleGroup: String, CaseIterable, Hashable {
    case chest      = "Chest"
    case back       = "Back"
    case legs       = "Legs"
    case shoulders  = "Shoulders"
    case arms       = "Arms"
    case core       = "Core"
    case cardio     = "Cardio"

    var color: Color {
        switch self {
        case .chest:     return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .back:      return Color(red: 0.30, green: 0.60, blue: 1.00)
        case .legs:      return Color(red: 0.20, green: 0.85, blue: 0.50)
        case .shoulders: return Color(red: 0.75, green: 0.35, blue: 1.00)
        case .arms:      return Color(red: 1.00, green: 0.60, blue: 0.20)
        case .core:      return Color(red: 1.00, green: 0.85, blue: 0.20)
        case .cardio:    return Color(red: 0.20, green: 0.88, blue: 0.95)
        }
    }

    var icon: String {
        switch self {
        case .chest:     return "figure.arms.open"
        case .back:      return "figure.gymnastics"
        case .legs:      return "figure.walk"
        case .shoulders: return "figure.basketball"
        case .arms:      return "dumbbell.fill"
        case .core:      return "flame.fill"
        case .cardio:    return "heart.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .chest:     return [Color(red:0.45,green:0.05,blue:0.05), Color(red:0.65,green:0.10,blue:0.10)]
        case .back:      return [Color(red:0.04,green:0.10,blue:0.45), Color(red:0.06,green:0.20,blue:0.60)]
        case .legs:      return [Color(red:0.04,green:0.26,blue:0.14), Color(red:0.06,green:0.40,blue:0.20)]
        case .shoulders: return [Color(red:0.24,green:0.06,blue:0.44), Color(red:0.36,green:0.10,blue:0.60)]
        case .arms:      return [Color(red:0.42,green:0.18,blue:0.02), Color(red:0.58,green:0.25,blue:0.04)]
        case .core:      return [Color(red:0.34,green:0.26,blue:0.02), Color(red:0.48,green:0.38,blue:0.04)]
        case .cardio:    return [Color(red:0.02,green:0.26,blue:0.34), Color(red:0.04,green:0.38,blue:0.48)]
        }
    }
}

// MARK: - Difficulty

enum ExerciseDifficulty: String, CaseIterable {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"

    var color: Color {
        switch self {
        case .beginner:     return Color(red: 0.20, green: 0.85, blue: 0.50)
        case .intermediate: return Color(red: 1.00, green: 0.70, blue: 0.20)
        case .advanced:     return Color(red: 0.95, green: 0.30, blue: 0.30)
        }
    }
}

// MARK: - Exercise Model

struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    /// One-liner shown on card and list row
    let shortDescription: String
    /// Full paragraph shown in detail sheet
    let fullDescription: String
    let muscleGroup: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let difficulty: ExerciseDifficulty
    let equipment: String
    let setsReps: String
    let formTips: [String]
    /// Exact filename WITHOUT extension inside Assets/ExerciseGIFs/
    let gifFilename: String

    var accessibilityID: String {
        "exercise_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
}

// MARK: - Database  (32 exercises, exact filenames as downloaded)

extension Exercise {
    static let all: [Exercise] = [

        // ── CHEST ──────────────────────────────────────────────────────────
        Exercise(
            name: "Push-Up",
            shortDescription: "Classic bodyweight chest builder",
            fullDescription: "From a high plank, lower your chest to the floor then press back up. Engages chest, anterior delts, and triceps simultaneously. The most accessible pushing movement — do it anywhere.",
            muscleGroup: .chest, secondaryMuscles: [.shoulders, .arms, .core],
            difficulty: .beginner, equipment: "None", setsReps: "3 × 12–20",
            formTips: [
                "Body in a rigid straight line — no sagging hips",
                "Elbows at 45°, not flared wide",
                "Lower until chest nearly grazes the floor",
                "Exhale powerfully on the push up"
            ],
            gifFilename: "push_up"
        ),
        Exercise(
            name: "Barbell Bench Press",
            shortDescription: "King of chest mass exercises",
            fullDescription: "Lying on a bench, lower a barbell to mid-chest and press to full lockout. The single best horizontal push for building maximum pectoral size and raw pressing strength.",
            muscleGroup: .chest, secondaryMuscles: [.shoulders, .arms],
            difficulty: .intermediate, equipment: "Barbell + Bench", setsReps: "4 × 6–10",
            formTips: [
                "Retract shoulder blades and keep them pinched throughout",
                "Bar travels diagonally — touches low chest, not the neck",
                "Plant feet flat on the floor",
                "Use a spotter for all heavy sets"
            ],
            gifFilename: "barbell_bench_press"
        ),
        Exercise(
            name: "Dumbbell Fly",
            shortDescription: "Deep chest stretch and isolation",
            fullDescription: "Arc dumbbells outward from above the chest and back in a wide hugging motion. Produces a unique deep stretch at the bottom that pressing movements can't replicate — essential for complete chest development.",
            muscleGroup: .chest, secondaryMuscles: [.shoulders],
            difficulty: .intermediate, equipment: "Dumbbells + Bench", setsReps: "3 × 12",
            formTips: [
                "Maintain a soft bend in elbows throughout",
                "Feel the stretch before squeezing back",
                "Use lighter weight than you think you need",
                "Don't let elbows drop below shoulder level"
            ],
            gifFilename: "dumbbell_fly"
        ),

        // ── BACK ───────────────────────────────────────────────────────────
        Exercise(
            name: "Pull-Up",
            shortDescription: "Gold standard for wide back development",
            fullDescription: "Dead hang from a bar, pull until chin clears the bar, lower fully. Builds wide lats, strong biceps, and serious grip strength. If you can do 10 clean pull-ups you have genuinely impressive upper-body strength.",
            muscleGroup: .back, secondaryMuscles: [.arms, .core],
            difficulty: .intermediate, equipment: "Pull-up Bar", setsReps: "3 × 6–10",
            formTips: [
                "Full dead hang at the bottom every single rep",
                "Drive elbows down and back — not just arms up",
                "Squeeze shoulder blades together at the top",
                "Use a resistance band to scale if needed"
            ],
            gifFilename: "pull_up"
        ),
        Exercise(
            name: "Incline Barbell Row",
            shortDescription: "Chest-supported row for thick back",
            fullDescription: "Lying face-down on an incline bench, row a barbell to your lower chest. The chest support eliminates lower-back fatigue so you can focus entirely on upper-back and lat contraction.",
            muscleGroup: .back, secondaryMuscles: [.arms, .shoulders],
            difficulty: .intermediate, equipment: "Barbell + Incline Bench", setsReps: "4 × 10",
            formTips: [
                "Pull elbows back and high — don't just pull with biceps",
                "Squeeze shoulder blades together at the top",
                "Control the descent for maximum muscle tension",
                "Keep chest firmly on the pad throughout"
            ],
            gifFilename: "incline_barbell_row"
        ),
        Exercise(
            name: "Lat Pull Down",
            shortDescription: "Machine row for lat width",
            fullDescription: "Seated at a cable machine, pull a wide bar to your upper chest. Beginner-friendly and excellent for building the lat width that creates the V-taper look. A stepping stone toward pull-ups.",
            muscleGroup: .back, secondaryMuscles: [.arms],
            difficulty: .beginner, equipment: "Cable Machine", setsReps: "3 × 12",
            formTips: [
                "Lean back 15–20° with chest proud",
                "Pull to your upper chest — never behind the neck",
                "Hold and squeeze for 1 second at the bottom",
                "Control the weight back up — 3 seconds up"
            ],
            gifFilename: "lat_pull_down"
        ),

        // ── LEGS ───────────────────────────────────────────────────────────
        Exercise(
            name: "Back Squat",
            shortDescription: "King of all lower body exercises",
            fullDescription: "Barbell on traps, feet shoulder-width, descend to parallel then drive back up. The most effective single movement for building strength, muscle, and athletic power throughout the entire lower body.",
            muscleGroup: .legs, secondaryMuscles: [.core, .back],
            difficulty: .intermediate, equipment: "Barbell", setsReps: "4 × 6–10",
            formTips: [
                "Chest up, core braced before descending",
                "Knees track over toes — don't let them cave",
                "Reach parallel or below for full muscle activation",
                "Drive through heel and mid-foot on the way up"
            ],
            gifFilename: "back_squat"
        ),
        Exercise(
            name: "Dumbbell Goblet Squat",
            shortDescription: "Beginner-friendly squat with great depth",
            fullDescription: "Holding a dumbbell at chest height, squat deep between your elbows. Teaches perfect squat mechanics naturally, improves ankle mobility, and builds quad strength. The best squat variation for beginners.",
            muscleGroup: .legs, secondaryMuscles: [.core],
            difficulty: .beginner, equipment: "Dumbbell", setsReps: "3 × 15",
            formTips: [
                "Hold weight close to chest, elbows inside knees at bottom",
                "Sit deep — this exercise is designed for depth",
                "Keep heels firmly flat throughout",
                "Great for teaching squat mechanics before adding load"
            ],
            gifFilename: "dumbbell_goblet_squat"
        ),
        Exercise(
            name: "Conventional Deadlift",
            shortDescription: "Full-body strength builder — nothing rivals it",
            fullDescription: "Pull a loaded barbell from the floor to standing lockout. Engages more total muscle mass than any other exercise — hamstrings, glutes, back, traps, and grip working in unison. The ultimate test of raw strength.",
            muscleGroup: .legs, secondaryMuscles: [.back, .core],
            difficulty: .intermediate, equipment: "Barbell", setsReps: "3 × 5",
            formTips: [
                "Bar stays in contact with your legs the whole lift",
                "Hips and shoulders rise at the same rate off the floor",
                "Lock out hips fully at the top — don't lean back",
                "Never round the lower back under load"
            ],
            gifFilename: "conventional_deadlift"
        ),
        Exercise(
            name: "Romanian Deadlift",
            shortDescription: "Hip hinge for hamstrings and glutes",
            fullDescription: "With soft knees, hinge forward at the hip driving the bar down your legs until a deep hamstring stretch, then drive hips forward to stand. The most effective hamstring exercise that also hits glutes hard.",
            muscleGroup: .legs, secondaryMuscles: [.back, .core],
            difficulty: .intermediate, equipment: "Barbell / Dumbbells", setsReps: "3 × 10",
            formTips: [
                "Push hips back — not knees forward",
                "Bar stays close to your legs throughout the whole movement",
                "Neutral spine always — zero rounding",
                "Feel the hamstring stretch at the bottom before reversing"
            ],
            gifFilename: "romanian_deadlift"
        ),
        Exercise(
            name: "Dumbbell Lunge",
            shortDescription: "Single-leg strength and balance",
            fullDescription: "Holding dumbbells, step forward into a lunge and lower the rear knee toward the floor, then step through. Builds unilateral leg strength and hip flexibility — essential for athletic performance.",
            muscleGroup: .legs, secondaryMuscles: [.core],
            difficulty: .beginner, equipment: "Dumbbells", setsReps: "3 × 12 each leg",
            formTips: [
                "Step large enough that front shin stays vertical",
                "Torso stays upright — don't lean forward",
                "Rear knee approaches but doesn't slam the floor",
                "Drive through front heel to step through"
            ],
            gifFilename: "dumbbell_lunge"
        ),
        Exercise(
            name: "Hip Thrust",
            shortDescription: "Highest glute activation of any exercise",
            fullDescription: "Upper back on a bench, barbell across hips, bridge upward by squeezing the glutes to full hip extension. Research consistently shows hip thrusts produce greater glute activation than squats or deadlifts.",
            muscleGroup: .legs, secondaryMuscles: [.core],
            difficulty: .intermediate, equipment: "Bench + Barbell", setsReps: "4 × 12",
            formTips: [
                "Chin tucked — look forward, not at the ceiling",
                "Drive through heels to achieve full hip extension",
                "2-second squeeze at the top with hard glute contraction",
                "Use a barbell pad for hip comfort on heavy sets"
            ],
            gifFilename: "hip_thrust"
        ),
        Exercise(
            name: "Leg Press",
            shortDescription: "Machine quad and glute builder",
            fullDescription: "Push a weighted sled away with your legs while seated. Allows heavy loading without spinal compression — great as an accessory after squats or for building volume during quad-focused training blocks.",
            muscleGroup: .legs, secondaryMuscles: [],
            difficulty: .beginner, equipment: "Leg Press Machine", setsReps: "3 × 15",
            formTips: [
                "Never lock your knees fully at the top",
                "Lower until thighs pass parallel to the sled",
                "Keep lower back pressed against the seat throughout",
                "High foot placement targets glutes; low targets quads"
            ],
            gifFilename: "leg_press"
        ),
        Exercise(
            name: "Standing Calf Raise",
            shortDescription: "Calf isolation through full range of motion",
            fullDescription: "Standing on an edge, lower your heels fully then rise onto your toes. Calves need high volume and a full stretch — they're always active but rarely trained through complete range, making isolation essential.",
            muscleGroup: .legs, secondaryMuscles: [],
            difficulty: .beginner, equipment: "None / Machine", setsReps: "4 × 20",
            formTips: [
                "Full 1-second pause at the bottom stretch",
                "Rise as high as possible — full plantarflexion",
                "Lower slowly — 3 seconds down for maximum tension",
                "Slight knee bend targets the deeper soleus muscle"
            ],
            gifFilename: "standingcalf_raise"
        ),

        // ── SHOULDERS ──────────────────────────────────────────────────────
        Exercise(
            name: "Overhead Press",
            shortDescription: "Standing press for full shoulder mass",
            fullDescription: "Press a barbell from shoulder height to overhead lockout while standing. The premier shoulder mass builder that also demands significant core stability. Tests and builds full-body strength.",
            muscleGroup: .shoulders, secondaryMuscles: [.arms, .core],
            difficulty: .intermediate, equipment: "Barbell / Dumbbells", setsReps: "4 × 6–10",
            formTips: [
                "Brace core hard — imagine bracing for a punch",
                "Bar travels slightly behind your face at lockout",
                "Full elbow lockout overhead on every rep",
                "Don't hyperextend your lower back — squeeze glutes"
            ],
            gifFilename: "overhead_press"
        ),
        Exercise(
            name: "Dumbbell Lateral Raise",
            shortDescription: "Width and definition for the medial delt",
            fullDescription: "Raise dumbbells out to shoulder height. Isolates the medial (side) deltoid — the muscle responsible for the wide, capped shoulder look. Non-negotiable for well-rounded shoulder development.",
            muscleGroup: .shoulders, secondaryMuscles: [],
            difficulty: .beginner, equipment: "Dumbbells", setsReps: "3 × 15–20",
            formTips: [
                "Lead with elbows, not your wrists or hands",
                "A slight forward lean targets the medial head better",
                "Don't swing — strict form only",
                "Lower in 3 seconds for maximum time under tension"
            ],
            gifFilename: "dumbbell_lateral_raise"
        ),
        Exercise(
            name: "Barbell Front Raise",
            shortDescription: "Anterior deltoid isolation",
            fullDescription: "Raise a barbell from in front of your thighs to shoulder height. Directly targets the front (anterior) deltoid head — complementing lateral raises for complete shoulder development.",
            muscleGroup: .shoulders, secondaryMuscles: [],
            difficulty: .beginner, equipment: "Barbell / Dumbbells", setsReps: "3 × 12",
            formTips: [
                "Keep a slight elbow bend throughout",
                "Raise only to shoulder height — not higher",
                "Control the descent — don't drop the weight",
                "Avoid swinging — initiate from the shoulder"
            ],
            gifFilename: "barbell_front_raise"
        ),
        Exercise(
            name: "Face Pull",
            shortDescription: "Rear delts, rotator cuff, and posture",
            fullDescription: "Using a rope at face height on a cable machine, pull toward your face with elbows high. Builds the often-neglected rear delts and external rotators — critical for shoulder health, posture, and injury prevention.",
            muscleGroup: .shoulders, secondaryMuscles: [.back],
            difficulty: .beginner, equipment: "Cable Machine + Rope", setsReps: "3 × 15",
            formTips: [
                "Pull to face level — elbows must stay high throughout",
                "External rotate at the end — hands go back behind the rope",
                "Light weight, high reps — focus on the movement pattern",
                "Include these every session for long-term shoulder health"
            ],
            gifFilename: "face_pull"
        ),

        // ── ARMS ───────────────────────────────────────────────────────────
        Exercise(
            name: "Dumbbell Bicep Curl",
            shortDescription: "Classic bicep isolation exercise",
            fullDescription: "Standing with dumbbells, curl them by flexing the elbow while keeping upper arms pinned to your sides. Targets the biceps brachii and brachialis for full arm development.",
            muscleGroup: .arms, secondaryMuscles: [],
            difficulty: .beginner, equipment: "Dumbbells", setsReps: "3 × 12",
            formTips: [
                "Upper arms stationary — don't swing or lean back",
                "Supinate (rotate) wrists as you curl up",
                "Squeeze hard at the top for 1 second",
                "Lower slowly — 3-second eccentric builds more muscle"
            ],
            gifFilename: "dumbbell_bicep_curl"
        ),
        Exercise(
            name: "Dumbbell Hammer Curl",
            shortDescription: "Targets brachialis for arm thickness",
            fullDescription: "Neutral-grip (thumbs up) curl that targets the brachialis — the muscle underneath the bicep. When developed it pushes the bicep up, making arms look significantly thicker and more impressive.",
            muscleGroup: .arms, secondaryMuscles: [],
            difficulty: .beginner, equipment: "Dumbbells", setsReps: "3 × 12",
            formTips: [
                "Keep neutral (hammer) grip throughout — no wrist rotation",
                "Curl straight up, not across the body",
                "Can be done alternating or both simultaneously",
                "Also develops the forearms and brachioradialis"
            ],
            gifFilename: "dumbbell_hammer_curl"
        ),
        Exercise(
            name: "Dips",
            shortDescription: "Bodyweight tricep and chest compound",
            fullDescription: "On parallel bars, lower your body by bending the elbows then press back to lockout. Works the triceps (2/3 of the upper arm), chest, and anterior delts. Add weight with a dipping belt to progress.",
            muscleGroup: .arms, secondaryMuscles: [.chest, .shoulders],
            difficulty: .intermediate, equipment: "Parallel Bars", setsReps: "3 × 10–12",
            formTips: [
                "Stay upright for more tricep, lean forward for more chest",
                "Lower until upper arms are parallel to the floor",
                "Full elbow lockout at the top of every rep",
                "Don't flare elbows — keep them tracking backward"
            ],
            gifFilename: "dips"
        ),
        Exercise(
            name: "Skull Crusher",
            shortDescription: "Long-head tricep isolation on bench",
            fullDescription: "Lying on a bench, lower a barbell toward your forehead then extend back up. Specifically targets the long head of the tricep — the largest portion — for maximum arm mass.",
            muscleGroup: .arms, secondaryMuscles: [],
            difficulty: .intermediate, equipment: "EZ Bar + Bench", setsReps: "3 × 12",
            formTips: [
                "Only the forearms move — upper arms stay fixed vertical",
                "Lower to forehead level — that's where the name comes from",
                "Use an EZ bar to reduce wrist strain",
                "Keep elbows pointed at the ceiling throughout"
            ],
            gifFilename: "skull_crusher"
        ),

        // ── CORE ───────────────────────────────────────────────────────────
        Exercise(
            name: "Plank",
            shortDescription: "Isometric core endurance and total-body stability",
            fullDescription: "Hold a push-up position on forearms with a rigid, flat body. Builds the deep core stability that transfers to every athletic movement. Holding a 2-minute plank with perfect form represents genuinely strong core.",
            muscleGroup: .core, secondaryMuscles: [.shoulders],
            difficulty: .beginner, equipment: "None", setsReps: "3 × 30–90 sec",
            formTips: [
                "Straight line from head to heels — always",
                "Squeeze glutes and brace abs simultaneously",
                "Breathe normally — don't hold your breath",
                "Push the floor away hard with your forearms"
            ],
            gifFilename: "plank"
        ),
        Exercise(
            name: "Crunch",
            shortDescription: "Classic upper abdominal isolation",
            fullDescription: "Lying with knees bent, curl your upper body toward your knees by contracting the abs. Focus on quality of contraction rather than range of motion — the lower back should never fully leave the floor.",
            muscleGroup: .core, secondaryMuscles: [],
            difficulty: .beginner, equipment: "None", setsReps: "3 × 20",
            formTips: [
                "Press lower back firmly into the floor throughout",
                "Hands lightly behind ears — don't pull on your neck",
                "Exhale forcefully at the peak contraction",
                "1-second hold at the top of every rep"
            ],
            gifFilename: "crunch"
        ),
        Exercise(
            name: "Leg Raise",
            shortDescription: "Lower abs and hip flexor development",
            fullDescription: "Lying flat, raise both straight legs from the floor to vertical then lower with control. Targets the lower portion of the rectus abdominis and hip flexors in a way that crunches simply cannot reach.",
            muscleGroup: .core, secondaryMuscles: [],
            difficulty: .intermediate, equipment: "None", setsReps: "3 × 15",
            formTips: [
                "Press lower back firmly into the floor at all times",
                "Don't let feet touch the ground at the bottom",
                "Keep legs straight or with a very slight bend",
                "Move with control — zero swinging or momentum"
            ],
            gifFilename: "leg_raise"
        ),
        Exercise(
            name: "Russian Twist",
            shortDescription: "Rotational core and oblique exercise",
            fullDescription: "Seated at 45° with a weight, rotate side to side. Trains the rotational function of the core — obliques and transverse abdominis — that crunches completely miss. Essential for real-world core strength.",
            muscleGroup: .core, secondaryMuscles: [],
            difficulty: .beginner, equipment: "None / Weight Plate", setsReps: "3 × 20 twists",
            formTips: [
                "Lift feet off the floor for maximum core challenge",
                "Touch the weight to the floor on each side",
                "Rotate from your torso — not your arms",
                "Keep chest tall — don't collapse forward"
            ],
            gifFilename: "russian_twist"  // .png — resolved automatically by loader
        ),

        // ── CARDIO ─────────────────────────────────────────────────────────
        Exercise(
            name: "Mountain Climber",
            shortDescription: "Core stability meets cardio intensity",
            fullDescription: "In a high plank, rapidly alternate driving your knees toward your chest. Combines the stability demand of a plank with the cardiovascular intensity of sprinting — one of the most efficient calorie-burning movements.",
            muscleGroup: .cardio, secondaryMuscles: [.core, .shoulders],
            difficulty: .beginner, equipment: "None", setsReps: "3 × 30 seconds",
            formTips: [
                "Hips stay level — don't pike up during the movement",
                "Drive knee as far forward as possible each rep",
                "Stay on your toes throughout for maximum speed",
                "Slower = more core work; faster = more cardio conditioning"
            ],
            gifFilename: "mountain_climber"
        ),
        Exercise(
            name: "Burpee",
            shortDescription: "Total-body conditioning — maximum output",
            fullDescription: "Squat, jump feet back to plank, push-up, jump feet forward, jump and clap overhead. The most demanding and efficient bodyweight conditioning movement — burns serious calories and builds full-body endurance.",
            muscleGroup: .cardio, secondaryMuscles: [.chest, .core, .legs],
            difficulty: .intermediate, equipment: "None", setsReps: "3 × 10",
            formTips: [
                "Pace yourself — quality of movement over raw speed",
                "Land softly — absorb impact through hips and knees",
                "Full extension on the jump — arms fully overhead",
                "Scale by stepping feet instead of jumping if needed"
            ],
            gifFilename: "burpee"
        ),
        Exercise(
            name: "Jumping Jack",
            shortDescription: "Classic cardio warm-up",
            fullDescription: "Jump feet out while raising arms overhead, then return. A classic full-body warm-up that elevates heart rate, warms the joints, and burns more calories per minute than most people expect.",
            muscleGroup: .cardio, secondaryMuscles: [],
            difficulty: .beginner, equipment: "None", setsReps: "3 × 30 seconds",
            formTips: [
                "Land on the balls of your feet to protect your joints",
                "Maintain a slight bend in the knees throughout",
                "Full arm arc to overhead on every rep",
                "Keep a steady controlled rhythm"
            ],
            gifFilename: "jumping_jack"
        ),
        Exercise(
            name: "Box Jump",
            shortDescription: "Explosive plyometric lower body power",
            fullDescription: "Jump from the floor onto a sturdy box, landing softly in a partial squat, then step back down. Builds fast-twitch muscle fibres and explosive power that transfers directly to athletic and sport performance.",
            muscleGroup: .cardio, secondaryMuscles: [.legs],
            difficulty: .intermediate, equipment: "Plyo Box", setsReps: "4 × 8",
            formTips: [
                "Swing arms to generate maximum upward momentum",
                "Land quietly — absorb impact through knees and hips",
                "Always step down — never jump down from the box",
                "Take full rest between reps to ensure maximum power"
            ],
            gifFilename: "box_jump"
        ),
    ]

    // MARK: - Convenience

    static func filtered(by group: MuscleGroup?) -> [Exercise] {
        guard let group else { return all }
        return all.filter { $0.muscleGroup == group }
    }

    static var allGroups: [MuscleGroup] {
        Array(Set(all.map(\.muscleGroup))).sorted { $0.rawValue < $1.rawValue }
    }
}
