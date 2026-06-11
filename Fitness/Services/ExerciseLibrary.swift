import Foundation

// MARK: - Template

struct ExerciseTemplate {
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: Equipment
    let minExperience: ExperienceLevel
    let cues: [String]
    let sessionTypes: Set<SessionType>

    func block(sets: Int, repsLow: Int, repsHigh: Int, restSeconds: Int, tempo: String = "2-0-1") -> ExerciseBlock {
        ExerciseBlock(
            id: UUID().uuidString,
            name: name, sets: sets, repsLow: repsLow, repsHigh: repsHigh,
            restSeconds: restSeconds, tempo: tempo, cues: cues,
            muscleGroup: muscleGroup, equipment: equipment
        )
    }
}

// MARK: - Library

enum ExerciseLibrary {
    static let all: [ExerciseTemplate] = push + pull + legs + core + cardioHIIT + recovery

    // MARK: Push

    static let push: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Push-Up", muscleGroup: .chest, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Shoulders over wrists", "Keep hips level", "Full chest-to-floor range"],
            sessionTypes: [.push, .upper, .fullBody]),
        ExerciseTemplate(name: "Incline Push-Up", muscleGroup: .chest, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Hands on elevated surface", "Straight body line", "Lower chest to surface"],
            sessionTypes: [.push, .upper, .fullBody]),
        ExerciseTemplate(name: "Pike Push-Up", muscleGroup: .shoulders, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Hips high", "Lower crown to floor", "Press back to start"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Close-Grip Push-Up", muscleGroup: .triceps, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Hands shoulder-width", "Elbows track back", "Full range"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Tricep Dips", muscleGroup: .triceps, equipment: .bodyweight, minExperience: .intermediate,
            cues: ["Shoulders down", "Slight forward lean for chest focus", "Full extension at top"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Dumbbell Bench Press", muscleGroup: .chest, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Feet flat", "Retract scapula", "Controlled descent to chest"],
            sessionTypes: [.push, .upper, .fullBody]),
        ExerciseTemplate(name: "Dumbbell Shoulder Press", muscleGroup: .shoulders, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Core braced", "Elbows slightly forward", "Lock out overhead"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Dumbbell Lateral Raise", muscleGroup: .shoulders, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Slight bend at elbow", "Raise to shoulder height", "Lead with elbows"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Dumbbell Tricep Kickback", muscleGroup: .triceps, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Upper arm parallel to floor", "Extend fully", "Slow on way back"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell, minExperience: .intermediate,
            cues: ["5-point contact", "Bar to lower chest", "Drive feet into floor"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Overhead Press", muscleGroup: .shoulders, equipment: .barbell, minExperience: .intermediate,
            cues: ["Bar in front rack", "Core tight", "Press bar over head, not forward"],
            sessionTypes: [.push, .upper]),
        ExerciseTemplate(name: "Band Push-Down", muscleGroup: .triceps, equipment: .resistanceBands, minExperience: .beginner,
            cues: ["Elbows fixed at sides", "Full extension", "Controlled return"],
            sessionTypes: [.push, .upper]),
    ]

    // MARK: Pull

    static let pull: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Bodyweight Row", muscleGroup: .back, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Straight body from heels to head", "Pull chest to bar or surface", "Squeeze shoulder blades"],
            sessionTypes: [.pull, .upper, .fullBody]),
        ExerciseTemplate(name: "Dumbbell Row", muscleGroup: .back, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Flat back", "Pull elbow to hip", "Hold 1 second at top"],
            sessionTypes: [.pull, .upper, .fullBody]),
        ExerciseTemplate(name: "Dumbbell Bicep Curl", muscleGroup: .biceps, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Elbows fixed at sides", "Supinate at top", "Lower under control"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Dumbbell Rear Delt Fly", muscleGroup: .back, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Hinge at hips", "Slight bend at elbow", "Raise to shoulder height"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Band Pull-Apart", muscleGroup: .back, equipment: .resistanceBands, minExperience: .beginner,
            cues: ["Arms straight", "Pull to chest width", "Controlled return"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Band Bicep Curl", muscleGroup: .biceps, equipment: .resistanceBands, minExperience: .beginner,
            cues: ["Stand on band", "Elbows fixed", "Full curl"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Face Pull", muscleGroup: .shoulders, equipment: .resistanceBands, minExperience: .beginner,
            cues: ["Anchor at eye level", "Pull to face, elbows high", "External rotation finish"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Pull-Up", muscleGroup: .back, equipment: .pullupBar, minExperience: .intermediate,
            cues: ["Dead hang start", "Drive elbows to hips", "Chin over bar"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Chin-Up", muscleGroup: .biceps, equipment: .pullupBar, minExperience: .intermediate,
            cues: ["Supinated grip", "Full extension at bottom", "Pull to upper chest"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Hanging Knee Raise", muscleGroup: .core, equipment: .pullupBar, minExperience: .beginner,
            cues: ["Dead hang", "Compress abs to raise knees", "Lower with control"],
            sessionTypes: [.pull, .upper]),
        ExerciseTemplate(name: "Barbell Row", muscleGroup: .back, equipment: .barbell, minExperience: .intermediate,
            cues: ["Hip-hinged 45°", "Bar to belly button", "Keep back flat"],
            sessionTypes: [.pull, .upper]),
    ]

    // MARK: Legs

    static let legs: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Bodyweight Squat", muscleGroup: .quads, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Feet shoulder-width", "Knees track toes", "Hip crease below knee at depth"],
            sessionTypes: [.legs, .lower, .fullBody]),
        ExerciseTemplate(name: "Reverse Lunge", muscleGroup: .quads, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Step back, not forward", "Front knee over ankle", "Drive through front heel"],
            sessionTypes: [.legs, .lower, .fullBody]),
        ExerciseTemplate(name: "Glute Bridge", muscleGroup: .glutes, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Feet flat and close", "Drive hips up", "Squeeze glutes at top for 2s"],
            sessionTypes: [.legs, .lower, .activeRecovery]),
        ExerciseTemplate(name: "Step-Up", muscleGroup: .quads, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Whole foot on surface", "Drive through heel", "Don't push off trailing foot"],
            sessionTypes: [.legs, .lower, .fullBody]),
        ExerciseTemplate(name: "Calf Raise", muscleGroup: .calves, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Full stretch at bottom", "Pause at top", "Controlled descent"],
            sessionTypes: [.legs, .lower]),
        ExerciseTemplate(name: "Single-Leg Glute Bridge", muscleGroup: .glutes, equipment: .bodyweight, minExperience: .beginner,
            cues: ["One leg extended", "Drive through planted heel", "Level hips"],
            sessionTypes: [.legs, .lower, .activeRecovery]),
        ExerciseTemplate(name: "Dumbbell Goblet Squat", muscleGroup: .quads, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Hold dumbbell at chest", "Elbows inside knees", "Sit back and down"],
            sessionTypes: [.legs, .lower, .fullBody]),
        ExerciseTemplate(name: "Dumbbell Romanian Deadlift", muscleGroup: .hamstrings, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Soft knee", "Push hips back", "Weights stay close to legs"],
            sessionTypes: [.legs, .lower]),
        ExerciseTemplate(name: "Dumbbell Walking Lunge", muscleGroup: .quads, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Long stride", "Back knee to 1 inch above floor", "Upright torso"],
            sessionTypes: [.legs, .lower, .fullBody]),
        ExerciseTemplate(name: "Hip Thrust", muscleGroup: .glutes, equipment: .dumbbells, minExperience: .beginner,
            cues: ["Shoulders on bench", "Weight on hips", "Drive hips up, squeeze at top"],
            sessionTypes: [.legs, .lower]),
        ExerciseTemplate(name: "Kettlebell Swing", muscleGroup: .glutes, equipment: .kettlebell, minExperience: .intermediate,
            cues: ["Hinge, don't squat", "Drive hips forward", "Float to shoulder height"],
            sessionTypes: [.legs, .lower, .hiit, .fullBody]),
        ExerciseTemplate(name: "Kettlebell Goblet Squat", muscleGroup: .quads, equipment: .kettlebell, minExperience: .beginner,
            cues: ["Hold at chest", "Elbows inside knees", "Full depth"],
            sessionTypes: [.legs, .lower, .fullBody]),
        ExerciseTemplate(name: "Barbell Squat", muscleGroup: .quads, equipment: .barbell, minExperience: .intermediate,
            cues: ["Bar on traps", "Brace 360°", "Break at hips and knees simultaneously"],
            sessionTypes: [.legs, .lower]),
        ExerciseTemplate(name: "Barbell Deadlift", muscleGroup: .hamstrings, equipment: .barbell, minExperience: .intermediate,
            cues: ["Neutral spine", "Lats engaged", "Push floor away, don't lift bar"],
            sessionTypes: [.legs, .lower]),
        ExerciseTemplate(name: "Band Squat", muscleGroup: .quads, equipment: .resistanceBands, minExperience: .beginner,
            cues: ["Stand on band", "Hold at shoulders", "Squat to parallel"],
            sessionTypes: [.legs, .lower, .fullBody]),
    ]

    // MARK: Core

    static let core: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Plank", muscleGroup: .core, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Neutral spine", "Squeeze glutes", "Breathe steadily"],
            sessionTypes: [.push, .pull, .legs, .upper, .lower, .fullBody, .activeRecovery]),
        ExerciseTemplate(name: "Dead Bug", muscleGroup: .core, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Low back pressed to floor", "Opposite arm-leg extension", "Exhale on extension"],
            sessionTypes: [.fullBody, .activeRecovery]),
        ExerciseTemplate(name: "Side Plank", muscleGroup: .core, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Stack feet or stagger", "Drive hip up", "Top arm to ceiling"],
            sessionTypes: [.push, .pull, .fullBody, .activeRecovery]),
        ExerciseTemplate(name: "Mountain Climber", muscleGroup: .core, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Plank position", "Drive knee to chest", "Quick alternating pace"],
            sessionTypes: [.hiit, .fullBody, .cardio]),
        ExerciseTemplate(name: "Hollow Hold", muscleGroup: .core, equipment: .bodyweight, minExperience: .intermediate,
            cues: ["Lower back pressed down", "Arms overhead", "Legs low but not touching floor"],
            sessionTypes: [.push, .pull, .fullBody]),
        ExerciseTemplate(name: "Russian Twist", muscleGroup: .core, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Lean back 45°", "Feet lifted", "Rotate fully each side"],
            sessionTypes: [.fullBody, .activeRecovery]),
    ]

    // MARK: Cardio & HIIT

    static let cardioHIIT: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Jumping Jack", muscleGroup: .cardio, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Land softly", "Full arm range", "Controlled pace"],
            sessionTypes: [.hiit, .cardio, .fullBody]),
        ExerciseTemplate(name: "High Knees", muscleGroup: .cardio, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Drive knee to hip height", "Pump arms", "Land on balls of feet"],
            sessionTypes: [.hiit, .cardio]),
        ExerciseTemplate(name: "Skater", muscleGroup: .glutes, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Lateral bound", "Stick landing", "Reach for opposite foot"],
            sessionTypes: [.hiit, .cardio]),
        ExerciseTemplate(name: "Burpee", muscleGroup: .fullBody, equipment: .bodyweight, minExperience: .intermediate,
            cues: ["Jump feet back to plank", "Chest to floor", "Explosive jump at top"],
            sessionTypes: [.hiit, .fullBody]),
        ExerciseTemplate(name: "Squat Jump", muscleGroup: .quads, equipment: .bodyweight, minExperience: .intermediate,
            cues: ["Descend to full squat", "Explosive jump", "Soft landing"],
            sessionTypes: [.hiit, .legs, .fullBody]),
        ExerciseTemplate(name: "Box Jump", muscleGroup: .quads, equipment: .bodyweight, minExperience: .intermediate,
            cues: ["Arm swing for momentum", "Land soft and stable", "Step down, don't jump off"],
            sessionTypes: [.hiit, .legs]),
        ExerciseTemplate(name: "Treadmill Intervals", muscleGroup: .cardio, equipment: .cardioMachine, minExperience: .beginner,
            cues: ["Warm up 5 min", "Alternate work/rest intervals", "Cool down 5 min"],
            sessionTypes: [.cardio, .hiit]),
    ]

    // MARK: Active Recovery

    static let recovery: [ExerciseTemplate] = [
        ExerciseTemplate(name: "World's Greatest Stretch", muscleGroup: .fullBody, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Lunge forward", "Elbow to floor", "Reach to sky"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Deep Squat Hold", muscleGroup: .quads, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Feet wide, toes out", "Elbows inside knees", "Breathe deeply"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Hip Flexor Stretch", muscleGroup: .quads, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Half-kneeling position", "Tuck pelvis", "Reach forward"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Thoracic Rotation", muscleGroup: .back, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Side-lying", "Rotate upper back", "Follow hand with eyes"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Cat-Cow", muscleGroup: .core, equipment: .bodyweight, minExperience: .beginner,
            cues: ["On all fours", "Arch on inhale", "Round on exhale"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Child's Pose", muscleGroup: .back, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Arms extended", "Hips to heels", "Breathe into lower back"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Hamstring Floss", muscleGroup: .hamstrings, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Seated, leg extended", "Flex and point foot", "Gentle oscillation"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Shoulder CARs", muscleGroup: .shoulders, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Slow controlled arc", "Max range at end", "Opposite arm stabilizes"],
            sessionTypes: [.activeRecovery]),
        ExerciseTemplate(name: "Glute Bridge Hold", muscleGroup: .glutes, equipment: .bodyweight, minExperience: .beginner,
            cues: ["Feet flat and close", "Hold at top", "Breathe steadily"],
            sessionTypes: [.activeRecovery]),
    ]

    // MARK: - Lookup

    static func exercises(
        for sessionType: SessionType,
        equipment: [Equipment],
        experience: ExperienceLevel
    ) -> [ExerciseTemplate] {
        let expRank = ExperienceLevel.allCases.firstIndex(of: experience) ?? 0
        var matched = all.filter { t in
            t.sessionTypes.contains(sessionType) &&
            equipment.contains(t.equipment) &&
            (ExperienceLevel.allCases.firstIndex(of: t.minExperience) ?? 0) <= expRank
        }
        // Fallback to bodyweight so there's always something to show
        if matched.isEmpty {
            matched = all.filter { t in
                t.sessionTypes.contains(sessionType) &&
                t.equipment == .bodyweight &&
                (ExperienceLevel.allCases.firstIndex(of: t.minExperience) ?? 0) <= expRank
            }
        }
        return matched
    }
}
