import Foundation

struct WeekOption: Identifiable {
    let id: Int
    let startDate: Date
    let endDate: Date

    var title: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) – \(end)"
    }
    
    /// Границы недели — используется для агрегации реальных транзакций
    /// в этот период (см. TransactionStore.categories(...)).
    var dateRange: ClosedRange<Date> { startDate...endDate }
}

enum WeekData {
    /// Список недель: индекс 0 — текущая неделя (пн–вс), дальше — прошлые
    /// недели. Глубина (105 недель ≈ 2 года) даёт запас, аналогичный
    /// MonthData, чтобы кольца не заканчивались раньше, чем ожидает пользователь.
    static let weeks: [WeekOption] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // понедельник

        guard
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        else {
            return []
        }

        var result: [WeekOption] = []

        for index in 0..<105 {
            guard
                let start = calendar.date(byAdding: .weekOfYear, value: -index, to: currentWeekStart),
                let end = calendar.date(byAdding: .day, value: 6, to: start)
            else { continue }

            result.append(WeekOption(id: index, startDate: start, endDate: end))
        }

        return result
    }()
}
