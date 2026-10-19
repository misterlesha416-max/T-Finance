import Foundation

struct MonthOption: Identifiable {
    let id: Int
    let title: String
    let year: Int
    let month: Int
    
    var firstDate: Date {
        Calendar.current.date(
            from: DateComponents(
                year: year,
                month: month,
                day: 1
            )
        ) ?? Date()
    }
    
    /// Первый и последний день месяца — используется для агрегации реальных
    /// транзакций в этот период (см. TransactionStore.categories(...)).
    var dateRange: ClosedRange<Date> {
        let start = firstDate
        let end = Calendar.current.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: start
        ) ?? start
        return start...end
    }
}

enum MonthData {
    /// Список месяцев: индекс 0 — текущий месяц по системной дате устройства
    /// (Date()), дальше — прошлые месяцы. Раньше первый месяц был
    /// захардкожен (июль 2026) и список не сдвигался вместе с реальным
    /// временем — теперь, как и в WeekData/YearData, точка отсчёта берётся
    /// от Date(), поэтому при наступлении нового календарного месяца в
    /// ленте само собой появляется новое (пустое) кольцо под индексом 0,
    /// а старый текущий месяц становится index 1.
    static let months: [MonthOption] = {
        let names = [
            "Январь", "Февраль", "Март", "Апрель",
            "Май", "Июнь", "Июль", "Август",
            "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
        ]
        
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        var result: [MonthOption] = []
        var year = currentYear
        var month = currentMonth
        
        // Глубина 24 месяца (~2 года) — тот же запас, что и у WeekData/YearData,
        // чтобы кольца не заканчивались раньше, чем ожидает пользователь.
        for index in 0..<24 {
            let name = names[month - 1]
            let title = year == currentYear ? name : "\(name) \(year)"
            
            result.append(
                MonthOption(
                    id: index,
                    title: title,
                    year: year,
                    month: month
                )
            )
            
            month -= 1
            if month == 0 {
                month = 12
                year -= 1
            }
        }
        
        return result
    }()
}
