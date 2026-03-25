import Foundation

extension Calendar {
    static var dayActivityTracker: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

enum DateFormatting {
    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func weeklyRecapRange(start: Date, end: Date, calendar: Calendar = .dayActivityTracker) -> String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.dateTemplate = "EEE, MMM d"
        return formatter.string(from: start, to: end)
    }

    static func dayHeader(_ date: Date, calendar: Calendar = .dayActivityTracker) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.calendar = calendar
        return formatter.string(from: date)
    }
}

enum DurationFormatting {
    static func abbreviated(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval.rounded(.down) / 60), 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    static func hoursPerDay(_ interval: TimeInterval, dayCount: Int) -> String {
        let normalizedDayCount = max(dayCount, 1)
        let hoursPerDay = max(interval, 0) / 3600 / Double(normalizedDayCount)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1

        let value = formatter.string(from: NSNumber(value: hoursPerDay)) ?? "0.0"
        return "\(value)h/day"
    }
}

enum PercentageFormatting {
    static func wholePercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}
