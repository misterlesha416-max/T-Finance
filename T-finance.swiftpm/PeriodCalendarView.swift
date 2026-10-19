import SwiftUI

struct PeriodCalendarView: View {
    let initialMonth: Date
    
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    let onDone: () -> Void
    let onClose: () -> Void
    
    @State private var activeField: ActiveDateField = .start
    
    private let calendar = Calendar.current
    private let sidePadding: CGFloat = 12
    
    private var displayedMonths: [Date] {
        guard let firstMonth = calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: initialMonth
            )
        ) else {
            return []
        }
        
        return (-6...6).compactMap {
            calendar.date(
                byAdding: .month,
                value: $0,
                to: firstMonth
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            dateFields
            
            ZStack(alignment: .top) {
                calendarList
                weekdays
            }
        }
        .background(Color(red: 0.105, green: 0.105, blue: 0.115))
        .preferredColorScheme(.dark)
    }
    
    private var header: some View {
        HStack {
            Button("Закрыть", action: onClose)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Color.blue)
            
            Spacer()
            
            Text("Выберите период")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button("Готово", action: onDone)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Color.blue)
                .disabled(startDate == nil)
        }
        .padding(.horizontal, sidePadding)
        .frame(height: 68)
    }
    
    private var dateFields: some View {
        HStack(spacing: 22) {
            dateField(
                title: "Дата начала",
                value: startDate,
                field: .start
            )
            
            dateField(
                title: "Дата окончания",
                value: endDate,
                field: .end
            )
        }
        .padding(.horizontal, sidePadding)
    }
    
    private func dateField(
        title: String,
        value: Date?,
        field: ActiveDateField
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeField = field
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.secondary)
                    .opacity(value != nil ? 1 : 0)
                
                Text(value.map(dayMonthText) ?? title)
                    .font(.system(size: value != nil ? 16 : 17, weight: .light))
                    .foregroundStyle(value != nil ? .white : .secondary)
                
                Rectangle()
                    .fill(activeField == field ? Color.blue : Color.white.opacity(0.06))
                    .frame(height: activeField == field ? 2 : 1)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: value)
        }
        .buttonStyle(.plain)
    }
    
    private var weekdays: some View {
        HStack(spacing: 0) {
            ForEach(["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"], id: \.self) {
                Text($0)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, sidePadding)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(Color.black.opacity(0.38))
                }
        }
    }
    
    private var calendarList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 28) {
                    ForEach(displayedMonths, id: \.self) { month in
                        CalendarMonthView(
                            month: month,
                            startDate: startDate,
                            endDate: endDate,
                            onDateTap: selectDate,
                            onMonthTap: selectFullMonth
                        )
                        .id(monthIdentifier(month))
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(
                        monthIdentifier(initialMonth),
                        anchor: .top
                    )
                }
            }
        }
    }
    
    private func selectDate(_ date: Date) {
        switch activeField {
        case .start:
            startDate = date
            
            if let endDate, endDate < date {
                self.endDate = nil
            }
            
            activeField = .end
            
        case .end:
            guard let startDate else {
                self.startDate = date
                activeField = .end
                return
            }
            
            if date < startDate {
                self.startDate = date
                endDate = nil
            } else {
                endDate = date
            }
        }
    }
    
    private func dayMonthText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
    
    private func monthIdentifier(_ date: Date) -> String {
        let components = calendar.dateComponents(
            [.year, .month],
            from: date
        )
        
        let year = components.year ?? 0
        let month = components.month ?? 0
        
        return "\(year)-\(month)"
    }
    private func selectFullMonth(_ month: Date) {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            ),
            let lastDay = calendar.date(byAdding: .day, value: range.count - 1, to: firstDay)
        else { return }
        
        startDate = firstDay
        endDate = lastDay
        activeField = .end
    }
}

private enum ActiveDateField {
    case start
    case end
}

// MARK: - Month grid

private struct CalendarMonthView: View {
    let month: Date
    let startDate: Date?
    let endDate: Date?
    let onDateTap: (Date) -> Void
    let onMonthTap: (Date) -> Void
    
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        return calendar
    }
    
    private let cellHeight: CGFloat = 38
    
    /// Дни месяца строками по 7 (пн-вс). Строки нужны отдельно (а не как
    /// плоский список для LazyVGrid), чтобы подсветку диапазона рисовать
    /// одним прямоугольником на строку — без швов между соседними ячейками,
    /// которые давали "шахматный" эффект при флексибл-колонках.
    private var weeks: [[CalendarDay?]] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            )
        else {
            return []
        }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        // В Calendar воскресенье = 1. Преобразуем так, чтобы понедельник был первым.
        let leadingEmptyDays = (weekday + 5) % 7
        
        var flat = Array<CalendarDay?>(repeating: nil, count: leadingEmptyDays)
        
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) else {
                continue
            }
            flat.append(CalendarDay(number: day, date: date))
        }
        
        while flat.count % 7 != 0 {
            flat.append(nil)
        }
        
        return stride(from: 0, to: flat.count, by: 7).map {
            Array(flat[$0..<$0 + 7])
        }
    }
    
    private var isFullMonthSelected: Bool {
        guard
            let startDate, let endDate,
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            ),
            let lastDay = calendar.date(byAdding: .day, value: range.count - 1, to: firstDay)
        else { return false }
        
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        return start <= firstDay && end >= lastDay
    }
    
    private var isFutureMonth: Bool {
        let displayedComponents = calendar.dateComponents([.year, .month], from: month)
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        
        guard
            let displayedYear = displayedComponents.year,
            let displayedMonthNum = displayedComponents.month,
            let currentYear = currentComponents.year,
            let currentMonthNum = currentComponents.month
        else { return false }
        
        if displayedYear != currentYear {
            return displayedYear > currentYear
        }
        return displayedMonthNum > currentMonthNum
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                onMonthTap(month)
            } label: {
                Text(monthTitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(
                        isFutureMonth
                        ? Color.white.opacity(0.25)
                        : .white
                    )
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(
                        isFullMonthSelected
                        ? Color.blue
                        : Color.white.opacity(isFutureMonth ? 0.04 : 0.10)
                    )
                    .clipShape(Capsule())
                    .offset(y: 12)
            }
            .buttonStyle(.plain)
            .disabled(isFutureMonth)
            
            VStack(spacing: 2) {
                ForEach(weeks.indices, id: \.self) { index in
                    weekRow(weeks[index])
                }
            }
        }
    }
    
    // MARK: Week row (highlight drawn once per row — no seams)
    
    private func weekRow(_ week: [CalendarDay?]) -> some View {
        GeometryReader { geo in
            let cellWidth = geo.size.width / 7
            
            ZStack(alignment: .topLeading) {
                if let segment = highlightSegment(week, cellWidth: cellWidth) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: segment.leftRounded ? 18 : 0,
                        bottomLeadingRadius: segment.leftRounded ? 18 : 0,
                        bottomTrailingRadius: segment.rightRounded ? 18 : 0,
                        topTrailingRadius: segment.rightRounded ? 18 : 0
                    )
                    .fill(Color.white.opacity(0.10))
                    .frame(width: segment.width, height: 36)
                    .offset(x: segment.minX, y: 1)
                }
                
                HStack(spacing: 0) {
                    ForEach(week.indices, id: \.self) { index in
                        if let day = week[index] {
                            dayView(day)
                                .frame(width: cellWidth)
                        } else {
                            Color.clear.frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
        }
        .frame(height: cellHeight)
    }
    
    /// Сегмент подсветки для одной строки недели.
    /// leftRounded/rightRounded — true, когда этот край строки не совпадает
    /// с реальной start/end датой (значит, диапазон "перетекает" в соседнюю
    /// строку и край нужно закруглить капсулой, а не резать прямо; если же
    /// край совпадает с реальной датой — он всё равно спрятан под синим
    /// кружком, скругление там не нужно).
    private struct HighlightSegment {
        let minX: CGFloat
        let width: CGFloat
        let leftRounded: Bool
        let rightRounded: Bool
    }
    
    private func highlightSegment(
        _ week: [CalendarDay?],
        cellWidth: CGFloat
    ) -> HighlightSegment? {
        guard let startDate, let endDate else { return nil }
        
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start != end else { return nil }
        
        var firstIndex: Int?
        var lastIndex: Int?
        
        for (index, day) in week.enumerated() {
            guard let day else { continue }
            let current = calendar.startOfDay(for: day.date)
            if current >= start && current <= end {
                if firstIndex == nil { firstIndex = index }
                lastIndex = index
            }
        }
        
        guard let first = firstIndex, let last = lastIndex else { return nil }
        
        let firstDate = calendar.startOfDay(for: week[first]!.date)
        let lastDate = calendar.startOfDay(for: week[last]!.date)
        
        let isTrueStart = firstDate == start
        let isTrueEnd = lastDate == end
        
        let minX = CGFloat(first) * cellWidth + (isTrueStart ? cellWidth / 2 : 0)
        let maxX = CGFloat(last + 1) * cellWidth - (isTrueEnd ? cellWidth / 2 : 0)
        
        guard maxX > minX else { return nil }
        
        return HighlightSegment(
            minX: minX,
            width: maxX - minX,
            leftRounded: !isTrueStart,
            rightRounded: !isTrueEnd
        )
    }
    
    private func dayView(_ day: CalendarDay) -> some View {
        let isStart = isSameDay(day.date, startDate)
        let isEnd = isSameDay(day.date, endDate)
        let isToday = calendar.isDateInToday(day.date)
        let isFuture = calendar.startOfDay(for: day.date) > calendar.startOfDay(for: Date())
        
        return Button {
            onDateTap(day.date)
        } label: {
            ZStack {
                if isStart || isEnd {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 36, height: 36)
                }
                
                Text("\(day.number)")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(
                        isFuture
                        ? Color.white.opacity(0.25)
                        : .white
                    )
                
                if isToday {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                        .offset(y: 13)
                }
            }
            .frame(height: cellHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL"
        
        var title = formatter.string(from: month).capitalized
        
        let displayedYear = calendar.component(.year, from: month)
        let currentYear = calendar.component(.year, from: Date())
        
        if displayedYear != currentYear {
            title += ", \(displayedYear)"
        }
        
        return title
    }
    
    private func isSameDay(_ first: Date, _ second: Date?) -> Bool {
        guard let second else { return false }
        return calendar.isDate(first, inSameDayAs: second)
    }
}

private struct CalendarDay {
    let number: Int
    let date: Date
}
