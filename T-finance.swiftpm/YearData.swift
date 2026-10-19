import Foundation

struct YearOption: Identifiable {
    let id: Int
    let year: Int

    var title: String { "\(year)" }
    
    /// Границы года — используется для агрегации реальных транзакций
    /// в этот период (см. TransactionStore.categories(...)).
    var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? start
        return start...end
    }
}

enum YearData {
    /// Список лет: индекс 0 — текущий год, дальше — прошлые годы.
    static let years: [YearOption] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (0..<15).map { offset in
            YearOption(id: offset, year: currentYear - offset)
        }
    }()
}
