import Foundation

enum TaskType: String, Codable, CaseIterable {
    case clock
    case normal
}

enum WeekdayOption: Int, CaseIterable, Identifiable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

struct TimeOfDay: Codable, Equatable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.hour = comps.hour ?? 9
        self.minute = comps.minute ?? 0
    }

    func toDate(on day: Date = Date()) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? day
    }

    var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

struct DailyTask: Identifiable, Codable {
    var id: UUID
    var title: String
    var type: TaskType
    var defaultTime: TimeOfDay?
    var clockURL: String?
    var isActive: Bool
    var activeWeekdays: [Int]?

    init(
        id: UUID = UUID(),
        title: String,
        type: TaskType,
        defaultTime: TimeOfDay? = nil,
        clockURL: String? = nil,
        isActive: Bool = true,
        activeWeekdays: [Int]? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.defaultTime = defaultTime
        self.clockURL = clockURL
        self.isActive = isActive
        self.activeWeekdays = activeWeekdays
    }

    func runs(on weekday: Int) -> Bool {
        guard let days = activeWeekdays, !days.isEmpty else {
            return true
        }
        return days.contains(weekday)
    }

    var weekdaySummary: String {
        guard let days = activeWeekdays, !days.isEmpty else {
            return "Every day"
        }
        let labels = days.compactMap { WeekdayOption(rawValue: $0)?.shortLabel }
        return labels.joined(separator: ", ")
    }
}

struct TodayTask: Identifiable, Codable {
    var id: UUID
    var dateString: String
    var sourceDailyTaskID: UUID?
    var title: String
    var type: TaskType
    var remindTime: TimeOfDay?
    var clockURL: String?
    var isDone: Bool
    var notificationID: String
    var originalDateString: String?
    var carryOverDays: Int?

    init(
        id: UUID = UUID(),
        dateString: String,
        sourceDailyTaskID: UUID? = nil,
        title: String,
        type: TaskType,
        remindTime: TimeOfDay? = nil,
        clockURL: String? = nil,
        isDone: Bool = false,
        notificationID: String? = nil,
        originalDateString: String? = nil,
        carryOverDays: Int? = nil
    ) {
        self.id = id
        self.dateString = dateString
        self.sourceDailyTaskID = sourceDailyTaskID
        self.title = title
        self.type = type
        self.remindTime = remindTime
        self.clockURL = clockURL
        self.isDone = isDone
        self.notificationID = notificationID ?? "today-\(id.uuidString)"
        self.originalDateString = originalDateString ?? dateString
        self.carryOverDays = carryOverDays ?? 0
    }

    var effectiveCarryOverDays: Int {
        carryOverDays ?? 0
    }

    var isStale: Bool {
        effectiveCarryOverDays > 3
    }
}

extension Date {
    var yyyyMMdd: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    static func from(yyyyMMdd: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: yyyyMMdd)
    }

    var weekdayIndex: Int {
        Calendar.current.component(.weekday, from: self)
    }
}
