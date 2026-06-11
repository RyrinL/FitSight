import SwiftUI

// MARK: - Main view

struct NutritionView: View {
    @ObservedObject var appVM: AppViewModel
    @StateObject private var vm: NutritionViewModel

    @State private var showAddEntry = false

    init(appVM: AppViewModel) {
        self.appVM = appVM
        _vm = StateObject(wrappedValue: NutritionViewModel(db: appVM.db))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    NutritionSummaryCard(
                        calories:    vm.totalCaloriesToday,
                        calorieGoal: appVM.profile?.recommendedDailyCalories ?? 2000,
                        proteinG:    vm.totalProteinG,
                        carbsG:      vm.totalCarbsG,
                        fatG:        vm.totalFatG,
                        targets:     appVM.profile?.macroTargets
                    )

                    waterCard
                    mealSections
                    dailySummaryCard
                    addButton
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        FitHaptic.impact(.light)
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.mint)
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                AddNutritionEntryView(vm: vm, uid: appVM.currentUser?.uid ?? "")
            }
            .task {
                guard let uid = appVM.currentUser?.uid else { return }
                vm.macroTargets = appVM.profile?.macroTargets
                vm.waterGoalMl  = 2000
                await vm.loadToday(uid: uid)
            }
            .onChange(of: appVM.profile?.fitnessGoal.rawValue) { _ in
                vm.macroTargets = appVM.profile?.macroTargets
            }
        }
    }

    // MARK: - Water card

    @State private var customWaterText = ""
    @State private var showCustomWater = false

    private var waterCard: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.fitBlue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hydration")
                            .font(.fitHeadline())
                        Text("\(Int(vm.waterEntriesML)) / \(Int(vm.waterGoalMl)) ml  ·  \(vm.waterCups) cups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(Int(vm.waterProgressFraction * 100))%")
                    .font(.fitMono(18))
                    .foregroundStyle(vm.waterProgressFraction >= 1 ? Color.fitBlue : Color.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.secondary.opacity(0.1))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(FitGradient.steps)
                        .frame(width: geo.size.width * min(vm.waterProgressFraction, 1), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: vm.waterProgressFraction)
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                ForEach([150.0, 250.0, 330.0, 500.0], id: \.self) { ml in
                    Button {
                        FitHaptic.impact(.light)
                        Task { await vm.logWater(ml: ml, uid: appVM.currentUser?.uid ?? "") }
                    } label: {
                        Text("+\(Int(ml))ml")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(FitGradient.steps)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    FitHaptic.impact(.light)
                    showCustomWater.toggle()
                } label: {
                    Text("Custom")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if vm.waterEntriesML > 0 {
                    Button {
                        FitHaptic.warning()
                        Task { await vm.resetWater(uid: appVM.currentUser?.uid ?? "") }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showCustomWater {
                HStack(spacing: 10) {
                    TextField("Amount (ml)", text: $customWaterText)
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        if let ml = Double(customWaterText), ml > 0 {
                            FitHaptic.impact(.medium)
                            Task { await vm.logWater(ml: ml, uid: appVM.currentUser?.uid ?? "") }
                            customWaterText = ""
                            showCustomWater = false
                        }
                    } label: {
                        Text("Add")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.fitBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(Double(customWaterText) == nil)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassCard(tint: .fitBlue)
        .animation(.easeInOut(duration: 0.2), value: showCustomWater)
    }

    // MARK: - Meal sections

    private var mealSections: some View {
        ForEach(MealType.allCases) { meal in
            let entries = vm.todayEntries.filter { $0.mealType == meal }
            if !entries.isEmpty {
                mealSection(meal: meal, entries: entries)
            }
        }
    }

    private func mealSection(meal: MealType, entries: [NutritionEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: meal.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.mint)
                Text(meal.rawValue)
                    .font(.fitHeadline())
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    let totalCal = entries.reduce(0) { $0 + $1.calories }
                    Text("\(Int(totalCal)) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    let p = entries.reduce(0) { $0 + $1.proteinG }
                    let c = entries.reduce(0) { $0 + $1.carbsG }
                    let f = entries.reduce(0) { $0 + $1.fatG }
                    Text("P\(Int(p))  C\(Int(c))  F\(Int(f))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    if i > 0 { Divider().padding(.vertical, 8) }
                    NutritionRow(entry: entry) {
                        Task { await vm.removeEntry(entry, uid: appVM.currentUser?.uid ?? "") }
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Daily summary card

    private var dailySummaryCard: some View {
        let calorieGoal = appVM.profile?.recommendedDailyCalories ?? 2000
        let remaining   = max(calorieGoal - vm.totalCaloriesToday, 0)
        let overBy      = max(vm.totalCaloriesToday - calorieGoal, 0)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Daily Summary")
                .font(.fitHeadline())

            HStack(spacing: 12) {
                summaryChip(
                    icon: "flame.fill", color: .fitOrange,
                    value: "\(Int(vm.totalCaloriesToday))",
                    label: "Eaten"
                )
                summaryChip(
                    icon: overBy > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    color: overBy > 0 ? .fitRed : .mint,
                    value: overBy > 0 ? "+\(Int(overBy))" : "\(Int(remaining))",
                    label: overBy > 0 ? "Over" : "Left"
                )
                summaryChip(
                    icon: "drop.fill", color: .fitBlue,
                    value: "\(Int(vm.waterProgressFraction * 100))%",
                    label: "Hydrated"
                )
            }

            if let targets = appVM.profile?.macroTargets {
                VStack(spacing: 8) {
                    macroGoalBar("Protein", value: vm.totalProteinG, goal: targets.proteinG, color: .fitBlue)
                    macroGoalBar("Carbs",   value: vm.totalCarbsG,   goal: targets.carbsG,   color: .fitOrange)
                    macroGoalBar("Fat",     value: vm.totalFatG,     goal: targets.fatG,     color: .fitPurple)
                }
            }
        }
        .glassCard()
    }

    private func summaryChip(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func macroGoalBar(_ label: String, value: Double, goal: Double, color: Color) -> some View {
        let progress = goal > 0 ? min(value / goal, 1.0) : 0
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(Int(value))/\(Int(goal))g")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            FitHaptic.impact(.light)
            showAddEntry = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add food entry")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FitGradient.mint)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fitShadow(color: .mint, radius: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nutrition row

private struct NutritionRow: View {
    let entry: NutritionEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text("P \(Int(entry.proteinG))g  ·  C \(Int(entry.carbsG))g  ·  F \(Int(entry.fatG))g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let serving = entry.servingLabel {
                        Text("·  \(serving)")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.fitRed.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Add entry sheet

struct AddNutritionEntryView: View {
    @ObservedObject var vm: NutritionViewModel
    let uid: String
    @Environment(\.dismiss) private var dismiss

    // Search
    @State private var searchText    = ""
    @State private var selectedPreset: FoodPreset?
    @State private var scannedFood:  ScannedFood?
    @FocusState private var searchFocused: Bool

    // Entry fields
    @State private var foodName  = ""
    @State private var servingG: Double = 100
    @State private var servingText = "100"   // mirrors servingG as a string for editing
    @State private var meal: MealType = .lunch

    // Barcode
    @State private var showScanner     = false
    @State private var isLoadingFood   = false

    // Manual override macros (nil = use preset-derived values)
    @State private var manualCalories = ""
    @State private var manualProtein  = ""
    @State private var manualCarbs    = ""
    @State private var manualFat      = ""
    @State private var showManual     = false

    // MARK: - Derived nutrition

    private var baseCalories100g: Double {
        if showManual { return Double(manualCalories) ?? 0 }
        if let s = scannedFood { return s.calories100g }
        return selectedPreset?.calories100g ?? 0
    }
    private var baseProtein100g: Double {
        if showManual { return Double(manualProtein) ?? 0 }
        if let s = scannedFood { return s.protein100g }
        return selectedPreset?.protein100g ?? 0
    }
    private var baseCarbs100g: Double {
        if showManual { return Double(manualCarbs) ?? 0 }
        if let s = scannedFood { return s.carbs100g }
        return selectedPreset?.carbs100g ?? 0
    }
    private var baseFat100g: Double {
        if showManual { return Double(manualFat) ?? 0 }
        if let s = scannedFood { return s.fat100g }
        return selectedPreset?.fat100g ?? 0
    }

    private var displayCalories: Int { Int((baseCalories100g * servingG / 100).rounded()) }
    private var displayProtein:  Double { (baseProtein100g  * servingG / 100).rounded(to: 1) }
    private var displayCarbs:    Double { (baseCarbs100g    * servingG / 100).rounded(to: 1) }
    private var displayFat:      Double { (baseFat100g      * servingG / 100).rounded(to: 1) }

    private var effectiveFoodName: String { foodName.isEmpty ? (scannedFood?.name ?? selectedPreset?.name ?? "") : foodName }
    private var hasValidEntry: Bool { !effectiveFoodName.isEmpty && displayCalories > 0 }
    private var hasSource: Bool { selectedPreset != nil || scannedFood != nil || showManual }

    // MARK: - Search results

    private var searchResults: [FoodPreset] {
        guard !searchText.isEmpty else { return [] }
        return Array(FoodDatabase.search(searchText).prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    searchSection
                        .padding(.horizontal)
                        .padding(.top, 12)

                    if !searchResults.isEmpty && selectedPreset == nil && scannedFood == nil {
                        searchResultsList
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    if hasSource {
                        entryDetailsSection
                            .padding(.horizontal)
                            .padding(.top, 12)
                    } else if !showManual && searchText.isEmpty {
                        quickCategoriesSection
                            .padding(.top, 8)
                    }

                    if !hasSource || showManual {
                        manualEntrySection
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            searchFocused = false
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.mint)
                        }
                        Button("Add") { addEntry() }
                            .font(.body.weight(.semibold))
                            .disabled(!hasValidEntry)
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { food in
                    scannedFood    = food
                    selectedPreset = nil
                    foodName       = ""
                    servingG       = 100
                    servingText    = "100"
                    showManual     = false
                    searchText     = ""
                }
            }
        }
    }

    // MARK: - Search bar

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search foods…", text: $searchText)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _ in
                    if !searchText.isEmpty {
                        selectedPreset = nil
                        scannedFood    = nil
                        showManual     = false
                    }
                }
            if !searchText.isEmpty {
                Button { searchText = ""; selectedPreset = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Search results

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { i, preset in
                if i > 0 { Divider().padding(.leading, 12) }
                Button {
                    FitHaptic.impact(.light)
                    selectedPreset = preset
                    scannedFood    = nil
                    servingG       = preset.defaultServingG
                    servingText    = servingG.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(servingG))" : String(format: "%.1f", servingG)
                    showManual     = false
                    searchFocused  = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(Int(preset.calories100g)) kcal / 100\(preset.servingUnit) · P\(Int(preset.protein100g))  C\(Int(preset.carbs100g))  F\(Int(preset.fat100g))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick categories

    private var quickCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BROWSE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FoodCategory.allCases, id: \.rawValue) { cat in
                        Button {
                            FitHaptic.impact(.light)
                            searchText    = cat.rawValue
                            searchFocused = false
                        } label: {
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Entry details (after food selected)

    private var entryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Food name header
            VStack(alignment: .leading, spacing: 4) {
                if let preset = selectedPreset {
                    Text(preset.name)
                        .font(.title3.weight(.bold))
                    Text(preset.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let food = scannedFood {
                    HStack(spacing: 6) {
                        Image(systemName: "barcode")
                            .foregroundStyle(.mint)
                            .font(.caption)
                        Text(food.name)
                            .font(.title3.weight(.bold))
                    }
                }
            }

            // Serving size
            VStack(alignment: .leading, spacing: 8) {
                Text("SERVING SIZE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button {
                            servingG = max(servingG - 10, 5)
                            servingText = servingG.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(servingG))" : String(format: "%.1f", servingG)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)

                        TextField("g", text: $servingText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .frame(width: 70)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: servingText) { val in
                                if let g = Double(val), g > 0 { servingG = g }
                            }

                        Text(selectedPreset?.servingUnit ?? (scannedFood != nil ? "g" : "g"))
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Button {
                            servingG = min(servingG + 10, 2000)
                            servingText = servingG.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(servingG))" : String(format: "%.1f", servingG)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.mint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Nutrition preview
            HStack(spacing: 0) {
                nutrientPill(value: "\(displayCalories)", label: "kcal", color: .fitOrange)
                Divider().frame(height: 40).padding(.horizontal, 8)
                nutrientPill(value: "\(Int(displayProtein))g", label: "Protein", color: .fitBlue)
                Divider().frame(height: 40).padding(.horizontal, 8)
                nutrientPill(value: "\(Int(displayCarbs))g", label: "Carbs", color: .fitOrange)
                Divider().frame(height: 40).padding(.horizontal, 8)
                nutrientPill(value: "\(Int(displayFat))g", label: "Fat", color: .fitPurple)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Custom name (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("CUSTOM LABEL (optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                TextField("Leave blank to use food name", text: $foodName)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Meal picker
            VStack(alignment: .leading, spacing: 6) {
                Text("MEAL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                HStack(spacing: 8) {
                    ForEach(MealType.allCases) { m in
                        Button {
                            FitHaptic.impact(.light)
                            meal = m
                        } label: {
                            Text(m.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(meal == m ? FitGradient.mint : LinearGradient(colors: [Color(.tertiarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom))
                                .foregroundStyle(meal == m ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func nutrientPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Manual entry section

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showManual.toggle() }
            } label: {
                HStack {
                    Text(showManual ? "Manual entry" : "Enter manually instead")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.mint)
                    Spacer()
                    Image(systemName: showManual ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.mint)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if showManual {
                VStack(spacing: 10) {
                    manualField("Food name", text: $foodName, keyboard: .default)
                    manualField("Calories (kcal)", text: $manualCalories, keyboard: .decimalPad)
                    manualField("Protein (g)",     text: $manualProtein,  keyboard: .decimalPad)
                    manualField("Carbs (g)",        text: $manualCarbs,   keyboard: .decimalPad)
                    manualField("Fat (g)",          text: $manualFat,     keyboard: .decimalPad)

                    // Meal picker
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases) { m in
                            Button {
                                FitHaptic.impact(.light)
                                meal = m
                            } label: {
                                Text(m.rawValue)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(meal == m ? FitGradient.mint : LinearGradient(colors: [Color(.tertiarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom))
                                    .foregroundStyle(meal == m ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func manualField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Add entry action

    private func addEntry() {
        let name = effectiveFoodName
        guard !name.isEmpty else { return }

        let entry: NutritionEntry
        if showManual {
            entry = NutritionEntry.new(
                userId: uid, foodName: name,
                calories: Double(manualCalories) ?? 0,
                protein:  Double(manualProtein)  ?? 0,
                carbs:    Double(manualCarbs)    ?? 0,
                fat:      Double(manualFat)      ?? 0,
                meal:     meal
            )
        } else if let preset = selectedPreset {
            entry = preset.entry(userId: uid, meal: meal, servingG: servingG)
        } else if let food = scannedFood {
            let m = servingG / 100.0
            entry = NutritionEntry.new(
                userId: uid, foodName: food.name,
                calories: (food.calories100g * m).rounded(),
                protein:  (food.protein100g  * m),
                carbs:    (food.carbs100g    * m),
                fat:      (food.fat100g      * m),
                meal:     meal,
                servingSize: servingG, servingUnit: "g"
            )
        } else {
            return
        }

        FitHaptic.impact(.medium)
        Task {
            await vm.addEntry(entry)
            dismiss()
        }
    }
}

// MARK: - Double rounding helper (local)

private extension Double {
    func rounded(to places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
