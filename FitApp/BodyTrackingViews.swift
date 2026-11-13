// BodyTrackingViews.swift
// Weight tracking (gain / loss over time) and body measurements (wrist, arm, waist, ...).
// Reached from Settings -> Body Tracking and from the Profile tab.
// All data lives in AppState (weightLog, bodyMeasurements); these views only display it and call
// AppState methods.

import SwiftUI
import Charts
import Combine  // explicit import

// MARK: - Formatting

enum BodyFormat {
    /// "+1.2", "−0.8" or "0". Uses a real minus sign so the numbers line up.
    static func signed(_ value: Double) -> String {
        let rounded = NumberParsing.roundedToTenth(value)
        if rounded == 0 { return "0" }
        let text = NumberParsing.display(abs(rounded))
        return rounded > 0 ? "+\(text)" : "−\(text)"
    }
}

// MARK: - Settings section

/// "Body Tracking" section for the Settings form.
struct BodyTrackingSettingsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Section {
            NavigationLink {
                WeightTrackerView()
            } label: {
                HStack {
                    Label("Weight", systemImage: "scalemass")
                    Spacer()
                    Text("\(NumberParsing.display(appState.currentWeightKg)) kg")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("settings_current_weight_value")
                }
            }
            .accessibilityIdentifier("weight_tracker_link")

            NavigationLink {
                MeasurementsView()
            } label: {
                HStack {
                    Label("Body Measurements", systemImage: "ruler")
                    Spacer()
                    Text(measurementSummary)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("settings_measurements_value")
                }
            }
            .accessibilityIdentifier("measurements_link")
        } header: {
            Text("Body Tracking")
        } footer: {
            Text("Track your weight and measurements such as wrist, arm or waist over time. They are stored on this device (and in your Google backup if you turn it on).")
        }
    }

    private var measurementSummary: String {
        let tracked = BodyMeasurementType.allCases.filter { appState.latestMeasurement(for: $0) != nil }.count
        return tracked == 0 ? "Not started" : "\(tracked) tracked"
    }
}

// MARK: - Weight

struct WeightTrackerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogSheet: Bool = false

    private var entriesNewestFirst: [WeightEntry] {
        appState.weightLog.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                summaryContent
            }
            Section("Trend") {
                trendContent
            }
            Section("History") {
                historyContent
            }
        }
        .navigationTitle("Weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLogSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log weight")
                .accessibilityIdentifier("add_weight_button")
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogWeightSheet()
        }
        .accessibilityIdentifier("weight_tracker_view")
    }

    // MARK: Summary

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(NumberParsing.display(appState.currentWeightKg))
                    .font(.system(size: 44, weight: .bold))
                    .accessibilityIdentifier("weight_current_label")
                Text("kg")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let total = appState.totalWeightChangeKg, let start = appState.weightLog.first {
                changeRow(title: "Since \(start.date.formatted(date: .abbreviated, time: .omitted))",
                          delta: total, id: "weight_total_change_label")
            } else {
                Text("Log your weight regularly to see how much you gained or lost.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("weight_empty_hint")
            }
            if let month = appState.weightChangeKg(overDays: 30) {
                changeRow(title: "Last 30 days", delta: month, id: "weight_30d_change_label")
            }
            if let week = appState.weightChangeKg(overDays: 7) {
                changeRow(title: "Last 7 days", delta: week, id: "weight_7d_change_label")
            }
        }
        .padding(.vertical, 4)
    }

    private func changeRow(title: String, delta: Double, id: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(BodyFormat.signed(delta)) kg")
                .font(.subheadline.bold())
                .foregroundColor(changeColor(delta))
                .accessibilityIdentifier(id)
        }
    }

    /// Green when the change matches the user's goal, orange when it goes the other way.
    private func changeColor(_ delta: Double) -> Color {
        if abs(delta) < 0.05 { return .secondary }
        switch appState.profile.goal {
        case .loseWeight:
            return delta < 0 ? .green : .orange
        case .gainMuscle:
            return delta > 0 ? .green : .orange
        case .maintain, .performance:
            return abs(delta) <= 1 ? .green : .orange
        }
    }

    // MARK: Trend

    @ViewBuilder
    private var trendContent: some View {
        if appState.weightLog.count >= 2 {
            Chart(appState.weightLog) { entry in
                LineMark(x: .value("Date", entry.date),
                         y: .value("Weight (kg)", entry.kg))
                    .foregroundStyle(Color.blue)
                PointMark(x: .value("Date", entry.date),
                          y: .value("Weight (kg)", entry.kg))
                    .foregroundStyle(Color.blue)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 200)
            .padding(.vertical, 8)
            .accessibilityIdentifier("weight_chart")
        } else {
            Text("Add at least two weigh-ins to see your trend.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("weight_chart_hint")
        }
    }

    // MARK: History

    @ViewBuilder
    private var historyContent: some View {
        if appState.weightLog.isEmpty {
            Text("No weigh-ins yet. Tap + to add your first one.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("weight_history_empty")
        } else {
            ForEach(Array(entriesNewestFirst.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text(entry.date, style: .date)
                        .font(.subheadline)
                    Spacer()
                    if let delta = deltaFromPrevious(at: index) {
                        Text(BodyFormat.signed(delta))
                            .font(.caption)
                            .foregroundColor(changeColor(delta))
                    }
                    Text("\(NumberParsing.display(entry.kg)) kg")
                        .font(.subheadline.bold())
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("weight_row_\(index)")
            }
            .onDelete { offsets in
                let list = entriesNewestFirst
                for offset in offsets where list.indices.contains(offset) {
                    appState.deleteWeight(id: list[offset].id)
                }
            }
        }
    }

    /// Change versus the next older weigh-in (the list is newest first).
    private func deltaFromPrevious(at index: Int) -> Double? {
        let list = entriesNewestFirst
        guard index + 1 < list.count else { return nil }
        return NumberParsing.roundedToTenth(list[index].kg - list[index + 1].kg)
    }
}

// MARK: - Log weight sheet

struct LogWeightSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("log_weight_field")
                    }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("log_weight_date_picker")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if !weightText.isEmpty && parsedWeight == nil {
                            Text("Enter a weight between \(Int(ProfileLimits.weightKg.lowerBound)) and \(Int(ProfileLimits.weightKg.upperBound)) kg.")
                                .foregroundColor(.red)
                                .accessibilityIdentifier("log_weight_validation_hint")
                        }
                        Text("One entry per day: logging again on the same day replaces it. Weigh yourself under similar conditions (for example in the morning) so changes are comparable.")
                    }
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(parsedWeight == nil)
                        .accessibilityIdentifier("save_weight_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_weight_button")
                }
            }
        }
        .onAppear {
            if weightText.isEmpty {
                weightText = NumberParsing.display(appState.currentWeightKg)
            }
        }
        .accessibilityIdentifier("log_weight_sheet")
    }

    private var parsedWeight: Double? {
        guard let w = NumberParsing.double(from: weightText), ProfileLimits.weightKg.contains(w) else { return nil }
        return w
    }

    private func save() {
        guard let w = parsedWeight else { return }
        if appState.logWeight(kg: w, date: date) {
            dismiss()
        }
    }
}

// MARK: - Measurements list

struct MeasurementsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogSheet: Bool = false

    var body: some View {
        List {
            Section {
                ForEach(BodyMeasurementType.allCases) { type in
                    NavigationLink {
                        MeasurementDetailView(type: type)
                    } label: {
                        row(for: type)
                    }
                    .accessibilityIdentifier("measurement_row_\(type.rawValue)")
                }
            } footer: {
                Text("Measure with a soft tape at the same place and time of day. Tap a measurement to see its history and chart. Values are in centimetres.")
            }
        }
        .navigationTitle("Body Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLogSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add measurement")
                .accessibilityIdentifier("add_measurement_button")
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogMeasurementSheet(initialType: .arm)
        }
        .accessibilityIdentifier("measurements_view")
    }

    private func row(for type: BodyMeasurementType) -> some View {
        HStack {
            Text(type.title)
            Spacer()
            if let latest = appState.latestMeasurement(for: type) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(NumberParsing.display(latest.cm)) cm")
                        .font(.subheadline.bold())
                    if let change = appState.measurementChangeCm(for: type), change != 0 {
                        Text("\(BodyFormat.signed(change)) cm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("—")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Measurement detail

struct MeasurementDetailView: View {
    let type: BodyMeasurementType

    @EnvironmentObject var appState: AppState
    @State private var showLogSheet: Bool = false

    init(type: BodyMeasurementType) {
        self.type = type
    }

    private var entriesNewestFirst: [BodyMeasurement] {
        appState.measurements(for: type).sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                summaryContent
            } footer: {
                Text(type.hint)
            }
            Section("Trend") {
                trendContent
            }
            Section("History") {
                historyContent
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLogSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add \(type.title) measurement")
                .accessibilityIdentifier("add_measurement_entry_button")
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogMeasurementSheet(initialType: type)
        }
        .accessibilityIdentifier("measurement_detail_\(type.rawValue)")
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let latest = appState.latestMeasurement(for: type) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(NumberParsing.display(latest.cm))
                        .font(.system(size: 40, weight: .bold))
                        .accessibilityIdentifier("measurement_current_label")
                    Text("cm")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                if let change = appState.measurementChangeCm(for: type), let first = appState.measurements(for: type).first {
                    HStack {
                        Text("Since \(first.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(BodyFormat.signed(change)) cm")
                            .font(.subheadline.bold())
                            .accessibilityIdentifier("measurement_change_label")
                    }
                }
            } else {
                Text("No measurements yet. Tap + to add your first one.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("measurement_empty_hint")
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var trendContent: some View {
        let list = appState.measurements(for: type)
        if list.count >= 2 {
            Chart(list) { entry in
                LineMark(x: .value("Date", entry.date),
                         y: .value("Centimetres", entry.cm))
                    .foregroundStyle(Color.orange)
                PointMark(x: .value("Date", entry.date),
                          y: .value("Centimetres", entry.cm))
                    .foregroundStyle(Color.orange)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 200)
            .padding(.vertical, 8)
            .accessibilityIdentifier("measurement_chart")
        } else {
            Text("Add at least two measurements to see your trend.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("measurement_chart_hint")
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if entriesNewestFirst.isEmpty {
            Text("Nothing logged yet.")
                .font(.footnote)
                .foregroundColor(.secondary)
        } else {
            ForEach(Array(entriesNewestFirst.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text(entry.date, style: .date)
                        .font(.subheadline)
                    Spacer()
                    if let delta = deltaFromPrevious(at: index) {
                        Text(BodyFormat.signed(delta))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(NumberParsing.display(entry.cm)) cm")
                        .font(.subheadline.bold())
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("measurement_entry_row_\(index)")
            }
            .onDelete { offsets in
                let list = entriesNewestFirst
                for offset in offsets where list.indices.contains(offset) {
                    appState.deleteMeasurement(id: list[offset].id)
                }
            }
        }
    }

    private func deltaFromPrevious(at index: Int) -> Double? {
        let list = entriesNewestFirst
        guard index + 1 < list.count else { return nil }
        return NumberParsing.roundedToTenth(list[index].cm - list[index + 1].cm)
    }
}

// MARK: - Log measurement sheet

struct LogMeasurementSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var type: BodyMeasurementType
    @State private var valueText: String = ""
    @State private var date: Date = Date()

    init(initialType: BodyMeasurementType) {
        _type = State(initialValue: initialType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Measurement", selection: $type) {
                        ForEach(BodyMeasurementType.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .accessibilityIdentifier("log_measurement_type_picker")

                    HStack {
                        Text("Size (cm)")
                        Spacer()
                        TextField("0", text: $valueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("log_measurement_field")
                    }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("log_measurement_date_picker")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if !valueText.isEmpty && parsedValue == nil {
                            Text("Enter a size between \(Int(MeasurementLimits.cm.lowerBound)) and \(Int(MeasurementLimits.cm.upperBound)) cm.")
                                .foregroundColor(.red)
                                .accessibilityIdentifier("log_measurement_validation_hint")
                        }
                        Text(type.hint)
                        Text("One entry per measurement per day: logging again on the same day replaces it.")
                    }
                }
            }
            .navigationTitle("Add Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(parsedValue == nil)
                        .accessibilityIdentifier("save_measurement_button")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel_measurement_button")
                }
            }
        }
        .onAppear { prefill() }
        .onChange(of: type) { _, _ in prefill() }
        .accessibilityIdentifier("log_measurement_sheet")
    }

    private var parsedValue: Double? {
        guard let v = NumberParsing.double(from: valueText), MeasurementLimits.cm.contains(v) else { return nil }
        return v
    }

    /// Starts from the latest value of the chosen measurement, which is usually close to the new one.
    private func prefill() {
        if let latest = appState.latestMeasurement(for: type) {
            valueText = NumberParsing.display(latest.cm)
        } else {
            valueText = ""
        }
    }

    private func save() {
        guard let v = parsedValue else { return }
        if appState.logMeasurement(type, cm: v, date: date) {
            dismiss()
        }
    }
}
