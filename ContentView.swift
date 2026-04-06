//
//  ContentView.swift
//  MedAlert
//
//  Created by Kaleb Rodriguez on 3/29/26.
//

import SwiftUI
import SwiftData

// MARK: - Main Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var showingAdd = false
    @State private var searchText = ""

    var filtered: [Medication] {
        searchText.isEmpty ? medications : medications.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if medications.isEmpty {
                    emptyState
                } else {
                    medicationList
                }
            }
            .navigationTitle("MedAlert")
            .searchable(text: $searchText, prompt: "Search medications")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddMedicationView()
            }
        }
    }

    private var medicationList: some View {
        List {
            let active = filtered.filter { $0.isActive }
            let inactive = filtered.filter { !$0.isActive }
            if !active.isEmpty {
                Section("Active") {
                    ForEach(active) { med in
                        NavigationLink { MedicationDetailView(medication: med) } label: {
                            MedRow(medication: med)
                        }
                    }
                    .onDelete { idx in delete(from: active, at: idx) }
                }
            }
            if !inactive.isEmpty {
                Section("Inactive") {
                    ForEach(inactive) { med in
                        NavigationLink { MedicationDetailView(medication: med) } label: {
                            MedRow(medication: med)
                        }
                    }
                    .onDelete { idx in delete(from: inactive, at: idx) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("No Medications")
                .font(.title2.bold())
            Text("Tap + to add your first medication and set up reminders.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Add Medication") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func delete(from source: [Medication], at offsets: IndexSet) {
        for i in offsets {
            NotificationManager.shared.cancel(for: source[i])
            modelContext.delete(source[i])
        }
    }
}

// MARK: - Medication Row

struct MedRow: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(medication.colorName.medColor)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name).font(.headline)
                Text(medication.dosage).font(.subheadline).foregroundStyle(.secondary)
                if let next = medication.nextScheduledTime {
                    Label(
                        "Next: \(next.formatted(date: .omitted, time: .shortened))",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(medication.isDueNow ? .red : .secondary)
                }
            }
            Spacer()
            if medication.isDueNow {
                Text("Due Now")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red, in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .opacity(medication.isActive ? 1.0 : 0.5)
    }
}

// MARK: - Add / Edit Medication View

struct AddMedicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var editing: Medication? = nil

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency: FrequencyType = .daily
    @State private var times: [Date] = [Date()]
    @State private var notes = ""
    @State private var isActive = true
    @State private var colorName = "blue"

    let colors = ["blue", "red", "green", "purple", "orange", "pink", "teal", "yellow"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication Info") {
                    TextField("Name (e.g. Aspirin)", text: $name)
                    TextField("Dosage (e.g. 100mg)", text: $dosage)
                }
                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(FrequencyType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    if frequency != .asNeeded {
                        ForEach(times.indices, id: \.self) { i in
                            DatePicker(
                                "Time \(i + 1)",
                                selection: $times[i],
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }
                Section("Color Label") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(colors, id: \.self) { c in
                                Circle()
                                    .fill(c.medColor)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if colorName == c {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .font(.caption.bold())
                                        }
                                    }
                                    .onTapGesture { colorName = c }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if editing != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Medication" : "Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExisting() }
            .onChange(of: frequency) { _, _ in syncTimes() }
        }
    }

    private func syncTimes() {
        let target = frequency.timesPerDay
        if target == 0 { return }
        while times.count < target { times.append(Date()) }
        times = Array(times.prefix(target))
    }

    private func loadExisting() {
        guard let m = editing else { return }
        name = m.name
        dosage = m.dosage
        frequency = m.frequency
        times = m.scheduledTimes.isEmpty ? [Date()] : m.scheduledTimes
        notes = m.notes
        isActive = m.isActive
        colorName = m.colorName
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let finalTimes = frequency == .asNeeded ? [] : Array(times.prefix(max(1, frequency.timesPerDay)))
        if let m = editing {
            NotificationManager.shared.cancel(for: m)
            m.name = n
            m.dosage = dosage
            m.frequency = frequency
            m.scheduledTimes = finalTimes
            m.notes = notes
            m.isActive = isActive
            m.colorName = colorName
            if isActive { NotificationManager.shared.schedule(for: m) }
        } else {
            let m = Medication(
                name: n, dosage: dosage, frequency: frequency,
                scheduledTimes: finalTimes, notes: notes, colorName: colorName
            )
            modelContext.insert(m)
            NotificationManager.shared.schedule(for: m)
        }
        dismiss()
    }
}

// MARK: - Medication Detail View

struct MedicationDetailView: View {
    @State private var showingEdit = false
    @State private var showTakenAlert = false
    var medication: Medication

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(medication.colorName.medColor)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "pill.fill")
                                .foregroundStyle(.white)
                                .font(.title3)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(medication.name).font(.title2.bold())
                        Text(medication.dosage).foregroundStyle(.secondary)
                        Text(medication.frequency.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(medication.isActive ? "Active" : "Inactive")
                        .font(.caption.bold())
                        .foregroundStyle(medication.isActive ? .green : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (medication.isActive ? Color.green : Color.secondary).opacity(0.15),
                            in: Capsule()
                        )
                }
                .padding(.vertical, 4)
            }

            if !medication.scheduledTimes.isEmpty && medication.frequency != .asNeeded {
                Section("Schedule") {
                    ForEach(medication.scheduledTimes.sorted(), id: \.self) { t in
                        Label(
                            t.formatted(date: .omitted, time: .shortened),
                            systemImage: "clock"
                        )
                    }
                    if let next = medication.nextScheduledTime {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Next Dose").font(.caption).foregroundStyle(.secondary)
                                Text(next.formatted(date: .abbreviated, time: .shortened))
                            }
                        } icon: {
                            Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(.blue)
                        }
                    }
                }
            }

            if medication.isActive {
                Section {
                    Button {
                        medication.lastTakenAt = Date()
                        showTakenAlert = true
                    } label: {
                        Label("Mark as Taken", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }

            if let last = medication.lastTakenAt {
                Section("History") {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Last Taken").font(.caption).foregroundStyle(.secondary)
                            Text(last.formatted(date: .abbreviated, time: .shortened))
                        }
                    } icon: {
                        Image(systemName: "clock.badge.checkmark").foregroundStyle(.green)
                    }
                }
            }

            if !medication.notes.isEmpty {
                Section("Notes") {
                    Text(medication.notes).foregroundStyle(.secondary)
                }
            }

            Section {
                Label(
                    "Added \(medication.createdAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(medication.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddMedicationView(editing: medication)
        }
        .alert("Marked as Taken!", isPresented: $showTakenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(medication.name) logged at \(Date().formatted(date: .omitted, time: .shortened)).")
        }
    }
}

#Preview {
    ContentView().modelContainer(for: Medication.self, inMemory: true)
}
