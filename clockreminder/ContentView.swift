import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: TaskStore
    @State private var expandedDailyTaskID: UUID?
    @State private var expandedTodayTaskID: UUID?
    @State private var showAddDailyForm = false
    @State private var showAddTodayForm = false

    @State private var newDailyTitle = ""
    @State private var newDailyType: TaskType = .normal
    @State private var newDailyTime = Date()
    @State private var newDailyHasReminder = true
    @State private var newDailyURL = ""
    @State private var newDailyWeekdays = Set(WeekdayOption.allCases.map(\.rawValue))

    @State private var newTodayTitle = ""
    @State private var newTodayTime = Date()
    @State private var newTodayHasReminder = true

    var body: some View {
        NavigationStack {
            List {
                todayTasksSection
                dailyTasksSection
            }
            .navigationTitle("Plan Settings")
            .toolbar {
                EditButton()
            }
            .onAppear {
                store.syncTodayTasksForCurrentDateIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    store.syncTodayTasksForCurrentDateIfNeeded()
                }
            }
        }
    }

    private var todayTasksSection: some View {
        Section {
            if showAddTodayForm {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Task Name", text: $newTodayTitle)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Set Reminder Time", isOn: $newTodayHasReminder)

                    if newTodayHasReminder {
                        DatePicker("Reminder Time", selection: $newTodayTime, displayedComponents: .hourAndMinute)
                    }

                    Button("Add Today Task") {
                        store.addTodayTempTask(
                            title: newTodayTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            remindTime: newTodayHasReminder ? TimeOfDay(date: newTodayTime) : nil
                        )
                        newTodayTitle = ""
                        newTodayTime = Date()
                        newTodayHasReminder = true
                        showAddTodayForm = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(newTodayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 4)
            }

            ForEach(store.todayTasks) { task in
                TodayTaskRow(
                    task: task,
                    isExpanded: expandedTodayTaskID == task.id,
                    onToggleExpand: { toggleTodayExpansion(task.id) }
                ) { updated in
                    store.updateTodayTask(updated)
                }
            }
            .onDelete(perform: deleteTodayTasks)
        } header: {
            HStack {
                Text("Today Tasks")
                Spacer()
                Button(showAddTodayForm ? "Cancel" : "Add") {
                    showAddTodayForm.toggle()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var dailyTasksSection: some View {
        Section {
            dailySummaryReminderSetting

            if showAddDailyForm {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Task Name", text: $newDailyTitle)
                        .textFieldStyle(.roundedBorder)

                    Picker("Type", selection: $newDailyType) {
                        Text("Normal").tag(TaskType.normal)
                        Text("Clock").tag(TaskType.clock)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Set Reminder Time", isOn: $newDailyHasReminder)

                    if newDailyHasReminder {
                        DatePicker("Default Time", selection: $newDailyTime, displayedComponents: .hourAndMinute)
                    }

                    WeekdayPickerField(
                        label: "Repeat on",
                        selectedDays: Binding(
                            get: { newDailyWeekdays },
                            set: { newDailyWeekdays = $0 }
                        )
                    )

                    if newDailyType == .clock {
                        TextField("Clock URL (https://...)", text: $newDailyURL)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    Button("Add Daily Task") {
                        let time = newDailyHasReminder ? TimeOfDay(date: newDailyTime) : nil
                        let url = newDailyType == .clock ? newDailyURL.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                        store.addDailyTask(
                            title: newDailyTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: newDailyType,
                            time: time,
                            clockURL: url?.isEmpty == true ? nil : url,
                            activeWeekdays: Array(newDailyWeekdays)
                        )
                        newDailyTitle = ""
                        newDailyType = .normal
                        newDailyTime = Date()
                        newDailyHasReminder = true
                        newDailyURL = ""
                        newDailyWeekdays = Set(WeekdayOption.allCases.map(\.rawValue))
                        showAddDailyForm = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newDailyTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 4)
            }

            ForEach(store.dailyTasks) { task in
                DailyTaskRow(
                    task: task,
                    isExpanded: expandedDailyTaskID == task.id,
                    onToggleExpand: { toggleDailyExpansion(task.id) }
                ) { updated in
                    store.updateDailyTask(updated)
                }
            }
            .onDelete(perform: deleteDailyTasks)
        } header: {
            HStack {
                Text("Daily Tasks")
                Spacer()
                Button(showAddDailyForm ? "Cancel" : "Add") {
                    showAddDailyForm.toggle()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var dailySummaryReminderSetting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "Daily pending reminder",
                isOn: Binding(
                    get: { store.dailySummaryReminderTime != nil },
                    set: { isOn in
                        if isOn {
                            store.setDailySummaryReminderTime(store.dailySummaryReminderTime ?? TimeOfDay(hour: 20, minute: 0))
                        } else {
                            store.setDailySummaryReminderTime(nil)
                        }
                    }
                )
            )

            if store.dailySummaryReminderTime != nil {
                DatePicker(
                    "Reminder Time",
                    selection: Binding(
                        get: { (store.dailySummaryReminderTime ?? TimeOfDay(hour: 20, minute: 0)).toDate() },
                        set: { newDate in
                            store.setDailySummaryReminderTime(TimeOfDay(date: newDate))
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleTodayExpansion(_ id: UUID) {
        expandedTodayTaskID = (expandedTodayTaskID == id) ? nil : id
    }

    private func toggleDailyExpansion(_ id: UUID) {
        expandedDailyTaskID = (expandedDailyTaskID == id) ? nil : id
    }

    private func deleteTodayTasks(at offsets: IndexSet) {
        let deletingIDs = offsets.compactMap { index in
            store.todayTasks.indices.contains(index) ? store.todayTasks[index].id : nil
        }
        if let expandedID = expandedTodayTaskID, deletingIDs.contains(expandedID) {
            expandedTodayTaskID = nil
        }
        store.deleteTodayTasks(at: offsets)
    }

    private func deleteDailyTasks(at offsets: IndexSet) {
        let deletingIDs = offsets.compactMap { index in
            store.dailyTasks.indices.contains(index) ? store.dailyTasks[index].id : nil
        }
        if let expandedID = expandedDailyTaskID, deletingIDs.contains(expandedID) {
            expandedDailyTaskID = nil
        }
        store.deleteDailyTasks(at: offsets)
    }

}

private struct DailyTaskRow: View {
    let task: DailyTask
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onChanged: (DailyTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggleExpand) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title.isEmpty ? "Untitled Task" : task.title)
                        Text(task.defaultTime?.displayText ?? "No reminder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(task.weekdaySummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField(
                    "Task Name",
                    text: Binding(
                        get: { task.title },
                        set: {
                            var updated = task
                            updated.title = $0
                            onChanged(updated)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Toggle(
                    "Active",
                    isOn: Binding(
                        get: { task.isActive },
                        set: {
                            var updated = task
                            updated.isActive = $0
                            onChanged(updated)
                        }
                    )
                )

                Toggle(
                    "Set Reminder Time",
                    isOn: Binding(
                        get: { task.defaultTime != nil },
                        set: { isOn in
                            var updated = task
                            updated.defaultTime = isOn ? (task.defaultTime ?? TimeOfDay(date: Date())) : nil
                            onChanged(updated)
                        }
                    )
                )

                WeekdayPickerField(
                    label: "Repeat on",
                    selectedDays: Binding(
                        get: { Set(task.activeWeekdays ?? WeekdayOption.allCases.map(\.rawValue)) },
                        set: { selected in
                            var updated = task
                            let normalized = selected.count == 7 ? nil : Array(selected).sorted()
                            updated.activeWeekdays = normalized
                            onChanged(updated)
                        }
                    )
                )

                if task.defaultTime != nil {
                    DatePicker(
                        "Default Time",
                        selection: Binding(
                            get: { (task.defaultTime ?? TimeOfDay(date: Date())).toDate() },
                            set: {
                                var updated = task
                                updated.defaultTime = TimeOfDay(date: $0)
                                onChanged(updated)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                if task.type == .clock {
                    TextField(
                        "Clock URL",
                        text: Binding(
                            get: { task.clockURL ?? "" },
                            set: {
                                var updated = task
                                updated.clockURL = $0
                                onChanged(updated)
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    OpenClockButton(urlString: task.clockURL)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TodayTaskRow: View {
    let task: TodayTask
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onChanged: (TodayTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    var updated = task
                    updated.isDone.toggle()
                    onChanged(updated)
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button(action: onToggleExpand) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .strikethrough(task.isDone)
                            Text(task.remindTime?.displayText ?? "No reminder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if task.isStale {
                                Text("STALE")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Toggle(
                    "Set Reminder Time",
                    isOn: Binding(
                        get: { task.remindTime != nil },
                        set: { isOn in
                            var updated = task
                            updated.remindTime = isOn ? (task.remindTime ?? TimeOfDay(date: Date())) : nil
                            onChanged(updated)
                        }
                    )
                )
                .disabled(task.isDone)

                if task.remindTime != nil {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { (task.remindTime ?? TimeOfDay(date: Date())).toDate() },
                            set: {
                                var updated = task
                                updated.remindTime = TimeOfDay(date: $0)
                                onChanged(updated)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(task.isDone)
                }

                if task.type == .clock {
                    OpenClockButton(urlString: task.clockURL)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct OpenClockButton: View {
    let urlString: String?

    var body: some View {
        Button("Open Clock Site") {
            guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: raw),
                  UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }
        .buttonStyle(.bordered)
        .disabled(!isValidURL(urlString))
    }

    private func isValidURL(_ value: String?) -> Bool {
        guard let value, let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
}

private struct WeekdayPickerField: View {
    let label: String
    @Binding var selectedDays: Set<Int>
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(summaryText)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Repeat on")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showPicker = false
                    }
                    .font(.subheadline.weight(.semibold))
                }

                ForEach(WeekdayOption.allCases) { day in
                    Button {
                        toggle(day.rawValue)
                    } label: {
                        HStack {
                            Text(day.shortLabel)
                            Spacer()
                            if selectedDays.contains(day.rawValue) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
            .frame(width: 240)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var summaryText: String {
        if selectedDays.count == 7 {
            return "Every day"
        }
        let labels = WeekdayOption.allCases
            .filter { selectedDays.contains($0.rawValue) }
            .map(\.shortLabel)
        return labels.joined(separator: ", ")
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
            return
        }
        selectedDays.insert(day)
    }
}

