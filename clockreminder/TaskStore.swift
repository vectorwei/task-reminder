import Foundation
import Combine
import SwiftUI

@MainActor
final class TaskStore: ObservableObject {
    @Published var dailyTasks: [DailyTask] = []
    @Published var todayTasks: [TodayTask] = []
    @Published var dailySummaryReminderTime: TimeOfDay?

    private let dailyKey = "clock.daily.tasks.v1"
    private let todayKey = "clock.today.tasks.v1"
    private let lastDailySyncDateKey = "clock.last.daily.sync.date.v1"
    private let dailySummaryReminderKey = "clock.daily.summary.reminder.time.v1"

    init() {
        load()
        if dailyTasks.isEmpty {
            dailyTasks = Self.defaultDailyTasks()
            saveDailyTasks()
        }
        dailySummaryReminderTime = loadValue(for: dailySummaryReminderKey)
        refreshDailyTasks()
        syncTodayTasksForCurrentDateIfNeeded()
    }

    func refreshTodayTasks() {
        let today = Date().yyyyMMdd
        todayTasks = todayTasks
            .filter { $0.dateString == today }
            .sorted(by: Self.timeSortToday)
    }

    func refreshDailyTasks() {
        dailyTasks = dailyTasks.sorted(by: Self.timeSortDaily)
    }

    func syncTodayTasksForCurrentDateIfNeeded() {
        let today = Date().yyyyMMdd
        let lastSyncDate = UserDefaults.standard.string(forKey: lastDailySyncDateKey)
        if lastSyncDate == today {
            scheduleDailySummaryReminderIfNeeded()
            return
        }
        rebuildTodayTasksFromDaily(for: today)
    }

    private func rebuildTodayTasksFromDaily(for dateString: String) {
        for task in todayTasks {
            NotificationManager.shared.removeNotification(id: task.notificationID)
        }

        let targetDate = Date.from(yyyyMMdd: dateString) ?? Date()
        let weekday = targetDate.weekdayIndex

        let generatedDailyTasks = dailyTasks
            .filter { $0.isActive }
            .filter { $0.runs(on: weekday) }
            .map { daily in
                TodayTask(
                    dateString: dateString,
                    sourceDailyTaskID: daily.id,
                    title: daily.title,
                    type: daily.type,
                    remindTime: daily.defaultTime,
                    clockURL: daily.clockURL
                )
            }

        let carriedTempTasks = buildCarriedTemporaryTasks(from: todayTasks, toDateString: dateString)
        let dedupedCarriedTasks = dedupeCarriedTasks(carriedTempTasks, against: generatedDailyTasks)
        todayTasks = generatedDailyTasks + dedupedCarriedTasks

        UserDefaults.standard.set(dateString, forKey: lastDailySyncDateKey)
        scheduleAllTodayNotifications()
        scheduleDailySummaryReminderIfNeeded()
        saveTodayTasks()
        refreshTodayTasks()
    }

    func addTodayTempTask(title: String, remindTime: TimeOfDay?) {
        let today = Date().yyyyMMdd
        let task = TodayTask(
            dateString: today,
            title: title,
            type: .normal,
            remindTime: remindTime
        )
        todayTasks.append(task)
        scheduleNotification(for: task)
        scheduleDailySummaryReminderIfNeeded()
        saveTodayTasks()
        refreshTodayTasks()
    }

    func deleteTodayTasks(at offsets: IndexSet) {
        let tasksToDelete = offsets.compactMap { index in
            todayTasks.indices.contains(index) ? todayTasks[index] : nil
        }
        for task in tasksToDelete {
            NotificationManager.shared.removeNotification(id: task.notificationID)
        }
        todayTasks.remove(atOffsets: offsets)
        scheduleDailySummaryReminderIfNeeded()
        saveTodayTasks()
        refreshTodayTasks()
    }

    func deleteTodayTask(id: UUID) {
        guard let index = todayTasks.firstIndex(where: { $0.id == id }) else {
            return
        }
        deleteTodayTasks(at: IndexSet(integer: index))
    }

    func updateTodayTask(_ task: TodayTask) {
        guard let idx = todayTasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        todayTasks[idx] = task
        if task.isDone {
            NotificationManager.shared.removeNotification(id: task.notificationID)
        } else {
            scheduleNotification(for: task)
        }
        scheduleDailySummaryReminderIfNeeded()
        saveTodayTasks()
        refreshTodayTasks()
    }

    func addDailyTask(title: String, type: TaskType, time: TimeOfDay?, clockURL: String?, activeWeekdays: [Int]?) {
        let task = DailyTask(
            title: title,
            type: type,
            defaultTime: time,
            clockURL: clockURL,
            activeWeekdays: normalizedWeekdays(activeWeekdays)
        )
        dailyTasks.append(task)
        saveDailyTasks()
        refreshDailyTasks()
    }

    func updateDailyTask(_ task: DailyTask) {
        guard let idx = dailyTasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        var updated = task
        updated.activeWeekdays = normalizedWeekdays(task.activeWeekdays)
        dailyTasks[idx] = updated
        saveDailyTasks()
        refreshDailyTasks()
    }

    func deleteDailyTasks(at offsets: IndexSet) {
        let dailyIDs = offsets.compactMap { index in
            dailyTasks.indices.contains(index) ? dailyTasks[index].id : nil
        }
        dailyTasks.remove(atOffsets: offsets)
        saveDailyTasks()
        refreshDailyTasks()

        let toRemove = todayTasks.filter { task in
            guard let sourceID = task.sourceDailyTaskID else { return false }
            return dailyIDs.contains(sourceID)
        }
        for task in toRemove {
            NotificationManager.shared.removeNotification(id: task.notificationID)
        }
        todayTasks.removeAll { task in
            guard let sourceID = task.sourceDailyTaskID else { return false }
            return dailyIDs.contains(sourceID)
        }
        saveTodayTasks()
        refreshTodayTasks()
        scheduleDailySummaryReminderIfNeeded()
    }

    func deleteDailyTask(id: UUID) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == id }) else {
            return
        }
        deleteDailyTasks(at: IndexSet(integer: index))
    }

    func setDailySummaryReminderTime(_ time: TimeOfDay?) {
        dailySummaryReminderTime = time
        save(dailySummaryReminderTime, key: dailySummaryReminderKey)
        scheduleDailySummaryReminderIfNeeded()
    }

    private func scheduleAllTodayNotifications() {
        for task in todayTasks where !task.isDone {
            scheduleNotification(for: task)
        }
    }

    private func scheduleNotification(for task: TodayTask) {
        guard task.type == .clock, !task.isDone, let remindTime = task.remindTime else {
            NotificationManager.shared.removeNotification(id: task.notificationID)
            return
        }
        let date = remindTime.toDate()
        NotificationManager.shared.scheduleNotification(
            id: task.notificationID,
            title: task.title,
            body: "Clock task reminder",
            at: date
        )
    }

    private func scheduleDailySummaryReminderIfNeeded() {
        let today = Date().yyyyMMdd
        let id = dailySummaryNotificationID(for: today)
        guard let reminderTime = dailySummaryReminderTime else {
            NotificationManager.shared.removeNotification(id: id)
            return
        }

        let pendingDailyCount = todayTasks.filter { task in
            task.sourceDailyTaskID != nil && !task.isDone
        }.count

        guard pendingDailyCount > 0 else {
            NotificationManager.shared.removeNotification(id: id)
            return
        }

        let triggerDate = reminderTime.toDate()
        guard triggerDate > Date() else {
            NotificationManager.shared.removeNotification(id: id)
            return
        }

        let title = "Daily tasks pending"
        let body = "You still have \(pendingDailyCount) unfinished daily tasks."
        NotificationManager.shared.scheduleNotification(id: id, title: title, body: body, at: triggerDate)
    }

    private func saveDailyTasks() {
        save(dailyTasks, key: dailyKey)
    }

    private func saveTodayTasks() {
        save(todayTasks, key: todayKey)
    }

    private func load() {
        dailyTasks = loadArray(for: dailyKey) ?? []
        dailyTasks = dailyTasks.map { task in
            var normalized = task
            normalized.activeWeekdays = normalizedWeekdays(task.activeWeekdays)
            return normalized
        }
        todayTasks = loadArray(for: todayKey) ?? []
    }

    private func dailySummaryNotificationID(for dateString: String) -> String {
        "daily-summary-\(dateString)"
    }

    private static func timeSortDaily(_ lhs: DailyTask, _ rhs: DailyTask) -> Bool {
        switch (lhs.defaultTime, rhs.defaultTime) {
        case let (l?, r?):
            return l.toDate() < r.toDate()
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func timeSortToday(_ lhs: TodayTask, _ rhs: TodayTask) -> Bool {
        switch (lhs.remindTime, rhs.remindTime) {
        case let (l?, r?):
            return l.toDate() < r.toDate()
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func buildCarriedTemporaryTasks(from existingTasks: [TodayTask], toDateString: String) -> [TodayTask] {
        existingTasks
            .filter { $0.sourceDailyTaskID == nil && !$0.isDone }
            .map { task in
                let addedDays = max(1, dayDelta(from: task.dateString, to: toDateString))
                return TodayTask(
                    dateString: toDateString,
                    sourceDailyTaskID: nil,
                    title: task.title,
                    type: task.type,
                    remindTime: task.remindTime,
                    clockURL: task.clockURL,
                    isDone: false,
                    originalDateString: task.originalDateString ?? task.dateString,
                    carryOverDays: task.effectiveCarryOverDays + addedDays
                )
            }
    }

    private func dedupeCarriedTasks(_ carried: [TodayTask], against generatedDailyTasks: [TodayTask]) -> [TodayTask] {
        let existingTitles = Set(generatedDailyTasks.map { normalizedTitle($0.title) })
        return carried.filter { !existingTitles.contains(normalizedTitle($0.title)) }
    }

    private func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func dayDelta(from oldDateString: String, to newDateString: String) -> Int {
        guard let old = Date.from(yyyyMMdd: oldDateString),
              let new = Date.from(yyyyMMdd: newDateString) else {
            return 1
        }
        let days = Calendar.current.dateComponents([.day], from: old, to: new).day ?? 1
        return max(1, days)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadArray<T: Decodable>(for key: String) -> [T]? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode([T].self, from: data)
    }

    private func loadValue<T: Decodable>(for key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func normalizedWeekdays(_ weekdays: [Int]?) -> [Int]? {
        guard let weekdays else { return nil }
        let filtered = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        if filtered.isEmpty || filtered.count == 7 {
            return nil
        }
        return filtered
    }

    private static func defaultDailyTasks() -> [DailyTask] {
        [
            DailyTask(title: "Clock In 1", type: .clock, defaultTime: .init(hour: 9, minute: 0), clockURL: "https://example.com/clock"),
            DailyTask(title: "Clock Out 1", type: .clock, defaultTime: .init(hour: 12, minute: 0), clockURL: "https://example.com/clock"),
            DailyTask(title: "Clock In 2", type: .clock, defaultTime: .init(hour: 13, minute: 30), clockURL: "https://example.com/clock"),
            DailyTask(title: "Clock Out 2", type: .clock, defaultTime: .init(hour: 18, minute: 30), clockURL: "https://example.com/clock")
        ]
    }
}
