//
//  ContentView.swift
//  FitSight
//
//  Created by 32 on 2026/5/7.
//

import AVFoundation
import HealthKit
import ImageIO
import SwiftUI
import Vision

struct ContentView: View {
    @StateObject private var model = FitSightModel()
    @StateObject private var healthStore = HealthEnergyStore()

    var body: some View {
        TabView {
            TodayView(model: model, healthStore: healthStore)
                .tabItem {
                    Label("Today", systemImage: "target")
                }

            CoachView(model: model)
                .tabItem {
                    Label("Coach", systemImage: "figure.strengthtraining.traditional")
                }

            FormCoachView()
                .tabItem {
                    Label("Form", systemImage: "camera.viewfinder")
                }

            ProgressView(model: model)
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.xaxis")
                }

            ReadinessView()
                .tabItem {
                    Label("Ready", systemImage: "checkmark.seal")
                }
        }
        .tint(.mint)
        .onReceive(healthStore.$activeEnergyToday) { activeEnergy in
            model.activeEnergy = activeEnergy
        }
    }
}

final class FitSightModel: ObservableObject {
    @Published var dailyCalorieGoal: Double {
        didSet { UserDefaults.standard.set(dailyCalorieGoal, forKey: "dailyCalorieGoal") }
    }

    @Published var workoutMinutes: Double {
        didSet { UserDefaults.standard.set(workoutMinutes, forKey: "workoutMinutes") }
    }

    @Published var goal: FitnessGoal {
        didSet { UserDefaults.standard.set(goal.rawValue, forKey: "fitnessGoal") }
    }

    @Published var focus: WorkoutFocus {
        didSet { UserDefaults.standard.set(focus.rawValue, forKey: "workoutFocus") }
    }

    @Published var activeEnergy: Double = 0

    let weeklyEnergy: [DailyMetric] = [
        DailyMetric(day: "Mon", value: 410),
        DailyMetric(day: "Tue", value: 530),
        DailyMetric(day: "Wed", value: 360),
        DailyMetric(day: "Thu", value: 620),
        DailyMetric(day: "Fri", value: 455),
        DailyMetric(day: "Sat", value: 700),
        DailyMetric(day: "Sun", value: 280)
    ]

    init() {
        let storedGoal = UserDefaults.standard.double(forKey: "dailyCalorieGoal")
        dailyCalorieGoal = storedGoal == 0 ? 650 : storedGoal

        let storedMinutes = UserDefaults.standard.double(forKey: "workoutMinutes")
        workoutMinutes = storedMinutes == 0 ? 25 : storedMinutes

        let goalValue = UserDefaults.standard.string(forKey: "fitnessGoal") ?? FitnessGoal.fatLoss.rawValue
        goal = FitnessGoal(rawValue: goalValue) ?? .fatLoss

        let focusValue = UserDefaults.standard.string(forKey: "workoutFocus") ?? WorkoutFocus.balanced.rawValue
        focus = WorkoutFocus(rawValue: focusValue) ?? .balanced
    }

    var activeEnergyProgress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(activeEnergy / dailyCalorieGoal, 1)
    }

    var remainingCalories: Double {
        max(dailyCalorieGoal - activeEnergy, 0)
    }

    var recommendations: [WorkoutRecommendation] {
        RecommendationEngine.recommendations(
            remainingCalories: remainingCalories,
            minutes: Int(workoutMinutes),
            goal: goal,
            focus: focus
        )
    }
}

enum FitnessGoal: String, CaseIterable, Identifiable {
    case fatLoss = "Fat loss"
    case maintenance = "Maintain"
    case strength = "Strength"
    case endurance = "Endurance"

    var id: String { rawValue }
}

enum WorkoutFocus: String, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case lowImpact = "Low impact"
    case strength = "Strength"
    case cardio = "Cardio"
    case mobility = "Mobility"

    var id: String { rawValue }
}

struct DailyMetric: Identifiable {
    let day: String
    let value: Double

    var id: String { day }
}

struct WorkoutRecommendation: Identifiable {
    let title: String
    let subtitle: String
    let minutes: Int
    let calories: Int
    let intensity: String
    let symbolName: String
    let steps: [String]

    var id: String { title }
}

enum RecommendationEngine {
    static func recommendations(
        remainingCalories: Double,
        minutes: Int,
        goal: FitnessGoal,
        focus: WorkoutFocus
    ) -> [WorkoutRecommendation] {
        let shortSession = max(minutes, 10)
        let calorieTarget = max(Int(remainingCalories), 120)

        if remainingCalories <= 40 {
            return [
                WorkoutRecommendation(
                    title: "Recovery Mobility",
                    subtitle: "You are close to today's goal. Keep the body loose.",
                    minutes: min(shortSession, 18),
                    calories: 70,
                    intensity: "Easy",
                    symbolName: "figure.cooldown",
                    steps: ["Hip openers", "Thoracic rotations", "Hamstring floss", "Box breathing"]
                ),
                WorkoutRecommendation(
                    title: "Form Practice",
                    subtitle: "Use the camera coach for clean reps instead of chasing more burn.",
                    minutes: 12,
                    calories: 55,
                    intensity: "Technique",
                    symbolName: "camera.viewfinder",
                    steps: ["5 bodyweight squats", "5 incline push-ups", "20-second plank", "Review form cues"]
                )
            ]
        }

        switch focus {
        case .lowImpact:
            return [
                WorkoutRecommendation(
                    title: "Incline Walk",
                    subtitle: "Low joint stress with steady calorie progress.",
                    minutes: shortSession,
                    calories: min(calorieTarget, shortSession * 8),
                    intensity: "Moderate",
                    symbolName: "figure.walk.motion",
                    steps: ["5-minute warm-up", "Incline intervals", "Nasal-breathing cooldown"]
                ),
                WorkoutRecommendation(
                    title: "Mobility Strength",
                    subtitle: "Controlled tempo work for strength and range.",
                    minutes: 22,
                    calories: 150,
                    intensity: "Easy",
                    symbolName: "figure.flexibility",
                    steps: ["Glute bridges", "Split-squat holds", "Dead bugs", "Side planks"]
                )
            ]
        case .strength:
            return strengthRecommendations(minutes: shortSession, calorieTarget: calorieTarget, goal: goal)
        case .cardio:
            return cardioRecommendations(minutes: shortSession, calorieTarget: calorieTarget)
        case .mobility:
            return [
                WorkoutRecommendation(
                    title: "Move Better Flow",
                    subtitle: "A recovery-first session that still nudges the goal forward.",
                    minutes: min(shortSession, 25),
                    calories: 120,
                    intensity: "Easy",
                    symbolName: "figure.mind.and.body",
                    steps: ["World's greatest stretch", "Deep squat breathing", "Shoulder cars", "Calf rocks"]
                )
            ]
        case .balanced:
            return balancedRecommendations(minutes: shortSession, calorieTarget: calorieTarget, goal: goal)
        }
    }

    private static func balancedRecommendations(
        minutes: Int,
        calorieTarget: Int,
        goal: FitnessGoal
    ) -> [WorkoutRecommendation] {
        [
            WorkoutRecommendation(
                title: goal == .strength ? "Strength Circuit" : "Full-Body Burn",
                subtitle: "A practical mix of movement quality and calorie burn.",
                minutes: minutes,
                calories: min(calorieTarget, minutes * 10),
                intensity: "Moderate",
                symbolName: "figure.highintensity.intervaltraining",
                steps: ["Squats", "Push-ups", "Reverse lunges", "Mountain climbers", "Plank"]
            ),
            WorkoutRecommendation(
                title: "Zone 2 Builder",
                subtitle: "Steady cardio for endurance and active energy.",
                minutes: max(minutes, 30),
                calories: min(calorieTarget + 80, max(minutes, 30) * 9),
                intensity: "Steady",
                symbolName: "heart.circle",
                steps: ["Easy start", "Conversational pace", "Finish relaxed"]
            )
        ]
    }

    private static func cardioRecommendations(minutes: Int, calorieTarget: Int) -> [WorkoutRecommendation] {
        [
            WorkoutRecommendation(
                title: "HIIT Finisher",
                subtitle: "Short intervals when you need efficient active energy.",
                minutes: min(minutes, 22),
                calories: min(calorieTarget, min(minutes, 22) * 13),
                intensity: "Hard",
                symbolName: "bolt.heart",
                steps: ["Jumping jacks", "High knees", "Skaters", "Rest 45 seconds", "Repeat"]
            ),
            WorkoutRecommendation(
                title: "Tempo Cardio",
                subtitle: "Smoother than HIIT, stronger than an easy walk.",
                minutes: max(minutes, 25),
                calories: min(calorieTarget, max(minutes, 25) * 10),
                intensity: "Moderate",
                symbolName: "figure.run",
                steps: ["Warm-up", "3 tempo blocks", "Cooldown"]
            )
        ]
    }

    private static func strengthRecommendations(
        minutes: Int,
        calorieTarget: Int,
        goal: FitnessGoal
    ) -> [WorkoutRecommendation] {
        [
            WorkoutRecommendation(
                title: "Lower-Body Strength",
                subtitle: "Rep quality first, with enough density to support the goal.",
                minutes: minutes,
                calories: min(calorieTarget, minutes * 7),
                intensity: goal == .strength ? "Heavy" : "Moderate",
                symbolName: "figure.strengthtraining.traditional",
                steps: ["Squat pattern", "Hip hinge", "Reverse lunge", "Calf raise", "Core brace"]
            ),
            WorkoutRecommendation(
                title: "Upper + Core",
                subtitle: "Camera-friendly movements for form checks.",
                minutes: 24,
                calories: 170,
                intensity: "Moderate",
                symbolName: "figure.core.training",
                steps: ["Push-ups", "Rows", "Shoulder taps", "Side planks"]
            )
        ]
    }
}

final class HealthEnergyStore: ObservableObject {
    @Published var activeEnergyToday: Double = 0
    @Published var authorizationState: HealthAuthorizationState = .notRequested
    @Published var statusMessage = "Connect Apple Health to read today's active energy."

    private let store = HKHealthStore()

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            statusMessage = "Apple Health is not available on this device."
            return
        }

        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            authorizationState = .unavailable
            statusMessage = "Active energy data type is unavailable."
            return
        }

        store.requestAuthorization(toShare: [], read: [activeEnergyType]) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.authorizationState = .authorized
                    self?.statusMessage = "Apple Health connected."
                    self?.refreshToday()
                } else {
                    self?.authorizationState = .denied
                    self?.statusMessage = error?.localizedDescription ?? "Health permission was not granted."
                }
            }
        }
    }

    func refreshToday() {
        guard HKHealthStore.isHealthDataAvailable(),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: activeEnergyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            let kilocalories = statistics?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie()) ?? 0

            DispatchQueue.main.async {
                self?.activeEnergyToday = kilocalories
                self?.statusMessage = error?.localizedDescription ?? "Updated from Apple Health."
            }
        }

        store.execute(query)
    }
}

enum HealthAuthorizationState {
    case notRequested
    case authorized
    case denied
    case unavailable
}

struct TodayView: View {
    @ObservedObject var model: FitSightModel
    @ObservedObject var healthStore: HealthEnergyStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TodaySummaryCard(model: model)
                    HealthConnectionCard(healthStore: healthStore)
                    GoalControls(model: model)
                    RecommendationPreview(recommendation: model.recommendations.first)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FitSight")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        healthStore.refreshToday()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh active energy")
                }
            }
        }
    }
}

struct TodaySummaryCard: View {
    @ObservedObject var model: FitSightModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily calorie goal")
                        .font(.headline)
                    Text("\(Int(model.activeEnergy)) / \(Int(model.dailyCalorieGoal)) kcal")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.16), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: model.activeEnergyProgress)
                        .stroke(.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(model.activeEnergyProgress * 100))%")
                        .font(.headline)
                }
                .frame(width: 96, height: 96)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Active energy progress")
                .accessibilityValue("\(Int(model.activeEnergyProgress * 100)) percent")
            }

            HStack(spacing: 12) {
                MetricTile(title: "Remaining", value: "\(Int(model.remainingCalories))", unit: "kcal")
                MetricTile(title: "Plan", value: "\(Int(model.workoutMinutes))", unit: "min")
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title2.bold())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct HealthConnectionCard: View {
    @ObservedObject var healthStore: HealthEnergyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Health Active Energy", systemImage: "heart.text.square")
                .font(.headline)

            Text(healthStore.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    healthStore.requestAuthorization()
                } label: {
                    Label("Connect", systemImage: "heart")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    healthStore.refreshToday()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct GoalControls: View {
    @ObservedObject var model: FitSightModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Goal setup")
                .font(.headline)

            Picker("Goal", selection: $model.goal) {
                ForEach(FitnessGoal.allCases) { goal in
                    Text(goal.rawValue).tag(goal)
                }
            }
            .pickerStyle(.segmented)

            Picker("Focus", selection: $model.focus) {
                ForEach(WorkoutFocus.allCases) { focus in
                    Text(focus.rawValue).tag(focus)
                }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Daily active calories")
                    Spacer()
                    Text("\(Int(model.dailyCalorieGoal)) kcal")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.dailyCalorieGoal, in: 250...1200, step: 25)
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Workout time")
                    Spacer()
                    Text("\(Int(model.workoutMinutes)) min")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.workoutMinutes, in: 10...60, step: 5)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct RecommendationPreview: View {
    let recommendation: WorkoutRecommendation?

    var body: some View {
        if let recommendation {
            VStack(alignment: .leading, spacing: 12) {
                Label("Recommended now", systemImage: "sparkles")
                    .font(.headline)
                WorkoutCard(recommendation: recommendation)
            }
        }
    }
}

struct CoachView: View {
    @ObservedObject var model: FitSightModel

    var body: some View {
        NavigationStack {
            List {
                Section("Recommended workouts") {
                    ForEach(model.recommendations) { recommendation in
                        WorkoutCard(recommendation: recommendation)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                Section("More features") {
                    FeatureRow(
                        title: "Adaptive planning",
                        subtitle: "Recommendations change from HealthKit progress, time, and goal focus.",
                        symbolName: "slider.horizontal.3"
                    )
                    FeatureRow(
                        title: "Rep and form history",
                        subtitle: "The data model is ready for camera-session summaries.",
                        symbolName: "list.clipboard"
                    )
                    FeatureRow(
                        title: "Apple Watch path",
                        subtitle: "Future watchOS companion can contribute live heart-rate and workout data.",
                        symbolName: "applewatch"
                    )
                }
            }
            .navigationTitle("Coach")
        }
    }
}

struct WorkoutCard: View {
    let recommendation: WorkoutRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: recommendation.symbolName)
                    .font(.title2)
                    .frame(width: 38, height: 38)
                    .background(.mint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                    Text(recommendation.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label("\(recommendation.minutes) min", systemImage: "clock")
                Label("\(recommendation.calories) kcal", systemImage: "flame")
                Label(recommendation.intensity, systemImage: "gauge.with.dots.needle.50percent")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            ForEach(recommendation.steps, id: \.self) { step in
                Label(step, systemImage: "checkmark.circle")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FormCoachView: View {
    @StateObject private var cameraCoach = CameraFormCoach()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CameraPreview(session: cameraCoach.session)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cameraCoach.currentExercise.rawValue)
                                .font(.headline)
                            Text(cameraCoach.feedback)
                                .font(.subheadline)
                        }
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                    }
                    .overlay {
                        if cameraCoach.permission != .authorized {
                            CameraPermissionOverlay(cameraCoach: cameraCoach)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .background(Color.black)

                VStack(alignment: .leading, spacing: 16) {
                    Picker("Exercise", selection: $cameraCoach.currentExercise) {
                        ForEach(TrackedExercise.allCases) { exercise in
                            Text(exercise.rawValue).tag(exercise)
                        }
                    }
                    .pickerStyle(.segmented)

                    FormSignalGrid(cameraCoach: cameraCoach)

                    Text("FitSight analyzes body-pose landmarks on device and gives coaching cues. It is fitness guidance, not medical diagnosis.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()

                Spacer(minLength: 0)
            }
            .navigationTitle("Form Coach")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        cameraCoach.toggleSession()
                    } label: {
                        Image(systemName: cameraCoach.isRunning ? "pause.circle" : "play.circle")
                    }
                    .accessibilityLabel(cameraCoach.isRunning ? "Pause camera" : "Start camera")
                }
            }
            .onAppear {
                cameraCoach.requestAccessIfNeeded()
            }
            .onDisappear {
                cameraCoach.stopSession()
            }
        }
    }
}

struct CameraPermissionOverlay: View {
    @ObservedObject var cameraCoach: CameraFormCoach

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text(cameraCoach.permissionMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            Button {
                cameraCoach.requestAccessIfNeeded()
            } label: {
                Label("Enable Camera", systemImage: "lock.open")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.76))
        .foregroundStyle(.white)
    }
}

struct FormSignalGrid: View {
    @ObservedObject var cameraCoach: CameraFormCoach

    var body: some View {
        HStack(spacing: 12) {
            MetricTile(title: "Rep count", value: "\(cameraCoach.repCount)", unit: "reps")
            MetricTile(title: "Pose", value: "\(cameraCoach.poseConfidencePercent)", unit: "%")
        }
    }
}

final class CameraFormCoach: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var permission: CameraPermission = .unknown
    @Published var feedback = "Position your full body in frame."
    @Published var poseConfidencePercent = 0
    @Published var repCount = 0
    @Published var isRunning = false
    @Published var currentExercise: TrackedExercise = .squat

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "fitsight.camera.session")
    private let videoQueue = DispatchQueue(label: "fitsight.camera.video")
    private var isConfigured = false
    private var wasInRepBottom = false

    var permissionMessage: String {
        switch permission {
        case .unknown:
            return "Camera access lets FitSight coach exercise form."
        case .authorized:
            return "Camera ready."
        case .denied:
            return "Camera permission is off. Enable it in Settings to use form feedback."
        case .unavailable:
            return "No camera is available on this device."
        }
    }

    func requestAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permission = granted ? .authorized : .denied
                    if granted {
                        self?.startSession()
                    }
                }
            }
        case .denied, .restricted:
            permission = .denied
        @unknown default:
            permission = .unavailable
        }
    }

    func toggleSession() {
        isRunning ? stopSession() : requestAccessIfNeeded()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async {
                self.permission = .unavailable
                self.feedback = "No usable camera was found."
            }
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        session.commitConfiguration()
        isConfigured = true
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, _ in
            guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
                DispatchQueue.main.async {
                    self?.poseConfidencePercent = 0
                    self?.feedback = "Move back until your whole body is visible."
                }
                return
            }

            self?.handlePose(observation)
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )
        try? handler.perform([request])
    }

    private func handlePose(_ observation: VNHumanBodyPoseObservation) {
        guard let points = try? observation.recognizedPoints(.all) else { return }
        let confidentPoints = points.values.filter { $0.confidence > 0.35 }
        let confidenceTotal = confidentPoints
            .map { Double($0.confidence) }
            .reduce(0, +)
        let confidenceAverage = confidentPoints.isEmpty ? 0 : confidenceTotal / Double(confidentPoints.count)
        let confidence = Int(confidenceAverage * 100)
        let cue = FormAnalyzer.feedback(for: currentExercise, points: points)

        DispatchQueue.main.async {
            self.poseConfidencePercent = confidence
            self.feedback = cue.text

            if cue.isRepBottom, !self.wasInRepBottom {
                self.wasInRepBottom = true
            } else if !cue.isRepBottom, self.wasInRepBottom {
                self.wasInRepBottom = false
                self.repCount += 1
            }
        }
    }
}

enum CameraPermission {
    case unknown
    case authorized
    case denied
    case unavailable
}

enum TrackedExercise: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case pushUp = "Push-up"
    case lunge = "Lunge"
    case plank = "Plank"

    var id: String { rawValue }
}

struct FormCue {
    let text: String
    let isRepBottom: Bool
}

enum FormAnalyzer {
    static func feedback(
        for exercise: TrackedExercise,
        points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> FormCue {
        switch exercise {
        case .squat:
            return squatCue(points)
        case .pushUp:
            return pushUpCue(points)
        case .lunge:
            return lungeCue(points)
        case .plank:
            return plankCue(points)
        }
    }

    private static func squatCue(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> FormCue {
        guard let hip = bestPoint(.leftHip, .rightHip, points: points),
              let knee = bestPoint(.leftKnee, .rightKnee, points: points),
              let ankle = bestPoint(.leftAnkle, .rightAnkle, points: points) else {
            return FormCue(text: "Show hips, knees, and ankles for squat feedback.", isRepBottom: false)
        }

        let kneeAngle = angle(a: hip.location, b: knee.location, c: ankle.location)
        if kneeAngle < 95 {
            return FormCue(text: "Good depth. Drive up with knees tracking over toes.", isRepBottom: true)
        } else if kneeAngle > 150 {
            return FormCue(text: "Stand tall, brace, then sit hips down and back.", isRepBottom: false)
        } else {
            return FormCue(text: "Keep chest proud and continue to controlled depth.", isRepBottom: false)
        }
    }

    private static func pushUpCue(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> FormCue {
        guard let shoulder = bestPoint(.leftShoulder, .rightShoulder, points: points),
              let elbow = bestPoint(.leftElbow, .rightElbow, points: points),
              let wrist = bestPoint(.leftWrist, .rightWrist, points: points),
              let hip = bestPoint(.leftHip, .rightHip, points: points) else {
            return FormCue(text: "Show shoulders, elbows, wrists, and hips for push-up feedback.", isRepBottom: false)
        }

        let elbowAngle = angle(a: shoulder.location, b: elbow.location, c: wrist.location)
        let bodySlope = abs(shoulder.location.y - hip.location.y)

        if bodySlope > 0.18 {
            return FormCue(text: "Keep shoulders, hips, and ankles in one strong line.", isRepBottom: false)
        } else if elbowAngle < 95 {
            return FormCue(text: "Good bottom position. Press the floor away.", isRepBottom: true)
        } else {
            return FormCue(text: "Lower with control and keep elbows about 45 degrees.", isRepBottom: false)
        }
    }

    private static func lungeCue(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> FormCue {
        guard let hip = bestPoint(.leftHip, .rightHip, points: points),
              let knee = bestPoint(.leftKnee, .rightKnee, points: points),
              let ankle = bestPoint(.leftAnkle, .rightAnkle, points: points) else {
            return FormCue(text: "Show the front leg for lunge feedback.", isRepBottom: false)
        }

        let kneeAngle = angle(a: hip.location, b: knee.location, c: ankle.location)
        let kneeForward = abs(knee.location.x - ankle.location.x)

        if kneeForward > 0.18 {
            return FormCue(text: "Stack front knee closer over the ankle.", isRepBottom: false)
        } else if kneeAngle < 105 {
            return FormCue(text: "Strong lunge depth. Push through the full foot.", isRepBottom: true)
        } else {
            return FormCue(text: "Lower straight down and keep your torso quiet.", isRepBottom: false)
        }
    }

    private static func plankCue(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> FormCue {
        guard let shoulder = bestPoint(.leftShoulder, .rightShoulder, points: points),
              let hip = bestPoint(.leftHip, .rightHip, points: points),
              let ankle = bestPoint(.leftAnkle, .rightAnkle, points: points) else {
            return FormCue(text: "Show shoulders, hips, and ankles for plank feedback.", isRepBottom: false)
        }

        let hipLine = abs(shoulder.location.y - hip.location.y)
        let ankleLine = abs(hip.location.y - ankle.location.y)

        if hipLine < 0.1 && ankleLine < 0.18 {
            return FormCue(text: "Solid plank line. Breathe and keep ribs down.", isRepBottom: false)
        } else if hip.location.y > shoulder.location.y + 0.14 {
            return FormCue(text: "Lower your hips slightly to make one long line.", isRepBottom: false)
        } else {
            return FormCue(text: "Lift hips slightly and brace your midline.", isRepBottom: false)
        }
    }

    private static func bestPoint(
        _ first: VNHumanBodyPoseObservation.JointName,
        _ second: VNHumanBodyPoseObservation.JointName,
        points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> VNRecognizedPoint? {
        [points[first], points[second]]
            .compactMap { $0 }
            .filter { $0.confidence > 0.25 }
            .max { $0.confidence < $1.confidence }
    }

    private static func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let magnitudes = hypot(ab.dx, ab.dy) * hypot(cb.dx, cb.dy)
        guard magnitudes > 0 else { return 180 }
        let cosine = min(max(dot / magnitudes, -1), 1)
        return acos(cosine) * 180 / Double.pi
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as? AVCaptureVideoPreviewLayer ?? AVCaptureVideoPreviewLayer()
    }
}

struct ProgressView: View {
    @ObservedObject var model: FitSightModel

    var body: some View {
        NavigationStack {
            List {
                Section("Weekly active energy") {
                    ForEach(model.weeklyEnergy) { metric in
                        HStack {
                            Text(metric.day)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 36, alignment: .leading)

                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.mint.gradient)
                                    .frame(width: max(8, proxy.size.width * metric.value / 800))
                            }
                            .frame(height: 12)

                            Text("\(Int(metric.value))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(metric.day), \(Int(metric.value)) active calories")
                    }
                }

                Section("Milestones") {
                    FeatureRow(
                        title: "Goal consistency",
                        subtitle: "Keep active energy above 80% of goal on 5 days this week.",
                        symbolName: "calendar.badge.checkmark"
                    )
                    FeatureRow(
                        title: "Form quality",
                        subtitle: "Use the camera coach for three controlled sets.",
                        symbolName: "figure.squat"
                    )
                    FeatureRow(
                        title: "Recovery",
                        subtitle: "Add one low-impact or mobility session after a hard day.",
                        symbolName: "moon.zzz"
                    )
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct ReadinessView: View {
    private let items = [
        ReadinessItem(
            title: "HealthKit purpose",
            status: .ready,
            detail: "Active energy access supports the daily calorie goal and workout recommendations."
        ),
        ReadinessItem(
            title: "Privacy policy",
            status: .needed,
            detail: "A public privacy policy URL is required before App Store submission."
        ),
        ReadinessItem(
            title: "Camera consent",
            status: .ready,
            detail: "Camera usage string explains on-device exercise form feedback."
        ),
        ReadinessItem(
            title: "Medical claims",
            status: .ready,
            detail: "Current wording keeps feedback as fitness coaching, not diagnosis or treatment."
        ),
        ReadinessItem(
            title: "Real-device QA",
            status: .needed,
            detail: "HealthKit and live camera coaching must be validated on iPhone hardware."
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("App Store readiness") {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.status.symbolName)
                                .foregroundStyle(item.status.color)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Launch checklist") {
                    FeatureRow(
                        title: "Screenshots",
                        subtitle: "Capture Today, Coach, Form Coach, and Progress screens.",
                        symbolName: "photo.on.rectangle"
                    )
                    FeatureRow(
                        title: "Support URL",
                        subtitle: "Add a lightweight support page for privacy and contact.",
                        symbolName: "questionmark.circle"
                    )
                    FeatureRow(
                        title: "Model disclosure",
                        subtitle: "Describe that pose analysis runs on device.",
                        symbolName: "cpu"
                    )
                }
            }
            .navigationTitle("Ready")
        }
    }
}

struct ReadinessItem: Identifiable {
    let title: String
    let status: ReadinessStatus
    let detail: String

    var id: String { title }
}

enum ReadinessStatus {
    case ready
    case needed

    var symbolName: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .needed:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ready:
            return .green
        case .needed:
            return .orange
        }
    }
}

struct FeatureRow: View {
    let title: String
    let subtitle: String
    let symbolName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .frame(width: 30, height: 30)
                .background(.mint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
